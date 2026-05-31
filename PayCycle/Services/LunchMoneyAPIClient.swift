import Foundation

struct LunchMoneyAPIClient {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.lunchmoney.dev/v2")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUser(apiKey: String) async throws -> LunchMoneyUser {
        try await sendRequest(path: "me", apiKey: apiKey, method: "GET", responseType: LunchMoneyUser.self)
    }

    func fetchPlaidAccounts(apiKey: String) async throws -> [LunchMoneyPlaidAccount] {
        let response: PlaidAccountsResponse = try await sendRequest(
            path: "plaid_accounts",
            apiKey: apiKey,
            method: "GET",
            responseType: PlaidAccountsResponse.self
        )
        return response.plaidAccounts
    }

    func fetchTransactions(apiKey: String, startDate: String, endDate: String) async throws -> [LunchMoneyTransaction] {
        let queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate),
            URLQueryItem(name: "include_metadata", value: "true"),
            URLQueryItem(name: "include_pending", value: "true"),
            URLQueryItem(name: "limit", value: "1000")
        ]
        let response: TransactionsResponse = try await sendRequest(
            path: "transactions", apiKey: apiKey, method: "GET",
            queryItems: queryItems, responseType: TransactionsResponse.self
        )
        return response.transactions
    }

    func fetchCategories(apiKey: String) async throws -> [LunchMoneyCategory] {
        let response: CategoriesResponse = try await sendRequest(
            path: "categories", apiKey: apiKey, method: "GET", responseType: CategoriesResponse.self
        )
        return response.categories
    }

    func fetchBudgetSummary(apiKey: String, startDate: String, endDate: String) async throws -> BudgetSummaryResponse {
        let queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate),
            URLQueryItem(name: "include_exclude_from_budgets", value: "false"),
            URLQueryItem(name: "include_occurrences", value: "false"),
            URLQueryItem(name: "include_past_budget_dates", value: "false"),
            URLQueryItem(name: "include_totals", value: "false"),
            URLQueryItem(name: "include_rollover_pool", value: "false")
        ]

        return try await sendRequest(
            path: "summary",
            apiKey: apiKey,
            method: "GET",
            queryItems: queryItems,
            responseType: BudgetSummaryResponse.self
        )
    }

    func fetchManualAccounts(apiKey: String) async throws -> [LunchMoneyManualAccount] {
        let response: ManualAccountsResponse = try await sendRequest(
            path: "manual_accounts",
            apiKey: apiKey,
            method: "GET",
            responseType: ManualAccountsResponse.self
        )
        return response.manualAccounts
    }

    func syncPlaidAccounts(apiKey: String) async throws -> [LunchMoneyPlaidAccount]? {
        do {
            let response: PlaidAccountsResponse = try await sendRequest(
                path: "plaid_accounts/fetch",
                apiKey: apiKey,
                method: "POST",
                responseType: PlaidAccountsResponse.self
            )
            return response.plaidAccounts
        } catch let error as LunchMoneyAPIError where error.isAcceptedWithoutBody {
            return nil
        } catch {
            throw error
        }
    }

    private func sendRequest<Response: Decodable>(
        path: String,
        apiKey: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        responseType: Response.Type
    ) async throws -> Response {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw LunchMoneyAPIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LunchMoneyAPIError.invalidResponse
        }

        if httpResponse.statusCode == 202 {
            throw LunchMoneyAPIError.acceptedWithoutBody
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw parseError(data: data, statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw LunchMoneyAPIError.decodingFailed
        }
    }

    private func parseError(data: Data, statusCode: Int) -> LunchMoneyAPIError {
        if let errorResponse = try? JSONDecoder().decode(LunchMoneyErrorResponse.self, from: data) {
            if let message = errorResponse.message, !message.isEmpty {
                return .message(message, statusCode: statusCode)
            }

            if let detailedMessage = errorResponse.errors?.first?.errMsg {
                return .message(detailedMessage, statusCode: statusCode)
            }
        }

        return .statusCode(statusCode)
    }
}

private struct LunchMoneyErrorResponse: Decodable {
    let message: String?
    let errors: [LunchMoneyErrorDetail]?
}

private struct LunchMoneyErrorDetail: Decodable {
    let errMsg: String?
}

enum LunchMoneyAPIError: LocalizedError {
    case invalidResponse
    case acceptedWithoutBody
    case statusCode(Int)
    case message(String, statusCode: Int)
    case decodingFailed

    var isAcceptedWithoutBody: Bool {
        if case .acceptedWithoutBody = self {
            return true
        }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Lunch Money returned an invalid response."
        case .acceptedWithoutBody:
            return "Lunch Money accepted the Plaid refresh and is still processing it."
        case .statusCode(let statusCode):
            return "Lunch Money request failed with status code \(statusCode)."
        case .message(let message, let statusCode):
            return "\(message) (HTTP \(statusCode))"
        case .decodingFailed:
            return "Lunch Money returned data in an unexpected format."
        }
    }
}
