import LeetPulseDesignSystem
import SwiftUI

// MARK: - Centralized TraceValue Display Properties

extension TraceValue {
    /// Short display string used in flow overview cards and comparison panes.
    /// Replaces per-file `valueSummary(_:)` and `compactSummary(_:)` functions.
    var compactSummary: String {
        switch self {
        case .null:
            return "nil"
        case let .bool(boolValue):
            return boolValue ? "true" : "false"
        case let .number(num, isInt):
            return isInt ? "\(Int(num))" : String(format: "%.2f", num)
        case let .string(str):
            return str.count <= 10
                ? "\"\(str)\""
                : "\"\(str.prefix(8))...\""
        case let .array(items):
            if items.count <= 4 {
                let previews = items.prefix(4).map(\.compactSummary)
                return "[\(previews.joined(separator: ", "))]"
            }
            return "[\(items.count) items]"
        case let .list(list):
            return "->\(list.nodes.count) nodes"
        case let .tree(tree):
            return "tree(\(tree.nodes.count))"
        case let .object(map):
            return "{\(map.count) keys}"
        case let .trie(trieData):
            return "trie(\(trieData.nodes.count))"
        case .listPointer, .treePointer:
            return "ptr"
        case let .typed(type, inner):
            let lowered = type.lowercased()
            if case let .array(items) = inner {
                return "\(lowered)(\(items.count))"
            }
            return inner.compactSummary
        }
    }

    /// Short summary variant with slightly tighter truncation for compact contexts.
    var flowSummary: String {
        switch self {
        case let .string(str):
            str.count <= 8
                ? "\"\(str)\""
                : "\"\(str.prefix(6))...\""
        case let .array(items):
            "[\(items.count)]"
        case let .list(list):
            "->\(list.nodes.count)"
        case let .number(num, isInt):
            isInt ? "\(Int(num))" : String(format: "%.1f", num)
        default:
            compactSummary
        }
    }

    /// Unique identity string for animation diffing in sequence bubble rows.
    /// Replaces `identityKey(for:)` in DataJourneySequenceBubbleRow+Layout.
    var identityKey: String {
        switch self {
        case .null:
            "nil"
        case let .bool(boolValue):
            boolValue ? "true" : "false"
        case let .number(number, isInt):
            isInt ? "i\(Int(number))" : "d\(number)"
        case let .string(stringValue):
            "s\(stringValue)"
        case let .array(items):
            "a\(items.count)"
        case let .object(map):
            "o\(map.count)"
        case let .list(list):
            "l\(list.nodes.count)-\(list.cycleIndex ?? -1)"
                + "-\(list.isTruncated)-\(list.isDoubly)"
        case let .tree(tree):
            "t\(tree.nodes.count)-\(tree.rootId ?? "nil")"
        case let .listPointer(id), let .treePointer(id):
            "p\(id)"
        case let .trie(trieData):
            "trie\(trieData.nodes.count)"
                + "-\(trieData.rootId ?? "nil")"
        case let .typed(type, inner):
            "t\(type)-\(inner.identityKey)"
        }
    }

    /// Element count for collection types, nil for scalars.
    /// Replaces part of `timelinePoint(from:)` in DataJourneyVariableTimeline.
    var collectionSize: Int? {
        switch self {
        case let .string(str):
            str.count
        case let .array(items):
            items.count
        case let .list(list):
            list.nodes.count
        case let .tree(tree):
            tree.nodes.count
        case let .object(map):
            map.count
        case let .trie(trieData):
            trieData.nodes.count
        case let .typed(_, inner):
            inner.collectionSize
        default:
            nil
        }
    }

    /// Double value for numeric types, nil for non-numeric.
    /// Replaces the numeric extraction in DataJourneyVariableTimeline.
    var numericValue: Double? {
        switch self {
        case let .number(num, _):
            num
        case let .bool(boolValue):
            boolValue ? 1 : 0
        case let .typed(_, inner):
            inner.numericValue
        default:
            nil
        }
    }

    /// Creates a bubble model with text and fill color for trace visualization.
    /// Replaces `TraceBubbleModel.from(_:theme:compact:)`.
    func bubbleModel(
        theme: DSTheme,
        compact: Bool = false
    ) -> TraceBubbleModel {
        if let scalar = scalarBubbleModel(theme: theme) {
            return scalar
        }
        return collectionBubbleModel(theme: theme, compact: compact)
    }

    /// Handles scalar TraceValue cases (null, bool, number, string).
    private func scalarBubbleModel(theme: DSTheme) -> TraceBubbleModel? {
        switch self {
        case .null:
            return TraceBubbleModel(
                text: "null", fill: theme.colors.surfaceElevated, isNull: true
            )
        case let .bool(boolValue):
            return TraceBubbleModel(
                text: boolValue ? "true" : "false",
                fill: theme.vizColors.quinary.opacity(0.3)
            )
        case let .number(number, isInt):
            let text = isInt ? "\(Int(number))" : String(format: "%.2f", number)
            return TraceBubbleModel(text: text, fill: theme.vizColors.primary.opacity(0.3))
        case let .string(stringValue):
            return TraceBubbleModel(
                text: stringValue,
                fill: theme.vizColors.tertiary.opacity(0.25)
            )
        default:
            return nil
        }
    }

    /// Handles collection and complex TraceValue cases.
    private func collectionBubbleModel(
        theme: DSTheme,
        compact: Bool
    ) -> TraceBubbleModel {
        switch self {
        case let .array(items):
            let label = compact ? "\(items.count)" : "[\(items.count)]"
            return TraceBubbleModel(text: label, fill: theme.colors.surfaceElevated)
        case let .object(map):
            let label = TraceBubbleModel.dictionaryPreview(
                map: map,
                seed: nil,
                theme: theme
            )
            return TraceBubbleModel(text: label, fill: theme.colors.surfaceElevated)
        case let .list(list):
            let label = compact
                ? "\(list.nodes.count)"
                : "[\(list.nodes.count)]"
            return TraceBubbleModel(text: label, fill: theme.colors.surfaceElevated)
        case let .tree(tree):
            let label = compact ? "\(tree.nodes.count)" : "tree"
            return TraceBubbleModel(text: label, fill: theme.colors.surfaceElevated)
        case .listPointer, .treePointer:
            return TraceBubbleModel(text: "ptr", fill: theme.colors.surfaceElevated)
        case let .trie(trieData):
            let label = compact ? "\(trieData.nodes.count)" : "trie"
            return TraceBubbleModel(text: label, fill: theme.colors.surfaceElevated)
        case let .typed(type, inner):
            return Self.typedBubbleModel(
                type: type,
                inner: inner,
                theme: theme,
                compact: compact
            )
        default:
            return TraceBubbleModel(text: "?", fill: theme.colors.surfaceElevated)
        }
    }

    private static func typedBubbleModel(
        type: String,
        inner: TraceValue,
        theme: DSTheme,
        compact: Bool
    ) -> TraceBubbleModel {
        let lowered = type.lowercased()
        if case let .array(items) = inner {
            switch lowered {
            case "set":
                return TraceBubbleModel(
                    text: "{\(items.count)}",
                    fill: theme.vizColors.secondary.opacity(0.25)
                )
            case "stack":
                return TraceBubbleModel(
                    text: "S\(items.count)",
                    fill: theme.vizColors.quinary.opacity(0.25)
                )
            case "queue":
                return TraceBubbleModel(
                    text: "Q\(items.count)",
                    fill: theme.vizColors.tertiary.opacity(0.25)
                )
            default:
                break
            }
        }
        return inner.bubbleModel(theme: theme, compact: compact)
    }
}
