# ASC API recipes (proven body shapes)

Base: `https://api.appstoreconnect.apple.com`, `Authorization: Bearer <ES256 JWT>`.

## Yearly subscription + 7-day free trial (per app)
Order matters — each step depends on the previous id.

1. Group: `POST /v1/subscriptionGroups`
   `{"data":{"type":"subscriptionGroups","attributes":{"referenceName":"<App> Pro"},"relationships":{"app":{"data":{"type":"apps","id":"<APP_ID>"}}}}}`
2. Group loc: `POST /v1/subscriptionGroupLocalizations` `{locale:"en-US", name:"<App> Pro"}` + relationship `subscriptionGroup`.
3. Subscription: `POST /v1/subscriptions`
   attributes `{productId, name, subscriptionPeriod:"ONE_YEAR", groupLevel:1, familySharable:true, reviewNote}` + relationship `group`.
4. Sub loc: `POST /v1/subscriptionLocalizations` attributes `{locale:"en-US", name:"<App> Pro Yearly", description:"≤55 chars"}` + relationship `subscription`. NO displayName attr.
5. Availability: `POST /v1/subscriptionAvailabilities` attributes `{availableInNewTerritories:true}` + relationships `subscription`, `availableTerritories` (array from `GET /v1/territories?limit=200`).
6. Price point: `GET /v1/subscriptions/{sub}/pricePoints?filter[territory]=USA&limit=200` (paginate) → id where `customerPrice=="9.99"`.
7. Price: `POST /v1/subscriptionPrices` attributes `{startDate:null}` + relationships `subscription`, `subscriptionPricePoint`, `territory=USA`.
8. Trial: `POST /v1/subscriptionIntroductoryOffers` attributes `{offerMode:"FREE_TRIAL", duration:"ONE_WEEK", numberOfPeriods:1}` + relationships `subscription`, `territory=USA`.

## Lifetime non-consumable IAP
1. `POST /v2/inAppPurchases` attributes `{productId, name, inAppPurchaseType:"NON_CONSUMABLE", familySharable:true, reviewNote}` + relationship `app`.
2. Loc: `POST /v1/inAppPurchaseLocalizations` attributes `{locale:"en-US", name, description}` + relationship **`inAppPurchaseV2`**.
3. `POST /v1/inAppPurchaseAvailabilities` (same shape as sub availability, relationship `inAppPurchase`).
4. Price points: `GET /v2/inAppPurchases/{id}/pricePoints?filter[territory]=USA&limit=200` (paginate).
5. Schedule — note the literal `${p1}` local id:
```json
{"data":{"type":"inAppPurchasePriceSchedules","relationships":{
  "inAppPurchase":{"data":{"type":"inAppPurchases","id":"<IID>"}},
  "baseTerritory":{"data":{"type":"territories","id":"USA"}},
  "manualPrices":{"data":[{"type":"inAppPurchasePrices","id":"${p1}"}]}},
 "included":[{"type":"inAppPurchasePrices","id":"${p1}",
  "attributes":{"startDate":null,"endDate":null},
  "relationships":{
   "inAppPurchasePricePoint":{"data":{"type":"inAppPurchasePricePoints","id":"<PPID>"}},
   "inAppPurchaseV2":{"data":{"type":"inAppPurchases","id":"<IID>"}}}}]}
```

## Listing metadata upload
- `GET /v1/apps/{app}/appStoreVersions` → `GET /v1/appStoreVersions/{vid}/appStoreVersionLocalizations` → `PATCH /v1/appStoreVersionLocalizations/{loc}` attributes `{description, keywords, promotionalText, supportUrl}`.
- `GET /v1/apps/{app}/appInfos` → `GET /v1/appInfos/{iid}/appInfoLocalizations` → `PATCH /v1/appInfoLocalizations/{loc}` attributes `{subtitle, privacyPolicyUrl}`.
- Categories: `PATCH /v1/appInfos/{iid}` relationships `primaryCategory`/`secondaryCategory`, data `{type:"appCategories", id:"<NAME>"}`.

## State verification
Fingerprint of a correctly-configured pre-build product: sub `locs=1 prices=1 trials=1 avail=set`, IAP `locs=1 avail=set schedule POST 201`, both `state=MISSING_METADATA` (= review screenshot pending the first build). Verify against `/v1/subscriptions/{id}/{subscriptionLocalizations,introductoryOffers,prices,subscriptionAvailability}` and `/v2/inAppPurchases/{id}/{inAppPurchaseLocalizations,inAppPurchaseAvailability}` — NOT legacy v1 price reads (they 404 on good data).
