import SwiftUI
import LeetPulseDesignSystem

struct TopicBrowseView: View {
    @Bindable var loader: ResultsLoader
    var searchText: String
    @Environment(\.dsTheme) private var theme
    @State private var expandedTopics: Set<String> = []

    private var topics: [TopicSummary] {
        loader.summary?.topics ?? []
    }

    var body: some View {
        LazyVStack(spacing: theme.spacing.md) {
            let filtered = filteredTopics
            if filtered.isEmpty && !searchText.isEmpty {
                noResultsView
            } else {
                ForEach(filtered, id: \.topic) { topic in
                    topicCard(topic)
                }
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .navigationDestination(for: ProblemMeta.self) { problem in
            SolutionView(
                problem: problem,
                results: loader.resultsForProblem(problem.slug, topic: problem.topic)
            )
        }
    }

    // MARK: - Filtering

    private var filteredTopics: [(topic: TopicSummary, problems: [ProblemMeta])] {
        topics.compactMap { topic in
            let problems = loader.topicResults[topic.topic]?.problems ?? []
            if searchText.isEmpty {
                return problems.isEmpty ? nil : (topic, problems)
            }
            let query = searchText.lowercased()
            let matched = problems.filter {
                $0.displayName.lowercased().contains(query)
                    || ($0.leetCodeNumber != 0 && "\($0.leetCodeNumber)".contains(query))
            }
            return matched.isEmpty ? nil : (topic, matched)
        }
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: theme.spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(theme.colors.textSecondary)
            Text("No problems found")
                .font(theme.typography.subtitle)
                .foregroundColor(theme.colors.textSecondary)
            Text("Try a different search term")
                .font(theme.typography.caption)
                .foregroundColor(theme.colors.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Topic Card

    private func topicCard(_ entry: (topic: TopicSummary, problems: [ProblemMeta])) -> some View {
        let topic = entry.topic
        let problems = entry.problems
        let isExpanded = expandedTopics.contains(topic.topic)

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            topicHeader(topic: topic, problemCount: problems.count, isExpanded: isExpanded)

            Divider()
                .background(theme.colors.border)

            // Problem rows
            VStack(spacing: 1) {
                if isExpanded {
                    expandedContent(problems: problems)
                } else {
                    collapsedContent(problems: problems)
                }
            }
            .padding(.vertical, theme.spacing.xs)

            // Toggle button
            if problems.count > 4 {
                Divider()
                    .background(theme.colors.border)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if isExpanded {
                            expandedTopics.remove(topic.topic)
                        } else {
                            expandedTopics.insert(topic.topic)
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text(isExpanded ? "Show less" : "Show all \(problems.count) problems")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.colors.primary)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.colors.primary)
                        Spacer()
                    }
                    .padding(.vertical, theme.spacing.sm)
                }
            }
        }
        .background(theme.colors.surface)
        .cornerRadius(theme.radii.lg)
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.lg)
                .stroke(theme.colors.border, lineWidth: 1)
        )
    }

    private func topicHeader(topic: TopicSummary, problemCount: Int, isExpanded: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(topic.displayName)
                    .font(theme.typography.subtitle)
                    .foregroundColor(theme.colors.textPrimary)

                Text("\(problemCount) problems")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.colors.textSecondary)
            }
            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.colors.textSecondary)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                if isExpanded {
                    expandedTopics.remove(topic.topic)
                } else {
                    expandedTopics.insert(topic.topic)
                }
            }
        }
    }

    // MARK: - Collapsed / Expanded Content

    private func collapsedContent(problems: [ProblemMeta]) -> some View {
        ForEach(problems.prefix(4)) { problem in
            problemRow(problem)
        }
    }

    private func expandedContent(problems: [ProblemMeta]) -> some View {
        let grouped = Dictionary(grouping: problems) { $0.difficulty.capitalized }
        let order = ["Easy", "Medium", "Hard"]
        let sortedKeys = order.filter { grouped[$0] != nil }

        return ForEach(sortedKeys, id: \.self) { difficulty in
            if let group = grouped[difficulty] {
                // Difficulty sub-header
                Text(difficulty)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.colors.textSecondary)
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.top, theme.spacing.sm)
                    .padding(.bottom, theme.spacing.xs)

                ForEach(group) { problem in
                    problemRow(problem)
                }
            }
        }
    }

    // MARK: - Problem Row

    private func problemRow(_ problem: ProblemMeta) -> some View {
        NavigationLink(value: problem) {
            HStack(spacing: theme.spacing.sm) {
                if problem.leetCodeNumber != 0 {
                    Text("#\(problem.leetCodeNumber)")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 44, alignment: .leading)
                }

                Text(problem.displayName)
                    .font(theme.typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                DSBadge(text: problem.difficulty.capitalized, difficultyLevel: problem.difficulty.capitalized)
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.sm)
            .background(theme.colors.surfaceElevated)
            .cornerRadius(theme.radii.sm)
            .padding(.horizontal, theme.spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hashable conformance for navigation

extension TopicSummary: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(topic)
    }
    static func == (lhs: TopicSummary, rhs: TopicSummary) -> Bool {
        lhs.topic == rhs.topic
    }
}

extension ProblemMeta: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(slug)
    }
    static func == (lhs: ProblemMeta, rhs: ProblemMeta) -> Bool {
        lhs.slug == rhs.slug
    }
}
