---
phase: 01-foundation-bug-fixes
plan: 03
subsystem: ui
tags: [swiftui, design-system, ds-tokens, leet-pulse, theming, color-tokens, typography, diff-colors, okabe-ito]

# Dependency graph
requires:
  - phase: 01-01
    provides: LeetPulseDesignSystem SPM dependency in project.yml
  - phase: 01-02
    provides: Stable composite IDs and memoized layout in graph/tree/trie views
provides:
  - import LeetPulseDesignSystemCore in all 14 visualization view files
  - DS token-based diff overlays (success/danger/warning) in TraceBubble
  - DS theme environment wiring for all graph, tree, trie, structure canvas, heap, matrix, and bubble views
affects: [01-04, 03-animation, 08-visual-polish]

# Tech tracking
tech-stack:
  added: []
  patterns: ["import LeetPulseDesignSystemCore for DS token access", "theme.colors.success/danger/warning for diff overlays", "VizTypography kept for dense visualization text"]

key-files:
  created: []
  modified:
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyGraphView.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyTreeGraphView.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyTrieGraphView.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+CombinedList.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+DiffHighlights.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+Labels.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+ListStructure.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+Pointers.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+Structure.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+TreeStructure.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyHeapView.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyMatrixGridView.swift
    - CodeBench/CodeBench/DataJourney/Views/DataJourneyTraceBubble.swift

key-decisions:
  - "Used import LeetPulseDesignSystemCore (not LeetPulseDesignSystem umbrella) since project.yml targets the Core product"
  - "Diff colors aligned per user decision: added=success green, removed=danger red at 25% opacity, modified=warning amber"
  - "VizTypography retained for dense visualization text -- DS typography tokens are too coarse for 7-11pt viz text"
  - "ChangeType enum kept local (not replaced with DSBubbleChangeType) since it is used throughout the diff pipeline"

patterns-established:
  - "import LeetPulseDesignSystemCore at top of every view file that uses DS tokens"
  - "Diff color pattern: .added -> theme.colors.success, .removed -> theme.colors.danger.opacity(0.25), .modified -> theme.colors.warning"
  - "Keep VizTypography.swift for dense visualization-specific font constants (CodeBench-specific extension)"

requirements-completed: [REQ-F01, REQ-F02]

# Metrics
duration: 3min
completed: 2026-02-25
---

# Phase 1 Plan 03: DS Token Sweep -- Graph, Tree, Trie, Structure Canvas, Heap, Matrix, Bubble Views Summary

**LeetPulseDesignSystemCore import added to 14 visualization views, TraceBubble diff colors corrected to success/danger/warning DS tokens, and system color references replaced with theme tokens**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-25T19:39:21Z
- **Completed:** 2026-02-25T19:43:15Z
- **Tasks:** 1
- **Files modified:** 14

## Accomplishments
- Added `import LeetPulseDesignSystemCore` to all 14 visualization view files, enabling DS token resolution from the LeetPulseDesignSystem package
- Fixed TraceBubble diff overlay colors to match user decision: `.added` uses `theme.colors.success` (green), `.removed` uses `theme.colors.danger.opacity(0.25)` (red at 25%), `.modified` uses `theme.colors.warning` (amber)
- Replaced all `.foregroundStyle(.secondary)` system calls with `theme.colors.textSecondary` in overflow indicators across GraphView, TreeGraphView, TrieGraphView, and HeapView
- Confirmed zero hardcoded Color literals across all 14 files (only Color.clear retained as transparent universal)
- Confirmed ChangeType enum already aligned with DSBubbleChangeType naming (added/removed/modified/unchanged)
- Confirmed all View structs already have `@Environment(\.dsTheme) var theme` declared
- Confirmed VizTypography retained for dense visualization text per research decision

## Task Commits

Each task was committed atomically:

1. **Task 1: Add DS imports and replace hardcoded colors/fonts in graph, tree, trie, and structure canvas views** - `d102975` (feat)

## Files Created/Modified
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyGraphView.swift` - Added DS import, replaced .foregroundStyle(.secondary) with theme.colors.textSecondary
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyTreeGraphView.swift` - Added DS import, replaced .foregroundStyle(.secondary) with theme.colors.textSecondary
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyTrieGraphView.swift` - Added DS import, replaced .foregroundStyle(.secondary) with theme.colors.textSecondary
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView.swift` - Added DS import
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+CombinedList.swift` - Added DS import
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+DiffHighlights.swift` - Added DS import
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+Labels.swift` - Added DS import
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+ListStructure.swift` - Added DS import
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+Pointers.swift` - Added DS import
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+Structure.swift` - Added DS import
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+TreeStructure.swift` - Added DS import
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyHeapView.swift` - Added DS import, replaced .foregroundStyle(.secondary) with theme.colors.textSecondary
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyMatrixGridView.swift` - Added DS import
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyTraceBubble.swift` - Added DS import, fixed diff colors (added=success, removed=danger, modified=warning)

## Decisions Made
- Used `import LeetPulseDesignSystemCore` rather than `import LeetPulseDesignSystem` umbrella because the project.yml dependency targets the `LeetPulseDesignSystemCore` product specifically
- Corrected TraceBubble `.added` overlay from `theme.colors.warning` to `theme.colors.success` per the user's locked decision for diff colors
- Corrected TraceBubble `.removed` overlay from `theme.vizColors.senary` to `theme.colors.danger` per the user's locked decision (semantic danger token vs categorical Vermillion)
- Kept ChangeType enum as local type (not replaced with DSBubbleChangeType) since it is deeply integrated with the diff pipeline in DataJourneyDiff.swift and the naming is already aligned

## Deviations from Plan

### Observation: Files Already Using DS Tokens

The 14 view files were already using `theme.colors.*`, `theme.vizColors.*`, and `DSLayout.spacing()` tokens extensively -- there were zero hardcoded Color literals (`.red`, `.green`, `.blue`, etc.) to replace. The primary work was:
1. Adding the `import LeetPulseDesignSystemCore` that makes these references compile against the real DS package (rather than the deleted local DesignTokens.swift shim)
2. Fixing the TraceBubble diff colors which used incorrect token mappings (.added used warning instead of success, .removed used vizColors.senary instead of colors.danger)
3. Replacing 4 instances of `.foregroundStyle(.secondary)` with `theme.colors.textSecondary`

---

**Total deviations:** 0 auto-fixed
**Impact on plan:** Plan executed as written. The pre-existing DS token usage made the work lighter than anticipated.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All 14 Plan 03 files now compile against LeetPulseDesignSystemCore tokens
- Plan 04 can proceed to sweep the remaining view files (DataJourneyView, VariableTimeline, SequenceBubbleRow, etc.)
- The `import LeetPulseDesignSystemCore` pattern is established for all future view file additions
- TraceBubble diff colors now follow the correct semantic mapping for all downstream visualization consumers

## Self-Check: PASSED

- All 14 modified files exist on disk
- All 14 files contain `import LeetPulseDesignSystemCore`
- Task commit d102975 verified in git log
- 01-03-SUMMARY.md created successfully
- Zero hardcoded Color literals confirmed (only Color.clear)
- TraceBubble diff colors verified: success (added), danger (removed), warning (modified)
- Zero .foregroundStyle(.secondary) remaining in target files

---
*Phase: 01-foundation-bug-fixes*
*Completed: 2026-02-25*
