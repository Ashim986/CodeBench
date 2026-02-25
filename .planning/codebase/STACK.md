# Technology Stack

**Analysis Date:** 2026-02-24

## Languages

**Primary:**
- Swift 5.9+ - iOS/macOS application code and test generation
- Python 3 - Build automation and test case generation scripts

**Secondary:**
- JSON - Data interchange for test cases and results
- YAML - Project configuration (XcodeGen)

## Runtime

**Environment:**
- iOS 26.0+ (minimum deployment target)
- macOS 26.0+ (SPM test suite runs on macOS)

**Package Manager:**
- SPM (Swift Package Manager) - Primary dependency manager for Swift
- Lockfile: `Package.resolved` (not visible, but managed by SPM)

## Frameworks

**Core - iOS App:**
- SwiftUI - UI framework
- Foundation - Core data types, JSON decoding, concurrency

**Testing:**
- Swift Testing - Modern testing framework (Swift 6+)
  - Config: `Package.swift` defines test targets
  - Location: `/Users/ashimdahal/Documents/CodeBench/TestCaseEvaluator/Tests/`

**Build/Dev:**
- Xcode 16.0+ - IDE and build system
- XcodeGen - Project generation from YAML configuration
  - Config file: `CodeBench/project.yml`
- SPM (Swift Package Manager) - Test suite build system
  - Version: 6.2+
  - Config: `TestCaseEvaluator/Package.swift`

## Key Dependencies

**Critical:**
- LeetCodeHelpers (internal SPM library) - Shared test utilities
  - Location: `TestCaseEvaluator/Sources/LeetCodeHelpers/`
  - Provides: Input/output serialization, data structure builders (TreeNode, ListNode, etc.)

**Infrastructure:**
- Foundation framework - Provides Actor concurrency model for thread-safe result recording
- FileManager - Local file I/O for test results and bundled JSON files

## Configuration

**Environment:**
- iOS app loads test results from bundled JSON files or user-selected directories
- No external configuration files or environment variables required
- Bundle resource access: Uses `Bundle.module` for SPM, `Bundle.main` for Xcode projects

**Build:**
- XcodeGen YAML config: `CodeBench/project.yml`
  - Bundle ID prefix: `com.focus.codebench`
  - App version: 1.0.0
  - Build settings include:
    - `SWIFT_STRICT_CONCURRENCY: complete` (enforces strict concurrency)
    - `GENERATE_INFOPLIST_FILE: true`
    - Code signing: Automatic

## Platform Requirements

**Development:**
- macOS 26.0+ (build machine)
- Xcode 16.0+
- Python 3+ (for test generation scripts)
- Swift 6.0+ CLI toolchain

**Production - iOS:**
- iOS 26.0+ devices/simulators
- 8MB+ storage (for bundled test data)
- No external network dependencies

**Production - Test Suite:**
- macOS 26.0+
- Swift 6.0+ toolchain
- Runs via `swift test` or Xcode test runner

## Deployment

**App Distribution:**
- Xcode project (`CodeBench/CodeBench.xcodeproj`)
- Can be built and signed for App Store or TestFlight
- Bundle ID: `com.focus.codebench`

**Test Results Output:**
- JSON files written to filesystem by ResultRecorderActor
- Summary structure: `summary.json` + topic-specific JSON files
- Directory structure: Topic names map to filenames (e.g., `arrays-hashing.json`)

---

*Stack analysis: 2026-02-24*
