import SwiftUI

struct SolutionView: View {
    let problem: ProblemMeta
    let results: [TestResult]

    @State private var selectedResultIndex = 0
    @State private var selectedEventID: String?
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Test case picker
                if results.count > 1 {
                    testCasePicker
                        .padding(.horizontal, 16)
                }

                if !results.isEmpty {
                    let result = results[selectedResultIndex]
                    let events = TestResultBridge.events(from: result)

                    // Status badge
                    statusBadge(result)
                        .padding(.horizontal, 16)

                    // Side-by-side: Code + Visualization
                    if sizeClass == .regular {
                        // iPad / wide: horizontal split
                        HStack(alignment: .top, spacing: 12) {
                            codePanel(result)
                                .frame(maxWidth: .infinity)

                            vizPanel(events: events)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 16)
                    } else {
                        // iPhone: stacked vertically, code always visible
                        codePanel(result)
                            .padding(.horizontal, 16)

                        vizPanel(events: events)
                            .padding(.horizontal, 16)
                    }
                } else {
                    noResultsView
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(white: 0.98))
        .navigationTitle(problem.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Code Panel (always visible)

    private func codePanel(_ result: TestResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)
                Text("Test Data")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()
                .padding(.horizontal, 8)

            // Input
            codeSection(
                icon: "arrow.right.circle.fill",
                iconColor: .blue,
                label: "INPUT",
                text: result.input,
                lineNumbers: true
            )

            Divider()
                .padding(.horizontal, 8)

            // Expected
            codeSection(
                icon: "target",
                iconColor: .orange,
                label: "EXPECTED",
                text: result.originalExpected,
                lineNumbers: false
            )

            Divider()
                .padding(.horizontal, 8)

            // Computed Output
            codeSection(
                icon: result.outputMatches ? "checkmark.circle.fill" : "xmark.circle.fill",
                iconColor: result.outputMatches ? .green : .red,
                label: "COMPUTED",
                text: result.computedOutput,
                lineNumbers: false
            )

            // Error message if present
            if let error = result.errorMessage {
                Divider()
                    .padding(.horizontal, 8)
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 10))
                    Text(error)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // Order badge
            if result.orderMatters {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 8))
                    Text("Order matters")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func codeSection(
        icon: String,
        iconColor: Color,
        label: String,
        text: String,
        lineNumbers: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 12)
            .padding(.top, 8)

            // Code content
            if lineNumbers {
                numberedCode(text)
            } else {
                Text(text)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.bottom, 8)
    }

    private func numberedCode(_ text: String) -> some View {
        let params = text.components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            // Re-join items that were split mid-bracket
            .reduce(into: [String]()) { result, part in
                if let last = result.last,
                   last.filter({ $0 == "[" }).count > last.filter({ $0 == "]" }).count {
                    result[result.count - 1] = last + ", " + part
                } else {
                    result.append(part)
                }
            }

        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(params.enumerated()), id: \.offset) { index, param in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(index + 1)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5))
                        .frame(width: 14, alignment: .trailing)

                    Text(param)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Visualization Panel

    private func vizPanel(events: [DataJourneyEvent]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.cyan)
                Text("Data Journey")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()
                .padding(.horizontal, 8)

            DataJourneyView(
                events: events,
                selectedEventID: $selectedEventID,
                onSelectEvent: { _ in },
                isTruncated: false,
                sourceCode: ""
            )
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Test Case Picker

    private var testCasePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test Cases")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                        Button {
                            selectedResultIndex = index
                            selectedEventID = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: result.outputMatches ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(result.outputMatches ? .green : .red)

                                Text("#\(index + 1)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(index == selectedResultIndex
                                          ? Color.blue.opacity(0.15)
                                          : Color(white: 0.95))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(index == selectedResultIndex ? Color.blue : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Status Badge

    private func statusBadge(_ result: TestResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: result.outputMatches ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.outputMatches ? .green : .red)

            Text(result.outputMatches ? "Output Matches Expected" : "Output Does Not Match")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            if !result.isValid {
                Text("INVALID")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red)
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(result.outputMatches ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
        )
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("No test results available for this problem.")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}
