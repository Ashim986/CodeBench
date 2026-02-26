import SwiftUI
import LeetPulseDesignSystem

struct SolutionView: View {
    let problem: ProblemMeta
    let results: [TestResult]

    @State private var selectedResultIndex = 0
    @State private var selectedEventID: String?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dsTheme) private var theme

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
        .background(theme.colors.background)
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
                    .foregroundColor(theme.colors.primary)
                Text("Test Data")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.colors.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()
                .background(theme.colors.border)
                .padding(.horizontal, 8)

            // Input
            codeSection(
                icon: "arrow.right.circle.fill",
                iconColor: theme.colors.primary,
                label: "INPUT",
                text: result.input,
                lineNumbers: true
            )

            Divider()
                .background(theme.colors.border)
                .padding(.horizontal, 8)

            // Expected
            codeSection(
                icon: "target",
                iconColor: theme.colors.warning,
                label: "EXPECTED",
                text: result.originalExpected,
                lineNumbers: false
            )

            Divider()
                .background(theme.colors.border)
                .padding(.horizontal, 8)

            // Computed Output
            codeSection(
                icon: result.outputMatches ? "checkmark.circle.fill" : "xmark.circle.fill",
                iconColor: result.outputMatches ? theme.colors.success : theme.colors.danger,
                label: "COMPUTED",
                text: result.computedOutput,
                lineNumbers: false
            )

            // Error message if present
            if let error = result.errorMessage {
                Divider()
                    .background(theme.colors.border)
                    .padding(.horizontal, 8)
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.colors.warning)
                        .font(.system(size: 10))
                    Text(error)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(theme.colors.danger)
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
                .foregroundColor(theme.colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: theme.radii.md)
                .fill(theme.colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.md)
                .stroke(theme.colors.border, lineWidth: 1)
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
            // Label with copy button
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(theme.colors.textSecondary)

                Spacer()

                CopyButton(text: text, theme: theme)
            }
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .padding(.top, 8)

            // Code content
            if lineNumbers {
                numberedCode(text)
            } else {
                Text(text)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.colors.textPrimary)
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
                        .foregroundColor(theme.colors.textSecondary.opacity(0.5))
                        .frame(width: 14, alignment: .trailing)

                    Text(param)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.colors.textPrimary)
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
                    .foregroundColor(theme.colors.accent)
                Text("Data Journey")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.colors.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()
                .background(theme.colors.border)
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
            RoundedRectangle(cornerRadius: theme.radii.md)
                .fill(theme.colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.md)
                .stroke(theme.colors.border, lineWidth: 1)
        )
    }

    // MARK: - Test Case Picker

    private var testCasePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test Cases")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(theme.colors.textSecondary)
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
                                    .foregroundColor(result.outputMatches ? theme.colors.success : theme.colors.danger)

                                Text("#\(index + 1)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(theme.colors.textPrimary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: theme.radii.sm)
                                    .fill(index == selectedResultIndex
                                          ? theme.colors.primary.opacity(0.2)
                                          : theme.colors.surfaceElevated)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.radii.sm)
                                    .stroke(index == selectedResultIndex ? theme.colors.primary : Color.clear, lineWidth: 1)
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
                .foregroundColor(result.outputMatches ? theme.colors.success : theme.colors.danger)

            Text(result.outputMatches ? "Output Matches Expected" : "Output Does Not Match")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.colors.textPrimary)

            Spacer()

            if !result.isValid {
                Text("INVALID")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.colors.danger)
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.sm)
                .fill(result.outputMatches ? theme.colors.success.opacity(0.15) : theme.colors.danger.opacity(0.15))
        )
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(theme.colors.textSecondary)

            Text("No test results available for this problem.")
                .font(.body)
                .foregroundColor(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

// MARK: - Copy Button

private struct CopyButton: View {
    let text: String
    let theme: DSTheme
    @State private var copied = false

    var body: some View {
        Button {
            #if os(iOS)
            UIPasteboard.general.string = text
            #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            #endif
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 9))
                .foregroundColor(copied ? theme.colors.success : theme.colors.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copied ? "Copied" : "Copy to clipboard")
    }
}
