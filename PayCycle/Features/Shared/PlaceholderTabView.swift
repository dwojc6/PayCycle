import SwiftUI

struct PlaceholderTabView: View {
    let title: String
    let systemImage: String
    let bodyText: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: systemImage)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Color.payCycleBlue)

                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(bodyText)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.payCycleDeepNavy)
            .navigationTitle(title)
        }
    }
}
