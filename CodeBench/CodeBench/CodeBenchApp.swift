import SwiftUI
import LeetPulseDesignSystem

@main
struct CodeBenchApp: App {
    @State private var loader = ResultsLoader()

    var body: some Scene {
        WindowGroup {
            DSThemeProvider(theme: .dark) {
                ContentView(loader: loader)
                    .onAppear {
                        if !loader.isLoaded {
                            loader.loadFromBundle()
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
    }
}
