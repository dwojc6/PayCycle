import SwiftUI

struct AccountsSummaryCard: View {
    let snapshot: AccountsSnapshot
    let store: AccountsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Metrics row
            HStack(alignment: .top, spacing: 0) {
                SummaryMetric(
                    color: Color.payCycleSky,
                    title: "Assets",
                    value: DisplayFormatter.currency(snapshot.assets)
                )
                SummaryMetric(
                    color: Color.payCycleDanger,
                    title: "Debt",
                    value: DisplayFormatter.currency(snapshot.debt)
                )
            }

            Divider()

            // Breakdown
            VStack(alignment: .leading, spacing: 0) {
                ForEach(snapshot.sections) { section in
                    HStack(spacing: 12) {
Text(section.type.title)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(DisplayFormatter.currency(section.total))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.payCycleCardNavy)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.payCyclePillBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(Color.payCycleDeepNavy)
    }
}

private struct SummaryMetric: View {
    let color: Color
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
