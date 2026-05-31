import SwiftUI
import UIKit
#if canImport(FinanceKit)
import FinanceKit
#endif

struct SettingsView: View {
    let store: AccountsStore
    @State private var token = ""
    @State private var simpleFINSetupURL = ""
    @State private var showToken = false
    @State private var showSimpleFINSetupURL = false
    @State private var path: [SettingsRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            settingsRoot
                .navigationDestination(for: SettingsRoute.self) { route in
                    switch route {
                    case .simpleFIN:
                        simpleFINSettingsPage
                    case .lunchMoney:
                        lunchMoneySettingsPage
                    case .appleCard:
                        appleCardSettingsPage
                    }
                }
        }
        .tint(Color.payCycleSky)
    }

    private var settingsRoot: some View {
        ZStack(alignment: .top) {
            Color.payCycleDeepNavy
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 12) {
                        connectionsSection
                        appearanceSection
                        notificationsSection
                        aboutSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var connectionsSection: some View {
        SettingsSection(title: "Connections") {
            NavigationLink(value: SettingsRoute.simpleFIN) {
                SettingsDisclosureRow(label: "SimpleFIN", value: store.hasSavedSimpleFINSetupURL ? "Saved" : "Not saved")
            }
            Divider().background(Color.white.opacity(0.1))
            NavigationLink(value: SettingsRoute.lunchMoney) {
                SettingsDisclosureRow(label: "Lunch Money", value: store.hasSavedToken ? "Saved" : "Not saved")
            }
            Divider().background(Color.white.opacity(0.1))
            NavigationLink(value: SettingsRoute.appleCard) {
                SettingsDisclosureRow(label: "Apple Card", value: appleFinanceStatus)
            }
        }
    }

    private var simpleFINSettingsPage: some View {
        SettingsDetailPage(title: "SimpleFIN") {
            SettingsSection(title: "Connection") {
                simpleFINConnectionRows
            }
        }
    }

    private var appleCardSettingsPage: some View {
        SettingsDetailPage(title: "Apple Card") {
            SettingsSection(title: "Wallet Sync") {
                appleCardConnectionRows
            }
        }
    }

    private var appleFinanceStatus: String {
        guard !store.appleFinanceAccounts.isEmpty else { return "Not synced" }
        return "\(store.appleFinanceAccounts.count) accounts"
    }

    private var lunchMoneySettingsPage: some View {
        SettingsDetailPage(title: "Lunch Money") {
            SettingsSection(title: "Connection") {
                lunchMoneyConnectionRows
            }
        }
    }

    private var simpleFINConnectionRows: some View {
        Group {
            SettingsRow {
                HStack(spacing: 10) {
                    Group {
                        if showSimpleFINSetupURL {
                            TextField("Paste access URL", text: $simpleFINSetupURL)
                        } else {
                            SecureField("Paste access URL", text: $simpleFINSetupURL)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .tint(Color.payCycleSky)

                    Button(showSimpleFINSetupURL ? "Hide" : "Show") {
                        showSimpleFINSetupURL.toggle()
                    }
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.payCycleSky)
                }
            }

            Divider().background(Color.white.opacity(0.1))

            SettingsRow {
                Button {
                    if let str = UIPasteboard.general.string {
                        simpleFINSetupURL = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.payCycleSky)
                }
            }

            #if DEBUG
            if let devURL = ProcessInfo.processInfo.environment["DEV_SIMPLEFIN_SETUP_URL"], !devURL.isEmpty {
                Divider().background(Color.white.opacity(0.1))
                SettingsRow {
                    Button {
                        simpleFINSetupURL = devURL
                    } label: {
                        Label("Fill Dev URL", systemImage: "ladybug.fill")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(Color.payCycleDanger)
                    }
                }
            }
            #endif

            Divider().background(Color.white.opacity(0.1))

            SettingsRow {
                Button(store.hasSavedSimpleFINSetupURL ? "Update Access URL and Refresh" : "Save Access URL and Refresh") {
                    Task {
                        await store.saveSimpleFINSetupURL(simpleFINSetupURL)
                        simpleFINSetupURL = ""
                    }
                }
                .foregroundStyle(simpleFINSetupURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isLoading ? Color.payCycleSky.opacity(0.4) : Color.payCycleSky)
                .disabled(simpleFINSetupURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isLoading)
            }

            if store.hasSavedSimpleFINSetupURL {
                Divider().background(Color.white.opacity(0.1))

                SettingsRow {
                    Button("Refresh SimpleFIN") {
                        Task {
                            await store.reload()
                        }
                    }
                    .foregroundStyle(store.isLoading ? Color.payCycleSky.opacity(0.4) : Color.payCycleSky)
                    .disabled(store.isLoading)
                }

                Divider().background(Color.white.opacity(0.1))

                SettingsRow {
                    Button("Clear SimpleFIN URL", role: .destructive) {
                        Task {
                            await store.removeSimpleFINSetupURL()
                            simpleFINSetupURL = ""
                        }
                    }
                    .foregroundStyle(Color.payCycleDanger)
                }
            }

            if let simpleFINErrorMessage = store.simpleFINErrorMessage {
                Divider().background(Color.white.opacity(0.1))

                SettingsRow {
                    Text(simpleFINErrorMessage)
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.payCycleDanger)
                }
            }
        }
    }

    private var lunchMoneyConnectionRows: some View {
        Group {
            SettingsRow {
                HStack(spacing: 10) {
                    Group {
                        if showToken {
                            TextField("Paste API token", text: $token)
                        } else {
                            SecureField("Paste API token", text: $token)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .tint(Color.payCycleSky)

                    Button(showToken ? "Hide" : "Show") {
                        showToken.toggle()
                    }
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.payCycleSky)
                }
            }

            Divider().background(Color.white.opacity(0.1))

            SettingsRow {
                Button {
                    if let str = UIPasteboard.general.string {
                        token = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.payCycleSky)
                }
            }

            #if DEBUG
            if let devToken = ProcessInfo.processInfo.environment["DEV_API_TOKEN"], !devToken.isEmpty {
                Divider().background(Color.white.opacity(0.1))
                SettingsRow {
                    Button {
                        token = devToken
                    } label: {
                        Label("Fill Dev Token", systemImage: "ladybug.fill")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(Color.payCycleDanger)
                    }
                }
            }
            #endif

            Divider().background(Color.white.opacity(0.1))

            SettingsRow {
                Button(store.hasSavedToken ? "Update Token and Refresh" : "Save Token and Refresh") {
                    Task {
                        await store.saveToken(token)
                        token = ""
                    }
                }
                .foregroundStyle(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isLoading ? Color.payCycleSky.opacity(0.4) : Color.payCycleSky)
                .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isLoading)
            }

            Divider().background(Color.white.opacity(0.1))

            SettingsRow {
                Button("Refresh Linked Accounts") {
                    Task {
                        await store.reload(triggerSync: true)
                    }
                }
                .foregroundStyle(store.isLoading ? Color.payCycleSky.opacity(0.4) : Color.payCycleSky)
                .disabled(store.isLoading)
            }

            if store.hasSavedToken {
                Divider().background(Color.white.opacity(0.1))

                SettingsRow {
                    Button("Clear Saved Token", role: .destructive) {
                        Task {
                            await store.removeSavedToken()
                            token = ""
                        }
                    }
                    .foregroundStyle(Color.payCycleDanger)
                }
            }
        }
    }

    @ViewBuilder
    private var appleCardConnectionRows: some View {
        #if canImport(FinanceKit)
        SettingsRow {
            VStack(alignment: .leading, spacing: 8) {
                Text("Authorize PayCycle to access eligible Wallet account balances and transactions, including Apple Card, Apple Savings, and Apple Cash.")
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Authorization: \(store.appleFinanceAuthorizationStatus)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))

                if let lastSyncedAt = store.appleFinanceLastSyncedAt {
                    Text("Last synced \(DisplayFormatter.relativeDate(lastSyncedAt))")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }

        Divider().background(Color.white.opacity(0.1))

        SettingsRow {
            Button {
                Task {
                    await store.refreshAppleFinanceData()
                }
            } label: {
                Label(store.isSyncingAppleFinance ? "Syncing Wallet Data..." : "Connect and Sync Wallet Data", systemImage: "creditcard.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(store.isSyncingAppleFinance ? Color.payCycleSky.opacity(0.4) : Color.payCycleSky)
            }
            .disabled(store.isSyncingAppleFinance)
        }

        if !store.appleFinanceAccounts.isEmpty || !store.appleFinanceTransactions.isEmpty {
            Divider().background(Color.white.opacity(0.1))

            SettingsRow {
                Button("Clear Apple Wallet Data", role: .destructive) {
                    store.clearAppleFinanceTransactions()
                }
                .foregroundStyle(Color.payCycleDanger)
            }
        }

        if !store.appleFinanceAccounts.isEmpty {
            Divider().background(Color.white.opacity(0.1))

            SettingsRow {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(store.appleFinanceAccounts) { account in
                        AppleFinanceAccountRow(account: account)
                    }
                }
            }
        }

        if !store.appleFinanceTransactions.isEmpty {

            Divider().background(Color.white.opacity(0.1))

            SettingsRow {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(store.appleFinanceTransactions.prefix(5)) { transaction in
                        AppleFinanceTransactionRow(transaction: transaction)
                    }

                    if store.appleFinanceTransactions.count > 5 {
                        Text("+ \(store.appleFinanceTransactions.count - 5) more")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }

        if let errorMessage = store.appleFinanceErrorMessage {
            Divider().background(Color.white.opacity(0.1))

            SettingsRow {
                Text(errorMessage)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.payCycleDanger)
            }
        }
        #else
        SettingsRow {
            Text("Apple Wallet sync requires FinanceKit.")
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(Color.payCycleDanger)
        }
        #endif
    }

    private var appearanceSection: some View {
        SettingsSection(title: "Appearance") {
            StatusRow(label: "Dark Mode", value: "On")
            Divider().background(Color.white.opacity(0.1))
            StatusRow(label: "App Icon", value: "Default")
        }
    }

    private var notificationsSection: some View {
        SettingsSection(title: "Notifications") {
            StatusRow(label: "Coming Soon", value: "")
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            StatusRow(label: "Version", value: appVersion)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (.some(version), .some(build)) where !build.isEmpty:
            return "\(version) (\(build))"
        case let (.some(version), _):
            return version
        case (_, let .some(build)):
            return build
        default:
            return "Unknown"
        }
    }
}

private enum SettingsRoute: Hashable {
    case simpleFIN
    case lunchMoney
    case appleCard
}

private struct SettingsDetailPage<Content: View>: View {
    let title: String
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            Color.payCycleDeepNavy
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.payCycleSky)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Back")

                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 24)

                ScrollView {
                    VStack(spacing: 12) {
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 4)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.payCycleCardNavy)
            )
        }
    }
}

private struct SettingsDisclosureRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.32))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct AppleFinanceAccountRow: View {
    let account: AppleFinanceAccountSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.displayName)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("\(account.institutionName) · \(account.kind)")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                if let bookedBalance = account.bookedBalance {
                    Text(DisplayFormatter.currency(bookedBalance, code: account.currencyCode))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            if let availableBalance = account.availableBalance {
                Text("Available \(DisplayFormatter.currency(availableBalance, code: account.currencyCode))")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
    }
}

private struct AppleFinanceTransactionRow: View {
    let transaction: AppleFinanceTransactionSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(transaction.transactionDate, style: .date)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            Text(DisplayFormatter.currency(transaction.amount, code: transaction.currencyCode))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
    }
}

private struct SettingsRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }
}

private struct StatusRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
