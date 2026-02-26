import SwiftUI
import LeetPulseDesignSystem

struct ContentView: View {
    @Bindable var loader: ResultsLoader
    @Environment(\.dsTheme) private var theme
    @State private var showFilePicker = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

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
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text("Problem Selection")
                        .font(theme.typography.title)
                        .foregroundColor(theme.colors.textPrimary)

                    Text("Browse and practice LeetCode problems by topic")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.colors.textSecondary)
                }
                .padding(.horizontal, theme.spacing.lg)

                // Search bar
                HStack(spacing: theme.spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(
                            isSearchFocused
                                ? theme.colors.primary
                                : theme.colors.textSecondary
                        )

                    TextField("Search problems...", text: $searchText)
                        .font(theme.typography.body)
                        .foregroundColor(theme.colors.textPrimary)
                        .focused($isSearchFocused)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(theme.colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, theme.spacing.md)
                .padding(.vertical, theme.spacing.sm)
                .background(theme.colors.surfaceElevated)
                .cornerRadius(theme.radii.md)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.md)
                        .stroke(
                            isSearchFocused
                                ? theme.colors.primary
                                : theme.colors.border,
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, theme.spacing.lg)

                TopicBrowseView(loader: loader, searchText: searchText)
            }
            .padding(.top, theme.spacing.sm)
            .padding(.bottom, 32)
        }
        .background(theme.colors.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var loadingView: some View {
        VStack(spacing: theme.spacing.xl) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 64))
                .foregroundColor(theme.colors.primary)

            Text("CodeBench")
                .font(theme.typography.title)
                .foregroundColor(theme.colors.textPrimary)

            Text("Load precomputed test results or select a test_results directory from your evaluator runs.")
                .font(theme.typography.body)
                .foregroundColor(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xl)

            if let error = loader.errorMessage {
                Text(error)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.colors.danger)
                    .padding(.horizontal, theme.spacing.lg)
            }

            VStack(spacing: theme.spacing.md) {
                Button {
                    loader.loadFromBundle()
                } label: {
                    Label("Load Bundled Data", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.colors.primary)

                Button {
                    showFilePicker = true
                } label: {
                    Label("Load from Files", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(theme.colors.primary)
            }
            .padding(.horizontal, theme.spacing.xl)

            Spacer()
        }
        .background(theme.colors.background)
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
