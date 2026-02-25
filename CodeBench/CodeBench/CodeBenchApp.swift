import SwiftUI

@main
struct CodeBenchApp: App {
    @State private var loader = ResultsLoader()

    var body: some Scene {
        WindowGroup {
            ContentView(loader: loader)
        }
    }
}
