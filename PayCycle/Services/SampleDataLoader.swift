import Foundation

struct SampleDataLoader {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadAccounts() throws -> [LunchMoneyPlaidAccount] {
        try decodeResource(
            named: "plaid_accounts",
            as: PlaidAccountsResponse.self
        ).plaidAccounts
    }

    func loadUser() throws -> LunchMoneyUser {
        try decodeResource(named: "me", as: LunchMoneyUser.self)
    }

    private func decodeResource<T: Decodable>(named name: String, as type: T.Type) throws -> T {
        let data = try loadResourceData(named: name)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func loadResourceData(named name: String) throws -> Data {
        if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "PreviewData") {
            return try Data(contentsOf: url)
        }

        if let url = bundle.url(forResource: name, withExtension: "json") {
            return try Data(contentsOf: url)
        }

        throw SampleDataError.missingResource(name)
    }
}

enum SampleDataError: LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Sample resource \(name).json could not be found in the app bundle."
        }
    }
}
