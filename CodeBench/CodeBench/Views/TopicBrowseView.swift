import SwiftUI

struct TopicBrowseView: View {
    @Bindable var loader: ResultsLoader

    private var topics: [TopicSummary] {
        loader.summary?.topics ?? []
    }

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(topics) { topic in
                NavigationLink(value: topic) {
                    topicRow(topic)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .navigationDestination(for: TopicSummary.self) { topic in
            TopicDetailView(topic: topic, loader: loader)
        }
    }

    private func topicRow(_ topic: TopicSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text("\(topic.matches)/\(topic.total) matched  ·  \(topic.invalid) invalid")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: topic.matchRate)
                    .stroke(rateColor(topic.matchRate), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(topic.matchRate * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(width: 40, height: 40)

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

    private func rateColor(_ rate: Double) -> Color {
        if rate >= 0.95 { return .green }
        if rate >= 0.7 { return .orange }
        return .red
    }
}

// MARK: - Topic Detail

struct TopicDetailView: View {
    let topic: TopicSummary
    @Bindable var loader: ResultsLoader

    private var topicData: TopicResults? {
        loader.topicResults[topic.topic]
    }

    private var problems: [ProblemMeta] {
        topicData?.problems ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topicMetrics
                    .padding(.horizontal, 16)

                if !problems.isEmpty {
                    ProblemBarChart(problems: problems)
                        .padding(.horizontal, 16)
                }

                Text("Problems")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)

                ProblemBrowseView(
                    problems: problems,
                    topic: topic.topic,
                    loader: loader
                )
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(white: 0.98))
        .navigationTitle(topic.displayName)
    }

    private var topicMetrics: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ],
            spacing: 8
        ) {
            metricCard(label: "Total Tests", value: "\(topic.total)")
            metricCard(label: "Match Rate", value: "\(Int(topic.matchRate * 100))%")
            metricCard(label: "Valid", value: "\(topic.valid)")
            metricCard(label: "Invalid", value: "\(topic.invalid)")
        }
    }

    private func metricCard(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(white: 0.95))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Problem Bar Chart

struct ProblemBarChart: View {
    let problems: [ProblemMeta]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Match Rate by Problem")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            GeometryReader { geo in
                chartContent(width: geo.size.width, height: geo.size.height - 24)
            }
            .frame(height: 180)
        }
        .padding(16)
        .background(Color(white: 0.95))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .primary.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func chartContent(width: CGFloat, height: CGFloat) -> some View {
        let data = problems.map { CGFloat($0.matchRate) }
        let labels = problems.map { abbreviate($0.slug) }
        let barWidth: CGFloat = max(8, min(28, (width - 40) / CGFloat(data.count)))
        let totalBars = CGFloat(data.count)
        let spacing = (width - barWidth * totalBars) / (totalBars + 1)

        return ZStack(alignment: .bottomLeading) {
            ForEach(0..<5, id: \.self) { gridIndex in
                let yPos = height * CGFloat(gridIndex) / 4
                Path { path in
                    path.move(to: CGPoint(x: 0, y: yPos))
                    path.addLine(to: CGPoint(x: width, y: yPos))
                }
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [4]))
            }

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<data.count, id: \.self) { index in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(data[index]))
                            .frame(width: barWidth, height: max(2, height * data[index]))

                        Text(index < labels.count ? labels[index] : "")
                            .font(.system(size: 6))
                            .foregroundColor(.secondary)
                            .frame(width: barWidth)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.leading, spacing)
        }
    }

    private func barColor(_ rate: CGFloat) -> Color {
        if rate >= 0.95 { return .green }
        if rate >= 0.7 { return .orange }
        return .red
    }

    private func abbreviate(_ slug: String) -> String {
        let parts = slug.split(separator: "-")
        if parts.count <= 2 { return String(slug.prefix(5)) }
        return parts.prefix(3).map { String($0.prefix(2)) }.joined()
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
