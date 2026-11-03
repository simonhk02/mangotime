---
name: appstore-connect-api
description: "Use when automating App Store Connect via the REST API."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [appstore, asc, ios, api, iap, subscriptions]
    category: software-development
---

# App Store Connect REST API automation

## When to Use
Any task that reads or mutates App Store Connect state programmatically: creating/pricing IAPs and subscriptions, uploading listing metadata, checking app/product/review state, verifying another agent's ASC work. For the end-to-end ship pipeline, see the `ios-app-store-shipping` skill.

Automates IAP/subscription creation, pricing, availability, listing metadata, and state checks against `https://api.appstoreconnect.apple.com`. Auth + exact body shapes: `references/api-recipes.md`. Reusable JWT/api helper: `scripts/asc_api.py` (import it, don't re-hand-roll).

## Auth
JWT ES256: payload `{iss: <issuer-uuid>, iat, exp: iat+≤1200, aud: 'appstoreconnect-v1'}`, headers `{kid: <key-id>, typ: 'JWT'}`, signed with the `.p8`. This user's key: `~/.hermes/secure/AuthKey_9V552N6G8U.p8`, iss `86743a9d-5f0a-46b8-a007-ae7ada62d54a` (verify before reuse — keys rotate). System python3 has PyJWT; run scripts via execute_code's python when /usr/bin/python3 is a broken xcrun shim.

## Hard capability lines (don't burn time)
- **Creating app records is NOT possible via API** — web UI only (ASC → Apps → + → New App). Registering bundle IDs IS possible (`POST /v1/bundleIds`) and records need them pre-registered.
- **App-level price schedule (Free/Paid) and App Review contact phone are web-only.** So is the privacy questionnaire UI, though `data not collected` apps are one click.
- App NAME must be globally unique: check `https://itunes.apple.com/search?term=<name>&entity=software&country=us` BEFORE attempting record creation; collisions surface only at create time. Keep a `Name: Descriptor` backup (≤30 chars) per app.

## Ordering rules that cost time when violated
- Set **availability (all territories) BEFORE prices** — pricePoints/price POSTs fail or find nothing on unavailable products.
- **pricePoints lists are huge**: always `filter[territory]=USA&limit=200` AND follow `links.next` pagination (up to ~10 pages) matching `attributes.customerPrice` as a string.
- Verify writes with per-resource v2 GETs, never legacy v1 reads: `/v1/inAppPurchases/{id}/prices` and `/priceSchedule` 404/empty even on correctly priced items. Sanity-fingerprint: a correctly configured-but-unbuilt app shows `state=MISSING_METADATA` (= missing review screenshot, comes with the build) — compare against a known-good submitted app when in doubt.

## Endpoint/attribute pitfalls (each bit cost a 409)
- `subscriptionLocalizations`: attributes are `name` + `description` — **`displayName` does not exist**; `description` max **55 chars**.
- `inAppPurchaseLocalizations` POST relationship is named **`inAppPurchaseV2`**, not `inAppPurchase`.
- `inAppPurchasePriceSchedules` inline `included` id must be a literal local id **`${p1}`** — a placeholder UUID is rejected with INCLUDED.INVALID_ID.
- Categories: PATCH `/v1/appInfos/{id}` relationships use type **`appCategories`** (`FOOD_AND_DRINK`, `HEALTH_AND_FITNESS`, `PRODUCTIVITY`, `LIFESTYLE`…), not `categories`.
- Listing metadata: `appStoreVersionLocalizations` (description ≤4000, keywords ≤100, promotionalText ≤170, supportUrl) is PATCH on the auto-created en-US row; `appInfoLocalizations` (subtitle, privacyPolicyUrl) likewise. Keywords: drop trailing comma-terms to fit 100.
- Subscription creation: `POST /v1/subscriptions` under a group with `subscriptionPeriod`, `groupLevel`, `reviewNote`; trial via `POST /v1/subscriptionIntroductoryOffers` `{offerMode: FREE_TRIAL, duration: ONE_WEEK, numberOfPeriods: 1}` + territory relationship.
- `/v2/inAppPurchases?filter[appId]=…` silently returns nothing — enumerate products via `/v1/apps/{app}/inAppPurchases`.
- **Rejection reasons are NOT retrievable via the REST API**: `reviewSubmissionItems` rejects GET_INSTANCE (403, only CREATE/DELETE/UPDATE allowed), has no `appReviewDetails` relationship (404 PATH_ERROR), and `?include=appReviewDetails` on the items list is rejected (400). When an item shows `state=REJECTED`, the actual guideline text lives only in the App Review email to the account holder and ASC web → Resolution Center. Confirm the rejection via `/v1/apps/{appId}/appStoreVersions` (`appVersionState=REJECTED`) and point the user there.

## Proven full chains
See `references/api-recipes.md` for exact JSON bodies: yearly-sub-with-trial, lifetime non-consumable, listing metadata upload.