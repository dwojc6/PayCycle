import Foundation

struct SimpleFINAPIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchAccounts(setupURL: String) async throws -> [SimpleFINAccount] {
        let request = try makeRequest(setupURL: setupURL)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SimpleFINAPIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw SimpleFINAPIError.statusCode(httpResponse.statusCode)
        }

        do {
            let response = try JSONDecoder().decode(SimpleFINAccountsResponse.self, from: data)
            return response.accounts
        } catch {
            throw SimpleFINAPIError.decodingFailed
        }
    }

    private func makeRequest(setupURL: String) throws -> URLRequest {
        let trimmedURL = setupURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw SimpleFINAPIError.invalidURL
        }

        let username = components.user
        let password = components.password
        components.user = nil
        components.password = nil

        guard let sanitizedURL = components.url else {
            throw SimpleFINAPIError.invalidURL
        }

        var request = URLRequest(url: sanitizedURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let username, let password {
            let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}

enum SimpleFINAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The SimpleFIN setup URL is not valid."
        case .invalidResponse:
            return "SimpleFIN returned an invalid response."
        case .statusCode(let statusCode):
            return "SimpleFIN request failed with status code \(statusCode)."
        case .decodingFailed:
            return "SimpleFIN returned account data in an unexpected format."
        }
    }
}
