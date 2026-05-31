import SwiftUI

extension Color {
    static let payCycleBlue = Color(red: 0.15, green: 0.50, blue: 0.93)
    static let payCycleSky = Color(red: 0.29, green: 0.71, blue: 1.00)
    static let payCycleNavy = Color(red: 0.08, green: 0.18, blue: 0.39)
    static let payCycleInk = Color(red: 0.12, green: 0.18, blue: 0.32)
    static let payCycleSoft = Color(red: 0.47, green: 0.56, blue: 0.74)
    static let payCycleDanger = Color(red: 0.95, green: 0.39, blue: 0.35)
    static let payCycleSuccess = Color(red: 0.17, green: 0.70, blue: 0.43)

    // Deep navy theme: identical in light and dark mode.
    static let payCycleDeepNavy = Color(.sRGB, red: 2 / 255, green: 9 / 255, blue: 18 / 255, opacity: 1)
    static let payCycleCardNavy = Color(.sRGB, red: 1 / 255, green: 20 / 255, blue: 50 / 255, opacity: 1)
    static let payCyclePillBorder = Color.payCycleBlue.opacity(0.5)
}

enum DisplayFormatter {
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static func currency(_ value: Decimal, code: String = "USD") -> String {
        currencyFormatter.currencyCode = code.uppercased()
        return currencyFormatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    static func percent(_ value: Decimal) -> String {
        percentFormatter.string(from: value as NSDecimalNumber) ?? "0%"
    }

    static func relativeDate(_ value: Date?) -> String {
        guard let value else { return "No recent sync" }
        return relativeFormatter.localizedString(for: value, relativeTo: .now)
    }
}

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)
            )
    }
}

extension View {
    func glassCardStyle() -> some View {
        modifier(GlassCardStyle())
    }
}
