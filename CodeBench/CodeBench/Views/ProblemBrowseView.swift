import SwiftUI

struct ProblemBrowseView: View {
    let problems: [ProblemMeta]
    let topic: String
    @Bindable var loader: ResultsLoader

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(problems) { problem in
                NavigationLink(value: problem) {
                    problemRow(problem)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .navigationDestination(for: ProblemMeta.self) { problem in
            SolutionView(
                problem: problem,
                results: loader.resultsForProblem(problem.slug, topic: problem.topic)
            )
        }
    }

    private func problemRow(_ problem: ProblemMeta) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor(problem))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(problem.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("\(problem.validTests)/\(problem.totalTests) valid  ·  \(problem.invalidTests) invalid")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(problem.matchRate * 100))%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(statusColor(problem))
                            .frame(width: geo.size.width * problem.matchRate, height: 4)
                    }
                }
                .frame(width: 60, height: 4)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(white: 0.95))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private func statusColor(_ problem: ProblemMeta) -> Color {
        if problem.matchRate >= 0.95 { return .green }
        if problem.matchRate >= 0.7 { return .orange }
        return .red
    }
}

// MARK: - Hashable conformance for navigation

extension ProblemMeta: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(slug)
    }
    static func == (lhs: ProblemMeta, rhs: ProblemMeta) -> Bool {
        lhs.slug == rhs.slug
    }
}
