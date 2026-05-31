import SwiftUI
import Foundation

struct SimpleFINAccountsResponse: Decodable {
    let accounts: [SimpleFINAccount]
}

struct SimpleFINAccount: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let currency: String
    let balance: Decimal
    let availableBalance: Decimal?
    let balanceDate: Date?
    let holdings: [SimpleFINHolding]
    let org: SimpleFINOrganization?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case currency
        case balance
        case availableBalance = "available-balance"
        case balanceDate = "balance-date"
        case holdings
        case org
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        balance = try container.decodeDecimal(forKey: .balance)
        availableBalance = try container.decodeDecimalIfPresent(forKey: .availableBalance)
        if let timestamp = try container.decodeIfPresent(Double.self, forKey: .balanceDate) {
            balanceDate = Date(timeIntervalSince1970: timestamp)
        } else {
            balanceDate = nil
        }
        holdings = try container.decodeIfPresent([SimpleFINHolding].self, forKey: .holdings) ?? []
        org = try container.decodeIfPresent(SimpleFINOrganization.self, forKey: .org)
    }
}

struct SimpleFINHolding: Decodable, Identifiable, Hashable {
    let id: String
    let description: String
    let marketValue: Decimal
    let shares: Decimal?
    let symbol: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case description
        case marketValue = "market_value"
        case shares
        case symbol
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        description = try container.decode(String.self, forKey: .description)
        marketValue = try container.decodeDecimal(forKey: .marketValue)
        shares = try container.decodeDecimalIfPresent(forKey: .shares)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
    }
}

struct SimpleFINOrganization: Decodable, Hashable {
    let name: String?
    let domain: String?
    let url: String?
}

extension SimpleFINAccount {
    var accountType: NormalizedAccountType {
        .investment
    }

    var amount: Decimal {
        balance
    }

    var nickname: String {
        name
    }

    var displayName: String? {
        name
    }

    var updateDate: Date? {
        balanceDate
    }

    var sourceLabel: String {
        org?.name ?? "SimpleFIN"
    }

    var badgeLabel: String {
        if name.localizedCaseInsensitiveContains("Dominion") {
            return "401K"
        }

        return name
    }

    var mask: String? {
        guard let open = name.lastIndex(of: "("),
              let close = name.lastIndex(of: ")"),
              open < close else {
            return nil
        }

        let suffix = name[name.index(after: open)..<close]
        return suffix.isEmpty ? nil : String(suffix)
    }

    var institutionLogoAssetName: String? {
        if accountSearchText.contains("dominion") || accountSearchText.contains("401") {
            return "InstitutionDominionEnergyLogo"
        }

        return nil
    }

    var gradientColors: [Color] {
        if accountSearchText.contains("dominion") || accountSearchText.contains("401") {
            return [.rgb(0, 114, 206), .rgb(0, 114, 206)]
        }

        return [Color.payCycleNavy, Color.payCycleBlue]
    }

    var replacesDominionManualAccount: Bool {
        accountSearchText.contains("dominion") &&
            (accountSearchText.contains("401(k)") ||
             accountSearchText.contains("401k") ||
             accountSearchText.contains("401 k"))
    }

    private var accountSearchText: String {
        [name, org?.name ?? "", org?.domain ?? ""]
            .joined(separator: " ")
            .lowercased()
    }
}

private extension Color {
    static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }
}
