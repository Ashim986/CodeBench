
import LeetPulseDesignSystemCore
import SwiftUI

// MARK: - List Structure View Builders

extension DataJourneyStructureCanvasView {
    @ViewBuilder
    func listView(list: TraceList) -> some View {
        let motions = listPointerMotions(
            from: previousEvent, to: selectedEvent, list: list
        )
        SequenceBubbleRow(
            items: list.nodes.isEmpty ? [.null] : list.nodes.map(\.value),
            showIndices: false,
            cycleIndex: list.cycleIndex,
            isTruncated: list.isTruncated,
            isDoubly: list.isDoubly,
            pointers: pointerMarkers(for: list),
            pointerMotions: motions,
            bubbleStyle: .solid,
            bubbleSize: structureBubbleSize,
            pointerFontSize: structurePointerFontSize,
            pointerHorizontalPadding: structurePointerHorizontalPadding,
            pointerVerticalPadding: structurePointerVerticalPadding
        )
    }

    @ViewBuilder
    func listGroupView(lists: [NamedTraceList]) -> some View {
        let combined = combinedListViewModel(for: lists)
        let motions = combinedPointerMotions(
            from: previousEvent, to: selectedEvent, lists: lists
        )
        let finalLinks = outputSequenceLinks(for: lists)
        VStack(alignment: .leading, spacing: DSLayout.spacing(14)) {
            combinedListRow(
                combined: combined,
                motions: motions,
                finalLinks: finalLinks
            )

            Rectangle()
                .fill(theme.colors.surfaceElevated.opacity(0.6))
                .frame(height: 1)
                .padding(.leading, DSLayout.spacing(64))

            ForEach(lists) { entry in
                namedListRow(entry: entry)
            }
        }
    }

    @ViewBuilder
    func listArrayView(listArray: ListArrayStructure) -> some View {
        let combined = combinedListViewModel(for: listArray.lists)
        let motions = combinedPointerMotions(
            from: previousEvent, to: selectedEvent,
            lists: listArray.lists
        )
        let finalLinks = outputSequenceLinks(for: listArray.lists)
        VStack(alignment: .leading, spacing: DSLayout.spacing(14)) {
            combinedListRow(
                combined: combined,
                motions: motions,
                finalLinks: finalLinks
            )

            headsRow(listArray: listArray)

            Rectangle()
                .fill(theme.colors.surfaceElevated.opacity(0.6))
                .frame(height: 1)
                .padding(.leading, DSLayout.spacing(64))

            ForEach(listArray.lists) { entry in
                namedListRow(entry: entry)
            }
        }
    }

    // MARK: - Shared List Sub-Views

    private func combinedListRow(
        combined: CombinedListViewModel,
        motions: [PointerMotion],
        finalLinks: [SequenceLink]
    ) -> some View {
        HStack(alignment: .center, spacing: DSLayout.spacing(12)) {
            listLabel(
                "combined",
                color: theme.vizColors.quinary,
                background: theme.vizColors.quinary.opacity(0.18)
            )
            .frame(width: 64, alignment: .leading)

            SequenceBubbleRow(
                items: combined.items,
                showIndices: false,
                cycleIndex: nil,
                isTruncated: combined.isTruncated,
                isDoubly: false,
                pointers: combined.pointers,
                pointerMotions: motions,
                sequenceLinks: finalLinks,
                gapIndices: combined.gapIndices,
                bubbleStyle: .solid,
                bubbleSize: structureBubbleSize,
                pointerFontSize: structurePointerFontSize,
                pointerHorizontalPadding: structurePointerHorizontalPadding,
                pointerVerticalPadding: structurePointerVerticalPadding
            )
        }
    }

    private func headsRow(
        listArray: ListArrayStructure
    ) -> some View {
        HStack(alignment: .center, spacing: DSLayout.spacing(10)) {
            listLabel(
                "heads",
                color: theme.vizColors.secondary,
                background: theme.vizColors.secondary.opacity(0.18)
            )
            .frame(width: 64, alignment: .leading)

            SequenceBubbleRow(
                items: listArray.heads.isEmpty
                    ? [.null] : listArray.heads,
                showIndices: true,
                cycleIndex: nil,
                isTruncated: false,
                isDoubly: false,
                pointers: listArrayHeadPointers(for: listArray),
                bubbleStyle: .solid,
                bubbleSize: structureBubbleSize,
                pointerFontSize: structurePointerFontSize,
                pointerHorizontalPadding: structurePointerHorizontalPadding,
                pointerVerticalPadding: structurePointerVerticalPadding
            )
        }
    }

    private func namedListRow(
        entry: NamedTraceList
    ) -> some View {
        HStack(alignment: .center, spacing: DSLayout.spacing(10)) {
            let accent = PointerPalette.color(
                for: entry.name, theme: theme
            )
            listLabel(
                entry.name,
                color: accent,
                background: accent.opacity(0.18)
            )
            .frame(width: 64, alignment: .leading)

            SequenceBubbleRow(
                items: entry.list.nodes.isEmpty
                    ? [.null] : entry.list.nodes.map(\.value),
                showIndices: false,
                cycleIndex: entry.list.cycleIndex,
                isTruncated: entry.list.isTruncated,
                isDoubly: entry.list.isDoubly,
                pointers: pointerMarkers(for: entry.list),
                bubbleStyle: .solid,
                bubbleSize: structureBubbleSize,
                pointerFontSize: structurePointerFontSize,
                pointerHorizontalPadding: structurePointerHorizontalPadding,
                pointerVerticalPadding: structurePointerVerticalPadding
            )
        }
    }
}
