import LeetPulseDesignSystem
import SwiftUI
import UniformTypeIdentifiers

struct DataJourneyView: View {
    let events: [DataJourneyEvent]
    @Binding var selectedEventID: String?
    let onSelectEvent: (DataJourneyEvent) -> Void
    let isTruncated: Bool
    let sourceCode: String
    @StateObject var animationController = DataJourneyAnimationController()
    @Environment(\.dsTheme) var theme
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State var exportTriggered = false
    @State private var exportDocument: PNGExportDocument?
    @State private var showExporter = false
    @State private var keyboardMonitor: Any?

    var body: some View {
        if events.isEmpty || hasNoData {
            emptyState
        } else {
            content
                .fileExporter(
                    isPresented: $showExporter,
                    document: exportDocument,
                    contentType: .png,
                    defaultFilename: "DataJourney"
                ) { _ in
                    exportDocument = nil
                }
                .onChange(of: exportTriggered) { _, triggered in
                    guard triggered else { return }
                    exportTriggered = false
                    renderAndExport()
                }
                .onChange(of: events.map(\.id)) { _, _ in
                    animationController.pause()
                    ensurePlaybackSelection()
                }
                .onAppear {
                    ensurePlaybackSelection()
                    installKeyboardMonitor()
                }
                .onDisappear {
                    animationController.teardown()
                    removeKeyboardMonitor()
                }
        }
    }

    // MARK: - PNG Export

    private func renderAndExport() {
        let structure = StructureResolver.resolve(
            inputEvent: inputEvent,
            selectedEvent: selectedEvent,
            outputEvent: outputEvent
        )
        guard structure != nil else { return }

        let canvasView = DataJourneyStructureCanvasView<
            EmptyView, EmptyView
        >(
            inputEvent: inputEvent,
            selectedEvent: selectedEvent,
            previousEvent: previousPlaybackEvent,
            outputEvent: outputEvent,
            structureOverride: structure,
            playbackIndex: currentPlaybackIndex,
            beginsAtZero: false,
            header: nil as EmptyView?,
            footer: nil as EmptyView?
        )

        let renderer = ImageRenderer(content: canvasView)
        renderer.scale = 2.0
        guard let image = renderer.cgImage else { return }

        let width = image.width
        let height = image.height
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else { return }

        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )

        guard let outputImage = context.makeImage() else { return }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return }
        CGImageDestinationAddImage(destination, outputImage, nil)
        guard CGImageDestinationFinalize(destination) else { return }

        exportDocument = PNGExportDocument(
            pngData: mutableData as Data
        )
        showExporter = true
    }

    // MARK: - Playback Delegation

    var isPlaying: Bool {
        animationController.isPlaying
    }

    var playbackSpeed: Double {
        get { animationController.playbackSpeed }
        nonmutating set { animationController.playbackSpeed = newValue }
    }

    func togglePlayback() {
        guard playbackEvents.count > 1 else { return }
        if !animationController.isPlaying,
           currentPlaybackIndex >= playbackEvents.count - 1 {
            selectIndex(0)
        }
        let total = playbackEvents.count
        let current = currentPlaybackIndex
        animationController.togglePlayPause(
            totalSteps: total,
            currentIndex: current,
            advance: { [self] in advancePlayback() },
            onEnd: { [self] in animationController.pause() },
            reduceMotion: reduceMotion
        )
    }

    private func advancePlayback() {
        if currentPlaybackIndex >= playbackEvents.count - 1 {
            animationController.pause()
            return
        }
        selectNext()
    }

    // MARK: - Keyboard Monitor

    private func installKeyboardMonitor() {
        #if os(macOS)
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { event in
            guard !events.isEmpty, !hasNoData else {
                return event
            }
            let flags = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
            guard flags.isEmpty
                || flags == .numericPad
                || flags == [.numericPad, .function]
            else {
                return event
            }
            switch event.keyCode {
            case 123:
                selectPrevious()
                return nil
            case 124:
                selectNext()
                return nil
            case 49:
                guard playbackEvents.count > 1 else {
                    return event
                }
                togglePlayback()
                return nil
            case 115:
                jumpToStart()
                return nil
            case 119:
                jumpToEnd()
                return nil
            default:
                return event
            }
        }
        #endif
    }

    private func removeKeyboardMonitor() {
        #if os(macOS)
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
        #endif
    }
}
