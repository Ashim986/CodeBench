import LeetPulseDesignSystem
import SwiftUI

extension DataJourneyView {
    enum StepControlsStyle {
        case standalone
        case embedded
    }

    func stepControls(
        style: StepControlsStyle = .standalone
    ) -> some View {
        let isEmbedded = style == .embedded
        let iconSize: CGFloat = isEmbedded ? 9 : 10
        let textSize: CGFloat = isEmbedded ? 9 : 10
        let spacing: CGFloat = isEmbedded ? 6 : 8
        let pickerWidth: CGFloat = isEmbedded ? 140 : 160

        return DSCard(
            config: DSCardConfig(
                style: .elevated,
                padding: isEmbedded ? 0 : 10
            )
        ) {
            VStack(alignment: .leading, spacing: spacing) {
                stepControlsHeader(
                    iconSize: iconSize,
                    textSize: textSize,
                    spacing: spacing,
                    pickerWidth: pickerWidth,
                    isEmbedded: isEmbedded
                )

                stepControlsTimeline(style: style)
            }
        }
        .accessibilityIdentifier("dataJourney.playbackControls")
    }

    func stepControlsHeader(
        style: StepControlsStyle = .standalone
    ) -> some View {
        let isEmbedded = style == .embedded
        let iconSize: CGFloat = isEmbedded ? 9 : 10
        let textSize: CGFloat = isEmbedded ? 9 : 10
        let spacing: CGFloat = isEmbedded ? 6 : 8
        let pickerWidth: CGFloat = isEmbedded ? 140 : 160

        return stepControlsHeader(
            iconSize: iconSize,
            textSize: textSize,
            spacing: spacing,
            pickerWidth: pickerWidth,
            isEmbedded: isEmbedded
        )
    }

    func stepControlsTimeline(
        style: StepControlsStyle = .standalone
    ) -> some View {
        let isEmbedded = style == .embedded
        let textSize: CGFloat = isEmbedded ? 9 : 10
        let chipFontSize: CGFloat = isEmbedded ? 9 : 10
        let chipVerticalPadding: CGFloat = isEmbedded ? 4 : 6

        return VStack(
            alignment: .leading,
            spacing: isEmbedded ? 6 : 8
        ) {
            // Text-only step counter replaces slider
            Text(
                "Step \(currentPlaybackIndex + 1) of \(playbackEvents.count)"
            )
            .font(VizTypography.secondaryInfo)
            .foregroundColor(theme.colors.textSecondary)

            if isTruncated {
                HStack(spacing: DSLayout.spacing(6)) {
                    Image(
                        systemName: "exclamationmark.triangle.fill"
                    )
                    .font(
                        VizTypography.labelSemibold(size: textSize)
                    )
                    .foregroundColor(theme.vizColors.primary)
                    Text(truncationMessage)
                        .font(
                            VizTypography.labelMedium(
                                size: isEmbedded ? 8 : 9
                            )
                        )
                        .foregroundColor(theme.vizColors.primary)
                }
            }

            timelineChips(
                chipFontSize: chipFontSize,
                chipVerticalPadding: chipVerticalPadding
            )
        }
    }

    // MARK: - Timeline Chips

    private func timelineChips(
        chipFontSize: CGFloat,
        chipVerticalPadding: CGFloat
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSLayout.spacing(6)) {
                ForEach(playbackEvents) { event in
                    let chipActive = event.id == selectedEventID
                    DSActionButton(action: {
                        animationController.onUserStepClick()
                        selectEvent(event)
                    }, label: {
                        HStack(spacing: DSLayout.spacing(6)) {
                            Circle()
                                .fill(
                                    chipActive
                                        ? theme.vizColors.quinary
                                        : theme.colors.textSecondary
                                        .opacity(0.85)
                                )
                                .frame(width: 6, height: 6)
                            Text(stepLabel(for: event))
                                .font(
                                    VizTypography.labelSemibold(
                                        size: chipFontSize
                                    )
                                )
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .padding(
                            .horizontal,
                            DSLayout.spacing(8)
                        )
                        .padding(
                            .vertical,
                            chipVerticalPadding
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    chipActive
                                        ? theme.vizColors.quinary
                                        .opacity(0.2)
                                        : theme.colors
                                        .surfaceElevated
                                        .opacity(0.95)
                                )
                        )
                    })
                }
            }
            .padding(.horizontal, DSLayout.spacing(2))
        }
    }

    // MARK: - Header

    private func stepControlsHeader(
        iconSize: CGFloat,
        textSize: CGFloat,
        spacing: CGFloat,
        pickerWidth: CGFloat,
        isEmbedded _: Bool
    ) -> some View {
        let canGoPrevious = currentPlaybackIndex > 0
        let canGoNext = currentPlaybackIndex
            < playbackEvents.count - 1
        let canPlay = playbackEvents.count > 1
        return HStack(alignment: .center, spacing: spacing) {
            playbackButtons(
                iconSize: iconSize,
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext,
                canPlay: canPlay
            )

            if playbackEvents.indices.contains(
                currentPlaybackIndex
            ) {
                Text(
                    stepLabel(
                        for: playbackEvents[currentPlaybackIndex]
                    )
                )
                .font(
                    VizTypography.labelSemibold(size: textSize)
                )
                .foregroundColor(
                    theme.colors.textPrimary
                )
            }

            Spacer()

            speedAndRestart(pickerWidth: pickerWidth)
        }
    }

    // MARK: - Playback Buttons

    private func playbackButtons(
        iconSize: CGFloat,
        canGoPrevious: Bool,
        canGoNext: Bool,
        canPlay: Bool
    ) -> some View {
        HStack(spacing: DSLayout.spacing(12)) {
            DSActionButton(action: selectPrevious) {
                Image(systemName: "backward.fill")
                    .font(
                        VizTypography.iconBold(size: iconSize)
                    )
            }
            .disabled(!canGoPrevious)
            .foregroundColor(
                currentPlaybackIndex == 0
                    ? theme.colors.textSecondary.opacity(0.4)
                    : theme.colors.textPrimary
            )

            DSActionButton(action: togglePlayback) {
                Image(
                    systemName: animationController.isPlaying
                        ? "pause.fill"
                        : "play.fill"
                )
                .font(
                    VizTypography.iconBold(size: iconSize)
                )
            }
            .disabled(!canPlay)
            .foregroundColor(
                playbackEvents.count > 1
                    ? theme.colors.textPrimary
                    : theme.colors.textSecondary.opacity(0.4)
            )

            DSActionButton(action: selectNext) {
                Image(systemName: "forward.fill")
                    .font(
                        VizTypography.iconBold(size: iconSize)
                    )
            }
            .disabled(!canGoNext)
            .foregroundColor(
                currentPlaybackIndex
                    >= playbackEvents.count - 1
                    ? theme.colors.textSecondary.opacity(0.4)
                    : theme.colors.textPrimary
            )
        }
    }

    // MARK: - Speed Picker & Restart

    private func speedAndRestart(
        pickerWidth: CGFloat
    ) -> some View {
        HStack(spacing: DSLayout.spacing(8)) {
            Picker(
                "Speed",
                selection: Binding<Double>(
                    get: { animationController.playbackSpeed },
                    set: { newValue in
                        DispatchQueue.main.async {
                            animationController.playbackSpeed = newValue
                        }
                    }
                )
            ) {
                Text("0.5x").tag(0.5)
                Text("1x").tag(1.0)
                Text("2x").tag(2.0)
                Text("4x").tag(4.0)
            }
            .pickerStyle(.segmented)
            .frame(width: pickerWidth)

            ZStack {
                DSButton(
                    "Start Over",
                    config: .init(
                        style: .secondary, size: .small
                    ),
                    action: { selectIndex(0) }
                )
                .opacity(
                    !animationController.isPlaying
                        && currentPlaybackIndex
                        >= playbackEvents.count - 1
                        ? 1 : 0
                )
                .disabled(
                    animationController.isPlaying
                        || currentPlaybackIndex
                        < playbackEvents.count - 1
                )
            }
            .offset(x: 16)
        }
    }

    // MARK: - Navigation

    func ensurePlaybackSelection() {
        guard !playbackEvents.isEmpty else { return }
        if let selectedEventID,
           playbackEvents.contains(where: {
               $0.id == selectedEventID
           }) {
            return
        }
        selectEvent(playbackEvents[0])
    }

    func selectEvent(_ event: DataJourneyEvent) {
        let animation: Animation? = reduceMotion
            ? .linear(duration: 0.05)
            : .easeInOut(duration: 0.35)
        withAnimation(animation) {
            selectedEventID = event.id
            onSelectEvent(event)
        }
    }

    func selectIndex(_ index: Int) {
        guard playbackEvents.indices.contains(index) else {
            return
        }
        selectEvent(playbackEvents[index])
    }

    func selectPrevious() {
        selectIndex(max(currentPlaybackIndex - 1, 0))
    }

    func selectNext() {
        selectIndex(
            min(
                currentPlaybackIndex + 1,
                playbackEvents.count - 1
            )
        )
    }

    func jumpToStart() {
        animationController.onUserStepClick()
        selectIndex(0)
    }

    func jumpToEnd() {
        animationController.onUserStepClick()
        selectIndex(playbackEvents.count - 1)
    }

    private var truncationMessage: String {
        "Showing first 40 steps or truncated data. "
            + "Reduce `Trace.step` calls or input size to see more."
    }
}
