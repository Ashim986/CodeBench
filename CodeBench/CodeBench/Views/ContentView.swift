import SwiftUI

struct ContentView: View {
    @Bindable var loader: ResultsLoader
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            if loader.isLoaded {
                topicsView
            } else {
                loadingView
            }
        }
    }

    private var topicsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Topics")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)

                TopicBrowseView(loader: loader)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(white: 0.98))
        .navigationTitle("CodeBench")
    }

    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Test Results Viewer")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Load precomputed test results or select a test_results directory from your evaluator runs.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let error = loader.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 12) {
                Button {
                    loader.loadFromBundle()
                } label: {
                    Label("Load Bundled Data", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showFilePicker = true
                } label: {
                    Label("Load from Files", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color(white: 0.98))
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                loader.loadFromDirectory(url)
            }
        }
    }
}
