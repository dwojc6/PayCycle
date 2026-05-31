import SwiftUI

@main
struct PayCycleApp: App {
    @State private var store = AccountsStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
