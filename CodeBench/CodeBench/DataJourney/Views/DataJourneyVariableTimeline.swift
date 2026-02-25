import LeetPulseDesignSystem
import SwiftUI

/// Collapsible timeline showing how each variable evolves across all playback steps.
/// Variable chips let the user filter which variables to track.
struct VariableTimelineView: View {
    let events: [DataJourneyEvent]
    let currentIndex: Int
    let onSelectIndex: (Int) -> Void

    @State private var isExpanded = false
    @State private var selectedVariables: Set<String> = []
    @State private var initialized = false
    @Environment(\.dsTheme) var theme
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        let variableNames = collectVariableNames()
        if !variableNames.isEmpty, events.count >= 2 {
            DSCard(config: DSCardConfig(style: .elevated, padding: 0)) {
                VStack(alignment: .leading, spacing: DSLayout.spacing(6)) {
                    timelineHeader(variableNames: variableNames)

                    if isExpanded {
                        timelineChips(variableNames: variableNames)

                        stepCounter

                        timelineContent(variableNames: variableNames)
                    }
                }
                .padding(DSLayout.spacing(8))
            }
            .onAppear {
                initializeSelection(variableNames: variableNames)
            }
            .onChange(of: variableNames) { _, newNames in
                initializeSelection(variableNames: newNames)
            }
        }
    }

    // MARK: - Header

    private func timelineHeader(variableNames _: [String]) -> some View {
        DSButton(
            "Timeline",
            config: .init(
                style: .ghost,
                size: .small,
                icon: Image(
                    systemName: isExpanded
                        ? "chevron.down"
                        : "chevron.right"
                ),
                iconPosition: .leading
            ),
            action: {
                withAnimation(
                    reduceMotion ? nil : .easeInOut(duration: 0.2)
                ) {
                    isExpanded.toggle()
                }
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Selectable Chips

    private func timelineChips(
        variableNames: [String]
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSLayout.spacing(6)) {
                ForEach(variableNames, id: \.self) { name in
                    chipView(name: name)
                }
            }
            .padding(.horizontal, DSLayout.spacing(2))
        }
    }

    private func chipView(name: String) -> some View {
        let isSelected = selectedVariables.contains(name)
        return DSActionButton(action: {
            toggleVariable(name)
        }, label: {
            Text(name)
                .font(VizTypography.secondaryInfo)
                .foregroundColor(
                    isSelected
                        ? theme.colors.primary
                        : theme.colors.textSecondary
                )
                .padding(.horizontal, DSLayout.spacing(8))
                .padding(.vertical, DSLayout.spacing(4))
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            isSelected
                                ? theme.colors.primary.opacity(0.15)
                                : theme.colors.surface
                        )
                )
        })
    }

    // MARK: - Step Counter

    private var stepCounter: some View {
        Text("Step \(currentIndex + 1) of \(events.count)")
            .font(VizTypography.secondaryInfo)
            .foregroundColor(theme.colors.textSecondary)
            .padding(.leading, DSLayout.spacing(4))
    }

    // MARK: - Timeline Content

    private func timelineContent(
        variableNames: [String]
    ) -> some View {
        let filtered = variableNames.filter {
            selectedVariables.contains($0)
        }
        return VStack(alignment: .leading, spacing: DSLayout.spacing(8)) {
            ForEach(filtered, id: \.self) { name in
                let series = extractSeries(for: name)
                HStack(
                    alignment: .center,
                    spacing: DSLayout.spacing(8)
                ) {
                    Text(name)
                        .font(VizTypography.secondaryInfo)
                        .foregroundColor(
                            theme.colors.border.opacity(0.7)
                        )
                        .frame(width: 60, alignment: .trailing)

                    timelineRow(series: series)
                }
            }
        }
        .padding(.leading, DSLayout.spacing(12))
    }

    // MARK: - Timeline Row

    @ViewBuilder
    private func timelineRow(
        series: [TimelinePoint]
    ) -> some View {
        let allNumeric = series.allSatisfy { $0.kind == .numeric }
        let allCollection = series.allSatisfy {
            $0.kind == .collection
        }

        if allNumeric {
            sparklineView(series: series)
        } else if allCollection {
            barChartView(series: series)
        } else {
            dotView(series: series)
        }
    }

    // MARK: - Data Extraction

    private func collectVariableNames() -> [String] {
        var names: [String] = []
        var seen: Set<String> = []
        for event in events {
            for key in event.values.keys.sorted()
                where seen.insert(key).inserted {
                names.append(key)
            }
        }
        return names
    }

    private func extractSeries(
        for name: String
    ) -> [TimelinePoint] {
        events.map { event in
            guard let value = event.values[name] else {
                return TimelinePoint(
                    kind: .null,
                    numericValue: nil,
                    collectionSize: nil
                )
            }
            return timelinePoint(from: value)
        }
    }

    private func timelinePoint(
        from value: TraceValue
    ) -> TimelinePoint {
        if case .null = value {
            return TimelinePoint(
                kind: .null,
                numericValue: nil,
                collectionSize: nil
            )
        }
        if case let .bool(boolValue) = value {
            return TimelinePoint(
                kind: boolValue ? .boolTrue : .boolFalse,
                numericValue: boolValue ? 1 : 0,
                collectionSize: nil
            )
        }
        if case .listPointer = value {
            return TimelinePoint(
                kind: .other,
                numericValue: nil,
                collectionSize: nil
            )
        }
        if case .treePointer = value {
            return TimelinePoint(
                kind: .other,
                numericValue: nil,
                collectionSize: nil
            )
        }
        if let size = value.collectionSize {
            return TimelinePoint(
                kind: .collection,
                numericValue: nil,
                collectionSize: size
            )
        }
        if let num = value.numericValue {
            return TimelinePoint(
                kind: .numeric,
                numericValue: num,
                collectionSize: nil
            )
        }
        return TimelinePoint(
            kind: .other,
            numericValue: nil,
            collectionSize: nil
        )
    }

    // MARK: - Helpers

    private func toggleVariable(_ name: String) {
        if selectedVariables.contains(name) {
            selectedVariables.remove(name)
        } else {
            selectedVariables.insert(name)
        }
    }

    private func initializeSelection(variableNames: [String]) {
        guard !initialized else { return }
        selectedVariables = Set(variableNames)
        initialized = true
    }
}

// MARK: - Supporting Types

struct TimelinePoint {
    enum Kind {
        case numeric
        case collection
        case boolTrue
        case boolFalse
        case null
        case other
    }

    let kind: Kind
    let numericValue: Double?
    let collectionSize: Int?
}
