# Phase 1: Foundation Bug Fixes - Context

**Gathered:** 2026-02-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix UUID identity instability and layout-in-body performance bugs that block all animation work. Additionally: integrate LeetPulseDesignSystem as the single source of styling (colors, typography, spacing) across all visualization code, consolidate DataJourney code ownership (CodeBench owns visualization, TestCaseEvaluator owns data), and audit all renderers for similar issues.

</domain>

<decisions>
## Implementation Decisions

### Node Identity Scheme
- Replace `let id = UUID()` with stable composite IDs derived from existing data models
- Graph nodes: value + index composite (e.g., `"node-0-val5"`) — index differentiates duplicate values
- Trie nodes: use existing `trieNodeId` string already stored but currently ignored
- Tree nodes: already use stable `id: String` from `TraceTreeNode` — keep as-is
- Linked list nodes: use semantic `id` from `TraceListNode` — already stable
- Edge identity: source-target pair (e.g., `edge-fromIdx-toIdx`) — sufficient for the problem set
- All composite IDs are internal only — not displayed in the view

### Animation Behavior
- Nodes are stationary landmarks; pointer variables animate between nodes with directional arrows
- Same pattern for arrays: cells are fixed, pointers (i, j, left, right) animate between positions
- Existing curved arc pointer motion style (already built) is kept as-is
- Tree node insertion: slides in from parent node
- Node removal (deletion): fade out in place, then remaining nodes reposition
- Value changes in-place: brief highlight pulse to draw attention
- Diff highlighting: color + brief pulse animation (not color only)
- Diff colors from LeetPulseDesignSystem: success green (added), danger red at 25% opacity (removed), warning amber (modified)
- Animation duration: medium 0.4-0.5s for transitions
- Highlight pulse duration: matches pointer duration (0.4-0.5s synchronized)
- Multiple simultaneous changes: all animate at the same time (not sequenced)

### Design System Integration
- Add LeetPulseDesignSystem as a git-based SPM dependency
- ALL visualization styling (colors, typography, spacing) must come from the design system — no hardcoded values
- Full sweep of all visualization files to replace every hardcoded color, font, and size with DS tokens
- Wire up both light and dark theme using DS theme tokens
- Use DS diff colors: success (`#16A349`/`#49DD7F`), danger (`#DB2626`/`#F77070` at 25% opacity), warning (`#F49E0A`/`#F9BF35`)
- Use Okabe-Ito colorblind-safe palette for categorical visualization needs

### Fix Boundary
- Audit all 14 renderers for UUID identity and layout-in-body patterns — fix everything found
- Fix all issues found during audit (not just identity/layout — any issues encountered while in the file)
- Consolidate DataJourney ownership: CodeBench owns all visualization/display code, TestCaseEvaluator owns all data production
- Remove duplicate DataJourney files from TestCaseEvaluator — they should not exist there
- TestCaseEvaluator provides JSON data that DataJourney consumes; CodeBench's DataJourney handles all rendering and user interaction
- Architecture: TestCaseEvaluator = data engine (computation, processing, JSON serialization); DataJourney = rendering layer with its own display business logic

### Layout Caching
- Simple layout memoization: compute once per data change, store in @State
- Recompute only when graph/tree data actually changes — not on every SwiftUI body evaluation
- No complex caching infrastructure needed — max ~40 nodes makes computation trivial
- All layout types (graph, tree, trie) use the same caching pattern for consistency
- In-memory only — no disk persistence
- No debug overlay for cache stats

### Node Limit
- Hard limit of 40 nodes for visualization — fixed, not configurable
- Beyond 40: show first 40 nodes with "...and N more" indicator

### Verification
- Manual visual check for correctness + automated Xcode Instruments profiling for 60fps
- Dedicated debug-only test view (`#if DEBUG`) with rapid step transitions across all structure types
- Test harness covers all data structure types: arrays, linked lists, trees, graphs, tries, matrices, heaps, strings
- 60fps target applies to all supported devices
- Minimum deployment target: iOS 17+ (full access to PhaseAnimator, matchedGeometryEffect)
- Grep-based check to confirm zero hardcoded color/font/size values remain after DS migration
- TestCaseEvaluator must build + all tests pass after DataJourney removal
- SwiftLint rule to flag `UUID()` in Identifiable types — prevents regression

### Claude's Discretion
- Edge identity scheme details (source-target pair recommended, extend if multi-edges needed)
- Graph re-layout vs maintain positions on structural changes (re-layout with animation recommended)
- Force-directed vs deterministic graph layout algorithm
- Graph layout settling animation visibility
- SPM module organization for the consolidation
- Exact cleanup approach for duplicate files (git history preserves everything)
- Layout cache implementation details (@State vs @StateObject)

</decisions>

<specifics>
## Specific Ideas

- "Nodes are stationary landmarks, pointers animate along them with arrows showing from/to positions"
- All styling from LeetPulseDesignSystem — colors, typography, spacing, everything
- "TestCaseEvaluator provides all data. DataJourney does its own business logic to render. It has its own user input data while rerendering which maps back to TestCaseEvaluator to update saved JSON."
- LeetPulseDesignSystem is hosted in git at /Users/ashimdahal/Documents/LeetPulseDesignSystem
- DS already has DSBubbleChangeType with added/removed/modified/unchanged states and corresponding colors

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (expanded scope was intentionally added by user: DS integration, consolidation, full audit)

</deferred>

---

*Phase: 01-foundation-bug-fixes*
*Context gathered: 2026-02-25*
