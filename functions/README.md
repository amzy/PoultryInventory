# OvalOasis market-price backend

The Flutter app reads `market_prices/{marketId}` from Firestore. These documents are written by the scheduled Cloud Function, so API credentials never ship to Android, iOS, or Web.

## Data source

1. Preferred: mKisan Egg Rates API, using the `MKISAN_API_KEY` Firebase secret. The API provides daily NECC egg rates by city.
2. Fallback: EggRates.in city pages, which publish daily NECC reference rates. The fallback is server-side only and is not called directly by Flutter.

## Deployment

Cloud Functions scheduling requires the Firebase/Google Cloud billing configuration that enables Cloud Scheduler. Before deployment:

```bash
cd functions
npm install
cd ..
firebase functions:secrets:set MKISAN_API_KEY
firebase deploy --only functions:syncEggMarketPrices,functions:refreshEggMarketPrices,firestore:rules
```

If no mKisan API key is configured, the function still attempts the server-side EggRates.in fallback for supported cities.

The scheduled job runs every day at **06:15 Asia/Kolkata**. NECC rates may not change on Sundays/public holidays; in that case the latest published rate remains valid.
