import SwiftUI
import Foundation

struct ManualAccountsResponse: Decodable {
    let manualAccounts: [LunchMoneyManualAccount]

    private enum CodingKeys: String, CodingKey {
        case manualAccounts = "manual_accounts"
    }
}

struct LunchMoneyManualAccount: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let displayName: String?
    let rawType: String
    let subtype: String?
    let balance: Decimal
    let currency: String
    let toBase: Decimal?
    let closedOn: String?
    let createdAt: Date?
    let updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName = "display_name"
        case rawType = "type"
        case subtype
        case balance
        case currency
        case toBase = "to_base"
        case closedOn = "closed_on"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        rawType = try container.decode(String.self, forKey: .rawType)
        subtype = try container.decodeIfPresent(String.self, forKey: .subtype)
        balance = try container.decodeDecimal(forKey: .balance)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "usd"
        toBase = try container.decodeDecimalIfPresent(forKey: .toBase)
        closedOn = try container.decodeIfPresent(String.self, forKey: .closedOn)
        createdAt = try container.decodeFlexibleDateIfPresent(forKey: .createdAt)
        updatedAt = try container.decodeFlexibleDateIfPresent(forKey: .updatedAt)
    }
}

extension LunchMoneyManualAccount {
    var accountType: NormalizedAccountType {
        NormalizedAccountType(rawType: rawType)
    }

    var amount: Decimal {
        toBase ?? balance
    }

    var nickname: String {
        displayName ?? name
    }

    var updateDate: Date? {
        updatedAt ?? createdAt
    }

    var isActive: Bool {
        closedOn == nil
    }
}

// MARK: - Convert to unified AnyAccount

/// Unified account type that wraps either a Plaid or Manual account
/// so both can be displayed in the same list with the same views.
enum AnyAccount: Identifiable, Hashable {
    case plaid(LunchMoneyPlaidAccount)
    case manual(LunchMoneyManualAccount)
    case simpleFIN(SimpleFINAccount)

    var id: String {
        switch self {
        case .plaid(let a): return "plaid-\(a.id)"
        case .manual(let a): return "manual-\(a.id)"
        case .simpleFIN(let a): return "simplefin-\(a.id)"
        }
    }

    var accountType: NormalizedAccountType {
        switch self {
        case .plaid(let a): return a.accountType
        case .manual(let a): return a.accountType
        case .simpleFIN(let a): return a.accountType
        }
    }

    var amount: Decimal {
        switch self {
        case .plaid(let a): return a.amount
        case .manual(let a): return a.amount
        case .simpleFIN(let a): return a.amount
        }
    }

    var plaidAccountId: Int? {
        switch self {
        case .plaid(let a): return a.id
        case .manual, .simpleFIN: return nil
        }
    }

    var currency: String {
        switch self {
        case .plaid(let a): return a.currency
        case .manual(let a): return a.currency
        case .simpleFIN(let a): return a.currency
        }
    }

    var nickname: String {
        switch self {
        case .plaid(let a): return a.nickname
        case .manual(let a): return a.nickname
        case .simpleFIN(let a): return a.nickname
        }
    }

    var displayName: String? {
        switch self {
        case .plaid(let a): return a.displayName
        case .manual(let a): return a.displayName
        case .simpleFIN(let a): return a.displayName
        }
    }

    var updateDate: Date? {
        switch self {
        case .plaid(let a): return a.updateDate
        case .manual(let a): return a.updateDate
        case .simpleFIN(let a): return a.updateDate
        }
    }

    var isActive: Bool {
        switch self {
        case .plaid(let a): return a.status.lowercased() == "active"
        case .manual(let a): return a.isActive
        case .simpleFIN: return true
        }
    }

    var isManual: Bool {
        if case .manual = self { return true }
        return false
    }

    /// Source label shown in the row
    var sourceLabel: String {
        switch self {
        case .plaid(let a): return a.shortInstitutionName
        case .manual: return "Manual"
        case .simpleFIN(let a): return a.sourceLabel
        }
    }

    /// Monogram for the badge
    var monogram: String {
        switch self {
        case .plaid(let a):
            let parts = a.shortInstitutionName
                .split(separator: " ").prefix(2)
                .map { String($0.prefix(1)) }.joined()
            return parts.isEmpty ? "LM" : parts.uppercased()
        case .manual(let a):
            let parts = a.nickname
                .split(separator: " ").prefix(2)
                .map { String($0.prefix(1)) }.joined()
            return parts.isEmpty ? "M" : parts.uppercased()
        case .simpleFIN(let a):
            let parts = a.sourceLabel
                .split(separator: " ").prefix(2)
                .map { String($0.prefix(1)) }.joined()
            return parts.isEmpty ? "SF" : parts.uppercased()
        }
    }

    var institutionLogoAssetName: String? {
        switch self {
        case .plaid(let a):
            return a.institutionLogoAssetName
        case .manual(let a):
            return a.institutionLogoAssetName
        case .simpleFIN(let a):
            return a.institutionLogoAssetName
        }
    }

    /// Card badge label
    var badgeLabel: String {
        switch self {
        case .plaid(let a): return a.badgeLabel
        case .manual(let a): return a.nickname
        case .simpleFIN(let a): return a.badgeLabel
        }
    }

    /// Last 4 digits / mask
    var mask: String? {
        switch self {
        case .plaid(let a): return a.mask
        case .manual: return nil
        case .simpleFIN(let a): return a.mask
        }
    }

    /// Utilization (credit accounts only)
    var utilization: Decimal? {
        switch self {
        case .plaid(let a): return a.utilization
        case .manual, .simpleFIN: return nil
        }
    }

    /// Credit limit
    var limit: Decimal? {
        switch self {
        case .plaid(let a): return a.limit
        case .manual, .simpleFIN: return nil
        }
    }

    /// Gradient colors for badge card
    var gradientColors: [Color] {
        switch self {
        case .plaid(let a):
            return a.gradientColors
        case .simpleFIN(let a):
            return a.gradientColors
        case .manual(let a):
            if let cardColor = a.cardColor {
                return [cardColor, cardColor]
            }

            if a.nickname.localizedCaseInsensitiveContains("Apple Savings") {
                return [Color.black, Color(red: 0.08, green: 0.08, blue: 0.09)]
            }

            switch a.accountType {
            case .cash:       return [Color(red: 0.13, green: 0.53, blue: 0.38), Color(red: 0.07, green: 0.38, blue: 0.27)]
            case .investment: return [Color(red: 0.44, green: 0.22, blue: 0.78), Color(red: 0.29, green: 0.13, blue: 0.56)]
            case .realEstate: return [Color(red: 0.60, green: 0.38, blue: 0.14), Color(red: 0.42, green: 0.26, blue: 0.08)]
            case .loan:       return [Color(red: 0.04, green: 0.37, blue: 0.52), Color(red: 0.11, green: 0.56, blue: 0.78)]
            case .credit:     return [Color(red: 1.00, green: 0.58, blue: 0.17), Color(red: 0.97, green: 0.78, blue: 0.07)]
            default:          return [Color.payCycleNavy, Color.payCycleBlue]
            }
        }
    }

    var replacesDominionManualAccount: Bool {
        switch self {
        case .simpleFIN(let account):
            return account.replacesDominionManualAccount
        case .manual(let account):
            return account.isDominionEnergy401k
        case .plaid:
            return false
        }
    }
}

// Pull gradientColors out of LunchMoneyPlaidAccount so AnyAccount can use it
extension LunchMoneyManualAccount {
    private var accountSearchText: String {
        [name, displayName ?? "", subtype ?? ""]
            .joined(separator: " ")
            .lowercased()
    }

    var institutionLogoAssetName: String? {
        if accountSearchText.contains("apple") {
            return "InstitutionAppleLogo"
        }

        if accountSearchText.contains("venmo") {
            return "InstitutionVenmoLogo"
        }

        if accountSearchText.contains("401k") ||
            accountSearchText.contains("401 k") ||
            accountSearchText.contains("401(k)") ||
            accountSearchText.contains("dominion") {
            return "InstitutionDominionEnergyLogo"
        }

        if accountSearchText.contains("mortgage") ||
            accountSearchText.contains("rocket") {
            return "InstitutionRocketMortgageLogo"
        }

        if accountSearchText.contains("hsa") ||
            accountSearchText.contains("inspira") {
            return "InstitutionInspiraLogo"
        }

        return nil
    }

    var cardColor: Color? {
        if accountSearchText.contains("401k") ||
            accountSearchText.contains("401 k") ||
            accountSearchText.contains("401(k)") ||
            accountSearchText.contains("dominion") {
            return .rgb(0, 114, 206)
        }

        if accountSearchText.contains("mortgage") ||
            accountSearchText.contains("rocket") {
            return .rgb(169, 39, 95)
        }

        if accountSearchText.contains("hsa") ||
            accountSearchText.contains("inspira") {
            return .rgb(255, 208, 8)
        }

        return nil
    }

    var isDominionEnergy401k: Bool {
        accountSearchText.contains("dominion") &&
            (accountSearchText.contains("401k") ||
             accountSearchText.contains("401 k") ||
             accountSearchText.contains("401(k)"))
    }
}

extension LunchMoneyPlaidAccount {
    private var accountSearchText: String {
        [name, displayName ?? "", institutionName ?? "", subtype ?? ""]
            .joined(separator: " ")
            .lowercased()
    }

    var institutionLogoAssetName: String? {
        let institution = shortInstitutionName.lowercased()

        if accountSearchText.contains("family trust") || accountSearchText.contains("sonata") { return "InstitutionFamilyTrustLogo" }
        if accountSearchText.contains("allegacy") || accountSearchText.contains("telluride") { return "InstitutionAllegacyLogo" }
        if accountSearchText.contains("rocket") || accountSearchText.contains("mortgage") { return "InstitutionRocketMortgageLogo" }
        if institution.contains("apple") { return "InstitutionAppleLogo" }
        if institution.contains("bank of america") { return "InstitutionBankOfAmericaLogo" }
        if institution.contains("capital one") { return "InstitutionCapitalOneLogo" }
        if institution.contains("citi") { return "InstitutionCitiLogo" }
        if institution.contains("chase") { return "InstitutionChaseLogo" }
        if institution.contains("venmo") { return "InstitutionVenmoLogo" }

        return nil
    }

    var gradientColors: [Color] {
        let institution = shortInstitutionName.lowercased()
        if accountSearchText.contains("family trust") || accountSearchText.contains("sonata") { return [.rgb(102, 153, 204), .rgb(102, 153, 204)] }
        if accountSearchText.contains("allegacy") || accountSearchText.contains("telluride") { return [.rgb(172, 31, 45), .rgb(172, 31, 45)] }
        if accountSearchText.contains("rocket") || accountSearchText.contains("mortgage") { return [.rgb(169, 39, 95), .rgb(169, 39, 95)] }
        if institution.contains("capital one") &&
            (accountSearchText.contains("t-mobile") ||
             accountSearchText.contains("tmobile") ||
             accountSearchText.contains("t mobile")) {
            return [.rgb(226, 0, 116), .rgb(226, 0, 116)]
        }
        if institution.contains("apple")          { return [Color(red: 0.11, green: 0.83, blue: 0.97), Color(red: 0.38, green: 0.83, blue: 0.98)] }
        if institution.contains("bank of america"){ return [Color(red: 0.97, green: 0.08, blue: 0.15), Color(red: 0.79, green: 0.05, blue: 0.17)] }
        if institution.contains("capital one")    { return [.rgb(4, 44, 67), .rgb(4, 44, 67)] }
        if institution.contains("chase")          { return [Color(red: 0.08, green: 0.49, blue: 0.84), Color(red: 0.10, green: 0.31, blue: 0.69)] }
        if institution.contains("citi")           { return [Color(red: 0.04, green: 0.27, blue: 0.54), Color(red: 0.09, green: 0.41, blue: 0.74)] }
        if accountType == .loan   { return [Color(red: 0.04, green: 0.37, blue: 0.52), Color(red: 0.11, green: 0.56, blue: 0.78)] }
        if accountType == .credit { return [Color(red: 1.00, green: 0.58, blue: 0.17), Color(red: 0.97, green: 0.78, blue: 0.07)] }
        return [Color.payCycleNavy, Color.payCycleBlue]
    }
}

private extension Color {
    static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }
}
