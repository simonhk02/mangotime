---
name: ios-app-store-shipping
description: "Use when shipping an iOS app to the App Store end-to-end."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [ios, appstore, shipping, testflight, ci, xcodegen]
    category: software-development
---

# Ship an iOS app to the App Store (end-to-end pipeline)

## When to Use
Taking one of this user's indie iOS apps (SwiftUI + SwiftData, iOS 17+, Swift 5 mode, XcodeGen, no third-party deps) from code-complete to App Store review. Covers repo/CI, icons, ASC records, IAP, metadata, legal pages, TestFlight and submission — the proven pipeline used on 5+ apps.

Specialist skills for individual stages: `ios-clt-typecheck` (verify code without Xcode), `appstore-connect-api` (IAP/metadata/state), `macos-app-install` (Xcode itself), `computer-use` (driving ASC web when API can't).

## Always-on rules
- **Check the app NAME is free first**: `https://itunes.apple.com/search?term=<name>&entity=software&country=us` — collisions only surface at ASC record-creation time. Prepare a `Name: Descriptor` variant (≤30 chars incl. descriptor) per app before anyone opens ASC.
- **Icons**: exactly 1024×1024 PNG, flattened RGB, **no alpha channel** — altool/App Store reject alpha. Wire into `<App>/Assets.xcassets/AppIcon.appiconset/` with a `filename` entry in Contents.json (XcodeGen auto-includes the catalog; verify with `file`, not by eye).
- **CI template is `templates/build.yml`** — macos-15 + xcodegen + simulator build, no signing. Copy and adapt ONLY the project/scheme names; verify any pre-existing workflow by diffing against this template, never by reading.
- **macOS runners bill at 10× on private repos** (~10 included-min per 1-min job). Batch pushes; iterate locally (CLT typecheck, then local xcodebuild once Xcode is licensed); watch the 2,000-min free tier.
- **Web-only steps** (no API exists — assign to the user or drive ASC web): creating the app record, Free/Paid price schedule, App Review contact phone, content-rights and privacy questionnaire answers. Everything else is scriptable via `appstore-connect-api`.
- GitHub auth: PAT from `git credential fill` (osxkeychain). If xcode-select points at Xcode with an unaccepted license, ALL xcrun-shimmed binaries (git, python3, swiftc) fail — call CLT tools by absolute path (`/Library/Developer/CommandLineTools/usr/bin/...`).
- **Review rejections**: `references/review-rejections.md` — the Guideline 2.1 "Information Needed" questionnaire playbook (reply in Resolution Center, usually no new build; fill Notes on first submission to prevent it).

## Pipeline (in order)
1. **Code verify**: `ios-clt-typecheck` whole-module harness to 0 errors / 0 warnings.
2. **Repo + CI**: git init, commit, create PRIVATE repo via REST, push, copy `templates/build.yml` in, poll run to green; confirm with the build-log artifact (`** BUILD SUCCEEDED **` + SwiftCompile lines — not step conclusions alone).
3. **Parallel artifacts**: App Store icon (see rules), `UAT-PLAN.md` written from actual source (ProGate limits, seed data — no invented features), `metadata/` listing copy.
4. **Legal pages**: privacy/terms/support HTML to the `knitpal-pages` GitHub Pages repo as `<app>-privacy.html` etc.; every URL referenced in a paywall or metadata must return 200 before submission (Apple checks the privacy URL).
5. **ASC record** (web): New App with pre-registered bundle ID; then Free pricing, content rights = no third-party content, privacy = Data Not Collected (these apps are 100% on-device), review contact phone (from the user).
6. **IAP + metadata** (`appstore-connect-api`): subscription group → yearly sub + price + 7-day trial + 175 territories; lifetime non-consumable + price; description/keywords/promo/subtitle/privacy+support URLs/categories.
7. **Build + TestFlight** (needs licensed Xcode): `xcodegen generate` → `xcodebuild -archive` → upload → internal tester = the user's own Apple ID email. IAP review screenshots come from this build; products stay `MISSING_METADATA` until then — expected.
8. **UAT → review**: user runs `UAT-PLAN.md` on-device; agent picks build + submits only after explicit user confirmation.

## Verification habits
- Every external write (repo, IAP, metadata, pages) gets read back or status-checked before reporting success.
- When the user forwards another agent's claims, verify against ASC/GitHub directly before relaying next steps.