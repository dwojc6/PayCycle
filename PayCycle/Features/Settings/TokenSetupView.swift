import SwiftUI
import UIKit

struct TokenSetupView: View {
    let store: AccountsStore

    @State private var token = ""
    @State private var showsToken = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.white
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.payCycleBlue, Color.payCycleSky.opacity(0.7), Color.white.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)
            .ignoresSafeArea(edges: .top)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PayCycle")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Connect Lunch Money")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.payCycleNavy)

                        Text("Paste your Lunch Money API token to load your linked Plaid accounts and start building the rest of the app around your real data.")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(Color.payCycleInk.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 42)

                    VStack(alignment: .leading, spacing: 18) {
                        Text("Lunch Money API Token")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.payCycleNavy)

                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Group {
                                    if showsToken {
                                        TextField("Paste token here", text: $token)
                                    } else {
                                        SecureField("Paste token here", text: $token)
                                    }
                                }
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))

                                Button(showsToken ? "Hide" : "Show") {
                                    showsToken.toggle()
                                }
                                .font(.system(.footnote, design: .rounded, weight: .bold))
                                .foregroundStyle(Color.payCycleBlue)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(.systemGray6))
                            )

                            Button {
                                if let clipboard = UIPasteboard.general.string {
                                    token = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            } label: {
                                Label("Paste From Clipboard", systemImage: "doc.on.clipboard")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Color.payCycleBlue)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            #if DEBUG
                            if let devToken = ProcessInfo.processInfo.environment["DEV_API_TOKEN"], !devToken.isEmpty {
                                Button {
                                    token = devToken
                                } label: {
                                    Label("Fill Dev Token", systemImage: "ladybug.fill")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(Color.payCycleDanger)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            #endif
                        }

                        Button {
                            Task {
                                await store.saveToken(token)
                                token = ""
                            }
                        } label: {
                            HStack {
                                if store.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                }

                                Text(store.isLoading ? "Connecting..." : "Connect Lunch Money")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(LinearGradient(colors: [Color.payCycleBlue, Color.payCycleNavy], startPoint: .leading, endPoint: .trailing))
                            )
                        }
                        .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isLoading)

                        if let errorMessage = store.errorMessage {
                            Text(errorMessage)
                                .font(.system(.footnote, design: .rounded, weight: .medium))
                                .foregroundStyle(Color.payCycleDanger)
                        }
                    }
                    .padding(24)
                    .glassCardStyle()

                    VStack(alignment: .leading, spacing: 14) {
                        SetupTipRow(
                            icon: "key.fill",
                            title: "Where to get it",
                            bodyText: "Create a token from the Developers page in Lunch Money, then paste it here once."
                        )

                        SetupTipRow(
                            icon: "lock.fill",
                            title: "How it’s stored",
                            bodyText: "The token is saved in your iPhone keychain so the app can refresh your accounts on future launches."
                        )

                        SetupTipRow(
                            icon: "arrow.trianglehead.clockwise",
                            title: "What happens next",
                            bodyText: "PayCycle will call Lunch Money and immediately load your linked Plaid accounts into the Accounts tab."
                        )
                    }
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct SetupTipRow: View {
    let icon: String
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.payCycleBlue)
                .frame(width: 28, height: 28)
                .background(Color.payCycleBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.payCycleNavy)

                Text(bodyText)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.payCycleInk.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
