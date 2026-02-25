import Foundation

/// Describes how an element changed between two consecutive steps.
enum ChangeType: Equatable {
    case added
    case removed
    case modified
    case unchanged
}

/// Utilities for computing diffs between consecutive DataJourneyEvents.
/// Used to highlight what changed between steps in the data journey visualization.
enum TraceValueDiff {
    /// Returns the set of variable keys whose values differ between two events.
    static func changedKeys(
        previous: DataJourneyEvent?,
        current: DataJourneyEvent?
    ) -> Set<String> {
        guard let previous, let current else { return current.map { Set($0.values.keys) } ?? [] }
        var changed = Set<String>()
        let allKeys = Set(previous.values.keys).union(current.values.keys)
        for key in allKeys where previous.values[key] != current.values[key] {
            changed.insert(key)
        }
        return changed
    }

    /// Returns the set of array indices that differ between two TraceValue arrays.
    static func changedIndices(
        previous: TraceValue?,
        current: TraceValue?
    ) -> Set<Int> {
        let prevItems = arrayItems(from: previous)
        let currItems = arrayItems(from: current)
        var changed = Set<Int>()
        let maxCount = max(prevItems.count, currItems.count)
        for index in 0 ..< maxCount
            where (index < prevItems.count ? prevItems[index] : nil)
            != (index < currItems.count ? currItems[index] : nil) {
            changed.insert(index)
        }
        return changed
    }

    /// Returns the set of node IDs that differ between two TraceValue lists.
    static func changedNodeIds(
        previous: TraceValue?,
        current: TraceValue?
    ) -> Set<String> {
        let prevNodes = listNodes(from: previous)
        let currNodes = listNodes(from: current)
        var changed = Set<String>()
        let prevById = Dictionary(uniqueKeysWithValues: prevNodes.map { ($0.id, $0.value) })
        let currById = Dictionary(uniqueKeysWithValues: currNodes.map { ($0.id, $0.value) })
        let allIds = Set(prevById.keys).union(currById.keys)
        for nodeId in allIds where prevById[nodeId] != currById[nodeId] {
            changed.insert(nodeId)
        }
        return changed
    }

    /// Returns the set of tree node IDs that differ between two events.
    static func changedTreeNodeIds(
        previous: TraceValue?,
        current: TraceValue?
    ) -> Set<String> {
        let prevNodes = treeNodes(from: previous)
        let currNodes = treeNodes(from: current)
        var changed = Set<String>()
        let prevById = Dictionary(
            uniqueKeysWithValues: prevNodes.map { ($0.id, $0) }
        )
        let currById = Dictionary(
            uniqueKeysWithValues: currNodes.map { ($0.id, $0) }
        )
        let allIds = Set(prevById.keys).union(currById.keys)
        for nodeId in allIds where prevById[nodeId] != currById[nodeId] {
            changed.insert(nodeId)
        }
        return changed
    }

    /// Returns the set of matrix cell coordinates (row, col) that differ
    /// between two 2D arrays.
    static func changedMatrixCells(
        previous: TraceValue?,
        current: TraceValue?
    ) -> Set<MatrixCell> {
        let prevGrid = matrixRows(from: previous)
        let currGrid = matrixRows(from: current)
        var changed = Set<MatrixCell>()
        let maxRows = max(prevGrid.count, currGrid.count)
        for row in 0 ..< maxRows {
            let prevRow = row < prevGrid.count ? prevGrid[row] : []
            let currRow = row < currGrid.count ? currGrid[row] : []
            let maxCols = max(prevRow.count, currRow.count)
            for col in 0 ..< maxCols
                where (col < prevRow.count ? prevRow[col] : nil)
                != (col < currRow.count ? currRow[col] : nil) {
                changed.insert(MatrixCell(row: row, col: col))
            }
        }
        return changed
    }

    /// Returns the set of dictionary keys whose values differ.
    static func changedDictKeys(
        previous: TraceValue?,
        current: TraceValue?
    ) -> Set<String> {
        let prevEntries = dictEntries(from: previous)
        let currEntries = dictEntries(from: current)
        var changed = Set<String>()
        let allKeys = Set(prevEntries.keys).union(currEntries.keys)
        for key in allKeys where prevEntries[key] != currEntries[key] {
            changed.insert(key)
        }
        return changed
    }

    // MARK: - Element-Level Change Types

    /// Returns per-index change types for arrays using LCS-based diffing.
    static func elementChanges(
        previous: TraceValue?,
        current: TraceValue?
    ) -> [ChangeType] {
        let prevItems = arrayItems(from: previous)
        let currItems = arrayItems(from: current)

        guard !prevItems.isEmpty || !currItems.isEmpty else { return [] }

        // If sizes are the same, just compare element-by-element
        if prevItems.count == currItems.count {
            return currItems.enumerated().map { index, curr in
                let prev = prevItems[index]
                return prev == curr ? .unchanged : .modified
            }
        }

        // Use LCS for differing sizes
        let lcs = longestCommonSubsequence(prevItems, currItems)
        var result = [ChangeType](repeating: .added, count: currItems.count)

        var lcsIndex = 0
        for (currIndex, currItem) in currItems.enumerated() {
            if lcsIndex < lcs.count, currItem == lcs[lcsIndex] {
                result[currIndex] = .unchanged
                lcsIndex += 1
            } else if prevItems.contains(currItem) {
                result[currIndex] = .modified
            }
            // else stays .added
        }

        return result
    }

    /// Returns per-node change types for tree structures.
    static func nodeChanges(
        previous: TraceValue?,
        current: TraceValue?
    ) -> [String: ChangeType] {
        let prevNodes = treeNodes(from: previous)
        let currNodes = treeNodes(from: current)
        let prevById = Dictionary(
            uniqueKeysWithValues: prevNodes.map { ($0.id, $0) }
        )
        let currById = Dictionary(
            uniqueKeysWithValues: currNodes.map { ($0.id, $0) }
        )
        var result: [String: ChangeType] = [:]

        for (nodeId, currNode) in currById {
            if let prevNode = prevById[nodeId] {
                result[nodeId] = prevNode == currNode ? .unchanged : .modified
            } else {
                result[nodeId] = .added
            }
        }

        // Mark removed nodes
        for nodeId in prevById.keys where currById[nodeId] == nil {
            result[nodeId] = .removed
        }

        return result
    }

    /// LCS helper for array diffing.
    private static func longestCommonSubsequence(
        _ lcsA: [TraceValue],
        _ lcsB: [TraceValue]
    ) -> [TraceValue] {
        let lengthA = lcsA.count
        let lengthB = lcsB.count
        guard lengthA > 0, lengthB > 0 else { return [] }

        // Cap at reasonable size to avoid performance issues
        guard lengthA <= 200, lengthB <= 200 else {
            // Fall back to empty LCS for large arrays
            return []
        }

        var dp = Array(
            repeating: Array(repeating: 0, count: lengthB + 1),
            count: lengthA + 1
        )
        for indexA in 1 ... lengthA {
            for indexB in 1 ... lengthB {
                if lcsA[indexA - 1] == lcsB[indexB - 1] {
                    dp[indexA][indexB] = dp[indexA - 1][indexB - 1] + 1
                } else {
                    dp[indexA][indexB] = max(dp[indexA - 1][indexB], dp[indexA][indexB - 1])
                }
            }
        }

        var result: [TraceValue] = []
        var indexA = lengthA
        var indexB = lengthB
        while indexA > 0, indexB > 0 {
            if lcsA[indexA - 1] == lcsB[indexB - 1] {
                result.append(lcsA[indexA - 1])
                indexA -= 1
                indexB -= 1
            } else if dp[indexA - 1][indexB] > dp[indexA][indexB - 1] {
                indexA -= 1
            } else {
                indexB -= 1
            }
        }
        return result.reversed()
    }

    // MARK: - Helpers

    private static func arrayItems(from value: TraceValue?) -> [TraceValue] {
        guard let value else { return [] }
        switch value {
        case let .array(items):
            return items
        case let .typed(_, inner):
            return arrayItems(from: inner)
        default:
            return []
        }
    }

    private static func listNodes(from value: TraceValue?) -> [TraceListNode] {
        guard let value else { return [] }
        switch value {
        case let .list(list):
            return list.nodes
        case let .typed(_, inner):
            return listNodes(from: inner)
        default:
            return []
        }
    }

    private static func treeNodes(from value: TraceValue?) -> [TraceTreeNode] {
        guard let value else { return [] }
        switch value {
        case let .tree(tree):
            return tree.nodes
        case let .typed(_, inner):
            return treeNodes(from: inner)
        default:
            return []
        }
    }

    private static func matrixRows(from value: TraceValue?) -> [[TraceValue]] {
        guard let value else { return [] }
        switch value {
        case let .array(items):
            return items.compactMap { item in
                if case let .array(row) = item { return row }
                return nil
            }
        case let .typed(_, inner):
            return matrixRows(from: inner)
        default:
            return []
        }
    }

    private static func dictEntries(
        from value: TraceValue?
    ) -> [String: TraceValue] {
        guard let value else { return [:] }
        switch value {
        case let .object(map):
            return map
        case let .typed(_, inner):
            return dictEntries(from: inner)
        default:
            return [:]
        }
    }
}

/// Hashable cell coordinate for matrix diff tracking.
struct MatrixCell: Hashable {
    let row: Int
    let col: Int
}
