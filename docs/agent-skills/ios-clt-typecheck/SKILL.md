---
name: ios-clt-typecheck
description: "Use when verifying iOS Swift code without Xcode (CLT only)."
version: 1.0.0
metadata:
  hermes:
    tags: [ios, swift, verification, xcode, clt]
    category: software-development
---

# Verify iOS Swift code without Xcode (CLT typecheck harness)

macOS with only Command Line Tools (`xcode-select -p` → /Library/Developer/CommandLineTools) can genuinely typecheck SwiftUI/SwiftData/Charts/StoreKit iOS code — the CLT macOS SDK ships those frameworks. Two blockers and their fixes:

1. **Missing macro plugins**: CLT lacks `SwiftDataMacros` and `PreviewsMacros` (`/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/` has only Observation/SwiftMacros/Testing). `@Model` and `#Preview` fail with "external macro implementation type ... could not be found". Fix: typecheck COPIES in scratch where `#Preview` blocks are regex-stripped and `@Model` classes are replaced by hand-written stubs exposing the exact same public API (plus stubs for `ModelContext`/`ModelContainer`/`FetchDescriptor`/`Schema`/`@Query`/`EnvironmentValues.modelContext`/`Scene.modelContainer`). Working stub template: ~/.hermes/cache/scratch/ironlog_harness/Stubs.swift (regenerate if pruned).
2. **iOS-only APIs error as 'unavailable in macOS'**: either gate with `#if os(iOS)` (UIKit haptics, `.navigationBarTitleDisplayMode`) or prefer cross-platform equivalents (`.primaryAction` over `.topBarTrailing`, `.navigation` over `.topBarLeading`, `.pickerStyle(.menu)` over `.navigationLink`, drop `.toolbarColorScheme`).

## Harness adaptation lessons (BrewDial, 2026)

- Views using `ForEach(models)` without `id:` or `.tag(Optional(model))` require the stub base class to conform to `Identifiable, Hashable` (real `PersistentModel` refines both). Use identity `==`/`hash` via `ObjectIdentifier`.
- Stores using `ModelConfiguration(schema:isStoredInMemoryOnly:)` + `ModelContainer(for:configurations:)` need those two stubs added; `ModelContainer` then needs both init overloads.
- When a @Model file carries real logic (streak math, computed stats in extensions), keep the REAL file in the harness: strip only `import SwiftData`, the `@Model` line, and any `@Relationship(...)` attribute line, then append `: StubPersistentModel` to the class declaration. API-mirror stubs in Stubs.swift skip the model's own logic — this variant typechecks it.
- Modifiers with no cross-platform equivalent (`.navigationBarTitleDisplayMode`, `.interactiveDismissDisabled`) can't take `#if` mid-modifier-chain — wrap them in a `private extension View` `@ViewBuilder` helper with the `#if os(iOS)` inside, and call the helper.
- Dynamic light/dark colors via `UIColor(dynamicProvider:)` don't exist on macOS: use `#if canImport(UIKit)` / `#else import AppKit` with a `private typealias PlatformColor` and `NSColor(name: nil) { appearance in appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }`. `NSColor(name:dynamicProvider:)` is NON-optional — no force unwrap.
- Verify assumptions against the SDK interface before writing fixes: `grep` the framework's `x86_64-apple-macos.swiftinterface` under `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/` (View/App/Scene are `@MainActor` there, so `@MainActor` singletons read from view bodies typecheck fine; `SwiftUICore.framework` holds `View`).

## Workflow
0. If `xcode-select -p` points at `/Applications/Xcode.app` (Xcode installed later), bare `swiftc`/`xcrun` and even `git`/`python3` fail with "You have not agreed to the Xcode license agreements" until the license is accepted — run every harness command with absolute CLT paths (`/Library/Developer/CommandLineTools/usr/bin/swiftc`, `.../git`) so the harness works in either state.
1. `swiftc -parse -swift-version 5 -target x86_64-apple-macos14.0 -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk <file>` per file — fast syntax gate.
2. Build harness dir: real files minus `import SwiftData` / `#Preview`, plus Stubs.swift.
3. `swiftc -typecheck -swift-version 5 -target x86_64-apple-macos14.0 -sdk ... *.swift` — whole-module, ~2-4 min for 15 SwiftUI files; run backgrounded (foreground >300s times out).
4. Iterate to 0 errors. When the bar is 0 warnings, re-run with `-warnings-as-errors`. Guard against false green: once per harness, compile a scratch file referencing an undefined symbol and confirm an `error:` is actually reported. Report honestly: view/logic layer verified against API-identical stubs; `@Model` macro expansion itself still needs one real Xcode build (TODO-COMPILE).

## Verifying CI green via REST (no gh)

Poll `GET /repos/{owner}/{repo}/actions/runs`, then `/actions/runs/{id}/jobs` for per-step conclusions. Don't trust step conclusions alone for a build: download the build-log artifact and grep it for `** BUILD SUCCEEDED **` plus `SwiftCompile` lines covering the expected files. Pitfall: `archive_download_url` answers with a 302 to a signed CDN URL — refetch that URL WITHOUT the `Authorization` header or it 403s.

Also: XcodeGen project.yml keys can be sanity-checked by string-matching when pyyaml isn't installed (execute_code sandbox lacks yaml module).