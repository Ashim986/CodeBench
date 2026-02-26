import Foundation

import SwiftUI

enum DataJourneyEventKind: String {
    case input
    case output
    case step
}

struct DataJourneyEvent: Identifiable {
    let id: String
    let kind: DataJourneyEventKind
    let line: Int?
    let label: String?
    let values: [String: TraceValue]

    static func from(json: Any, index: Int = 0) -> DataJourneyEvent? {
        guard let dict = json as? [String: Any] else { return nil }
        guard let kindString = dict["kind"] as? String,
              let kind = DataJourneyEventKind(rawValue: kindString) else { return nil }

        let line: Int? = if let lineValue = dict["line"] as? Int {
            lineValue
        } else if let lineNumber = dict["line"] as? NSNumber {
            lineNumber.intValue
        } else {
            nil
        }

        let label = dict["label"] as? String
        let valuesDict = dict["values"] as? [String: Any] ?? [:]
        let values = valuesDict.mapValues { JourneyValueFactory.fromJSON($0) }
        let eventId = "event-\(index)-\(kind.rawValue)-\(line ?? 0)-\(label ?? "unlabeled")"

        return DataJourneyEvent(id: eventId, kind: kind, line: line, label: label, values: values)
    }
}

struct TraceListNode: Equatable {
    let id: String
    let value: TraceValue
}

struct TraceList: Equatable {
    let nodes: [TraceListNode]
    let cycleIndex: Int?
    let isTruncated: Bool
    let isDoubly: Bool
}

struct TraceTreeNode: Equatable {
    let id: String
    let value: TraceValue
    let left: String?
    let right: String?
}

struct TraceTree: Equatable {
    let nodes: [TraceTreeNode]
    let rootId: String?
    let isTruncated: Bool
}

extension TraceTree {
    static func fromLevelOrder(_ items: [TraceValue]) -> TraceTree {
        guard !items.isEmpty else {
            return TraceTree(nodes: [], rootId: nil, isTruncated: false)
        }
        var nodes: [TraceTreeNode] = []
        for (index, value) in items.enumerated() {
            guard value != .null else { continue }
            let id = "i\(index)"
            let leftIndex = 2 * index + 1
            let rightIndex = 2 * index + 2
            let leftId = leftIndex < items.count && items[leftIndex] != .null
                ? "i\(leftIndex)"
                : nil
            let rightId = rightIndex < items.count && items[rightIndex] != .null
                ? "i\(rightIndex)"
                : nil
            nodes.append(TraceTreeNode(id: id, value: value, left: leftId, right: rightId))
        }
        let rootId = items.first == .null ? nil : "i0"
        return TraceTree(nodes: nodes, rootId: rootId, isTruncated: false)
    }
}

struct TraceTrieNode: Equatable {
    let id: String
    let character: String
    let isEnd: Bool
    let children: [String]
}

struct TraceTrie: Equatable {
    let nodes: [TraceTrieNode]
    let rootId: String?
    let isTruncated: Bool
}

indirect enum TraceValue: Equatable {
    case null
    case bool(Bool)
    case number(Double, isInt: Bool)
    case string(String)
    case array([TraceValue])
    case object([String: TraceValue])
    case list(TraceList)
    case listPointer(String)
    case tree(TraceTree)
    case treePointer(String)
    case trie(TraceTrie)
    case typed(String, TraceValue)

    static func from(json: Any) -> TraceValue {
        if let primitive = TraceValue.primitive(from: json) {
            return primitive
        }
        if let arrayValue = json as? [Any] {
            return .array(arrayValue.map { TraceValue.from(json: $0) })
        }
        if let dictValue = json as? [String: Any] {
            return TraceValue.typedValue(from: dictValue)
                ?? .object(dictValue.mapValues { TraceValue.from(json: $0) })
        }
        return .string(String(describing: json))
    }
}

extension TraceValue {
    fileprivate static func primitive(from json: Any) -> TraceValue? {
        if json is NSNull { return .null }
        if let number = json as? NSNumber {
            let objCType = String(cString: number.objCType)
            if objCType == "c" || objCType == "B" {
                return .bool(number.boolValue)
            }
            let doubleValue = number.doubleValue
            let intValue = number.intValue
            let isInt = Double(intValue) == doubleValue
            return .number(doubleValue, isInt: isInt)
        }
        if let boolValue = json as? Bool { return .bool(boolValue) }
        if let stringValue = json as? String { return .string(stringValue) }
        return nil
    }

    /// Table-driven dispatch: each type string maps to a focused parser function.
    nonisolated(unsafe) private static let typeParsers: [String: ([String: Any]) -> TraceValue?] = [
        "list": parseList,
        "doublylist": parseDoublyList,
        "listpointer": parseListPointer,
        "tree": parseTree,
        "treepointer": parseTreePointer,
        "trie": parseTrie
    ]

    fileprivate static func typedValue(from dictValue: [String: Any]) -> TraceValue? {
        guard let type = dictValue["__type"] as? String else { return nil }
        let key = type.lowercased()
        if let parser = typeParsers[key] {
            return parser(dictValue)
        }
        return parseTypedFallback(type: type, dictValue: dictValue)
    }

    private static func parseList(_ dict: [String: Any]) -> TraceValue? {
        let nodes = listNodes(from: dict["nodes"])
        let cycleIndex = intValue(from: dict["cycleIndex"])
        let isTruncated = (dict["truncated"] as? Bool) ?? false
        return .list(TraceList(
            nodes: nodes,
            cycleIndex: cycleIndex,
            isTruncated: isTruncated,
            isDoubly: false
        ))
    }

    private static func parseDoublyList(_ dict: [String: Any]) -> TraceValue? {
        let nodes = listNodes(from: dict["nodes"])
        let cycleIndex = intValue(from: dict["cycleIndex"])
        let isTruncated = (dict["truncated"] as? Bool) ?? false
        return .list(TraceList(
            nodes: nodes,
            cycleIndex: cycleIndex,
            isTruncated: isTruncated,
            isDoubly: true
        ))
    }

    private static func parseListPointer(_ dict: [String: Any]) -> TraceValue? {
        guard let id = dict["id"] as? String else { return nil }
        return .listPointer(id)
    }

    private static func parseTree(_ dict: [String: Any]) -> TraceValue? {
        let nodes = treeNodes(from: dict["nodes"])
        let rootId = dict["rootId"] as? String
        let isTruncated = (dict["truncated"] as? Bool) ?? false
        return .tree(TraceTree(nodes: nodes, rootId: rootId, isTruncated: isTruncated))
    }

    private static func parseTreePointer(_ dict: [String: Any]) -> TraceValue? {
        guard let id = dict["id"] as? String else { return nil }
        return .treePointer(id)
    }

    private static func parseTrie(_ dict: [String: Any]) -> TraceValue? {
        let nodes = trieNodes(from: dict["nodes"])
        let rootId = dict["rootId"] as? String
        let isTruncated = (dict["truncated"] as? Bool) ?? false
        return .trie(TraceTrie(nodes: nodes, rootId: rootId, isTruncated: isTruncated))
    }

    private static func parseTypedFallback(
        type: String,
        dictValue: [String: Any]
    ) -> TraceValue? {
        guard let value = dictValue["value"] else { return nil }
        return .typed(type, TraceValue.from(json: value))
    }

    private var arrayValues: [TraceValue] {
        if case let .array(items) = self { return items }
        return []
    }

    fileprivate static func intValue(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let intValue = Int(string) { return intValue }
        return nil
    }

    fileprivate static func listNodes(from value: Any?) -> [TraceListNode] {
        guard let rawNodes = value as? [Any] else { return [] }
        return rawNodes.compactMap { entry in
            guard let dict = entry as? [String: Any],
                  let id = dict["id"] as? String else { return nil }
            let value = dict["value"].map { TraceValue.from(json: $0) } ?? .null
            return TraceListNode(id: id, value: value)
        }
    }

    fileprivate static func trieNodes(from value: Any?) -> [TraceTrieNode] {
        guard let rawNodes = value as? [Any] else { return [] }
        return rawNodes.compactMap { entry in
            guard let dict = entry as? [String: Any],
                  let id = dict["id"] as? String else { return nil }
            let character = (dict["character"] as? String) ?? (dict["char"] as? String) ?? ""
            let isEnd = (dict["isEnd"] as? Bool) ?? false
            let children = (dict["children"] as? [String]) ?? []
            return TraceTrieNode(id: id, character: character, isEnd: isEnd, children: children)
        }
    }

    fileprivate static func treeNodes(from value: Any?) -> [TraceTreeNode] {
        guard let rawNodes = value as? [Any] else { return [] }
        return rawNodes.compactMap { entry in
            guard let dict = entry as? [String: Any],
                  let id = dict["id"] as? String else { return nil }
            let value = dict["value"].map { TraceValue.from(json: $0) } ?? .null
            let left = dict["left"] as? String
            let right = dict["right"] as? String
            return TraceTreeNode(id: id, value: value, left: left, right: right)
        }
    }
}

// MARK: - Accessibility

extension TraceValue {
    /// Short human-readable description for accessibility purposes.
    var shortDescription: String {
        switch self {
        case .null: "null"
        case let .bool(value): value ? "true" : "false"
        case let .number(value, isInt):
            isInt ? "\(Int(value))" : "\(value)"
        case let .string(value): value
        case let .array(items):
            "[\(items.prefix(3).map(\.shortDescription).joined(separator: ", "))]"
        case .list: "list"
        case .tree: "tree"
        case .trie: "trie"
        case let .typed(type, _): type
        default: ""
        }
    }
}
