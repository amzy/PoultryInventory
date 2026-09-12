# Live Market Price Service

OvalOasis Poultry Inventory now uses a server-side daily market-price service instead of hard-coded dashboard prices.

## Flow

```text
NECC daily rates
      ↓
 mKisan Egg Rates API (preferred)
      ↓
 Firebase Cloud Function
      ↓
 Firestore /market_prices/{marketId}
      ↓
 Flutter Dashboard (Admin + Members)
```

A server-side EggRates.in/NECC page fallback is included when the mKisan API is unavailable or a market is not returned by the API. The Flutter app never calls either provider directly and never contains the API key.

## Supported market picker values

Ajmer, Jaipur, Jodhpur, Kota, Udaipur, Delhi, Ahmedabad, Mumbai.

mKisan is the preferred provider and supports city/date egg-rate queries. Kota/Udaipur can remain unavailable when the provider does not publish a rate for those markets; the card shows a clear unavailable state instead of inventing a price.

## Daily refresh

The Cloud Function `syncEggMarketPrices` runs at **06:15 Asia/Kolkata every day**. It writes the latest value and keeps the previous stored value as `yesterdayPrice`, which powers the green/red/neutral market indicator.

The client uses a Firestore snapshot listener, so Admin and Member dashboards update automatically when the server writes a new price. No app update is needed for a new daily rate.

## One-time Firebase setup

The mKisan API requires an API key in the `X-API-Key` request header. Do not put this key in Flutter code, GitHub Actions, or web assets.

From the project root:

```bash
firebase login
firebase use poultryinventory
firebase functions:secrets:set MKISAN_API_KEY
```

Paste the API key when Firebase prompts for it.

Then deploy:

```bash
firebase deploy --only functions:syncEggMarketPrices,functions:refreshEggMarketPrices,firestore:rules
```

The scheduled function requires the Firebase/Google Cloud billing configuration that enables Cloud Scheduler.

## First refresh

After deployment, the scheduled 06:15 IST run remains the normal daily refresh. If the selected market has no `market_prices/{marketId}` document yet, the admin dashboard automatically calls the admin-only `refreshEggMarketPrices` callable once to bootstrap the first value; the Firestore listener then updates the card immediately. The callable is not repeatedly invoked when a document already exists.

## Firestore security

Users who are signed in can read `market_prices`. Client writes are denied. Only Cloud Functions/Admin SDK can write the feed, preventing members or clients from spoofing market prices.
