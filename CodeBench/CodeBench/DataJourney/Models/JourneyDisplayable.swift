import Foundation

/// Single protocol that all Data Journey values conform to.
///
/// Provides a unified display contract so input, expected, and output
/// values flow through the same interface regardless of their underlying
/// data structure (scalar, array, tree, linked list, etc.).
protocol JourneyDisplayable: Equatable, Sendable {
    /// Short display string for overview cards and comparison panes.
    var compactSummary: String { get }

    /// Tighter-truncation variant for compact contexts.
    var flowSummary: String { get }

    /// Unique identity string for animation diffing.
    var identityKey: String { get }

    /// Element count for collection types, nil for scalars.
    var collectionSize: Int? { get }

    /// Double value for numeric types, nil for non-numeric.
    var numericValue: Double? { get }

    /// Short human-readable description for accessibility.
    var shortDescription: String { get }
}

// MARK: - TraceValue Conformance

extension TraceValue: JourneyDisplayable {}
