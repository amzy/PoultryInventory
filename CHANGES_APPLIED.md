# Archive 16 — Mobile Admin Navigation

- Removed the mobile navigation drawer/side panel completely.
- Mobile bottom navigation is now Home, Daily, Reports, Admin.
- Renamed Settings navigation label to Admin.
- Admin screen contains the profile/avatar at the top.
- Admin menu sections are listed below the profile and users select a section to display its content.
- Standards Calendar is not in the side/mobile navigation; it remains accessible from its dashboard shortcut.
- Removed mobile header/dashboard hamburger actions because no drawer is used.
- Desktop sidebar remains available on desktop/tablet-wide layouts.

- Added Admin → Market picker. Ajmer is the default market; selected market is persisted locally and is available through MarketConfig for market-price features.

## Dashboard Today Price Card
- Added a compact Today Price dashboard card using the selected market.
- Ajmer currently displays the latest researched reference rate of ₹5.51/egg (12 Sep 2026).
- The card opens the market source for verification instead of presenting a hard-coded rate as a live API feed.
- Non-Ajmer markets display “Check market” until a live feed is connected for that market.
