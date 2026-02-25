import Foundation
import SwiftUI

/// Controls auto-play animation for the Data Journey visualization.
///
/// Manages play/pause state, playback speed selection, and
/// step advancement via a repeating timer. Designed to be
/// instantiated as `@StateObject` in `DataJourneyView`.
@MainActor
final class DataJourneyAnimationController: ObservableObject {
    // MARK: - Published State

    @Published var isPlaying = false
    @Published var playbackSpeed: Double = 1.0

    // MARK: - Constants

    let availableSpeeds: [Double] = [0.5, 1.0, 2.0, 4.0]

    /// Base interval between steps in seconds at 1x speed.
    private let baseInterval: TimeInterval = 1.2

    // MARK: - Private

    private var playbackTask: Task<Void, Never>?

    // MARK: - Playback Control

    func play(
        totalSteps: Int,
        currentIndex _: Int,
        advance: @escaping () -> Void,
        onEnd _: @escaping () -> Void,
        reduceMotion _: Bool
    ) {
        guard totalSteps > 1 else { return }
        isPlaying = true
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            guard let self else { return }
            while isPlaying {
                let interval = baseInterval / playbackSpeed
                let nanos = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                guard !Task.isCancelled, isPlaying else { break }
                advance()
            }
        }
    }

    func pause() {
        isPlaying = false
        playbackTask?.cancel()
    }

    func togglePlayPause(
        totalSteps: Int,
        currentIndex: Int,
        advance: @escaping () -> Void,
        onEnd: @escaping () -> Void,
        reduceMotion: Bool
    ) {
        if isPlaying {
            pause()
        } else {
            play(
                totalSteps: totalSteps,
                currentIndex: currentIndex,
                advance: advance,
                onEnd: onEnd,
                reduceMotion: reduceMotion
            )
        }
    }

    /// Pauses auto-play when user clicks a specific step.
    func onUserStepClick() {
        pause()
    }

    func teardown() {
        pause()
    }
}
