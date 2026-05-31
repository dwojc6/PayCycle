import SwiftUI

struct AccountRowView: View {
    let account: AnyAccount
    let store: AccountsStore

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            AccountBadgeView(account: account)

            HStack(alignment: .top, spacing: 0) {
                metricColumn(
                    title: account.accountType == .cash ? "Available" : "Balance",
                    value: DisplayFormatter.currency(store.displayedAmount(for: account), code: account.currency),
                    accent: Color.white
                )
                .frame(maxWidth: .infinity, alignment: .center)

                if let utilization = account.utilization {
                    metricColumn(
                        title: "Utilized",
                        value: DisplayFormatter.percent(utilization),
                        accent: Color.payCycleSuccess
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if let limit = account.limit {
                    metricColumn(
                        title: "Limit",
                        value: DisplayFormatter.currency(limit, code: account.currency),
                        accent: Color.white.opacity(0.55)
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    metricColumn(
                        title: "Updated",
                        value: DisplayFormatter.relativeDate(account.updateDate),
                        accent: Color.white.opacity(0.55)
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.payCycleDeepNavy)
    }

    private func metricColumn(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
}
