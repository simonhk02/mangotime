# Handling App Store review rejections

## Guideline 2.1 "Information Needed" — the new-account questionnaire

This is a PROCESS rejection, not a quality judgment. Apple sends it routinely to new developer accounts on first submission (anti-fraud) and to apps submitted with empty App Review notes. A real defect rejection says "Guideline 2.1 — Bugs/Crashes" and attaches crash logs — don't confuse the two.

**Usually no new build is needed** — reply in App Store Connect's Resolution Center; the app re-enters the review queue on reply (typical turnaround 24–48 h).

## Where the details live

- The notification email contains NO details — it only says "visit the App Review page in App Store Connect". The full reviewer questions are on the app's App Review page (web or the ASC iOS app → tap the message, scroll).
- The email lands in the **developer-account mailbox** (this user: the Yahoo address behind the Apple ID), not Gmail — searching Gmail finds only TestFlight/CI mail.
- ASC web is a slow SPA; on a flaky network it renders an empty page. The App Store Connect **API** (`appstore-connect-api` skill) still works for app/submission state when the web UI won't load.

## The standard 6-item ask (answer each numbered, paste-ready)

1. **Screen recording** — physical device, latest iOS, starting from app launch, showing the typical user flow; include paywall/paid-feature access, and account registration/login/deletion flows IF accounts exist (state explicitly when they don't). Upload to Drive, link in the reply.
2. Purpose + target audience + problem solved.
3. Setup/access instructions (demo credentials if account-based).
4. External services used (for on-device apps: state "none — 100% on-device, only StoreKit for IAP").
5. Regional differences (usually: none, identical in all regions).
6. Regulated-industry/protected-material docs (usually: not applicable).

Also paste the same answers into **App Review Information → Notes** so future submissions carry them — this prevents repeat questionnaires.

## Prevention

Fill the Notes field on FIRST submission (what the app does, how to reach the paywall, demo account if any) — most Information Needed rejections trace back to an empty Notes field on a new account.