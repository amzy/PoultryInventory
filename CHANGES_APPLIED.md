# Poultry Inventory — Changes Applied

Applied from the existing source archive:

- Added Suppliers to the main sidebar and dashboard navigation.
- Added dedicated Suppliers directory with search, contact-style cards, add/edit, and optional category.
- Added supplier category persistence while keeping existing supplier records backward compatible.
- Added recent supplier preview + List All in admin settings.
- Improved member administration cards with contact-style presentation, List All, edit action, language picker, and role picker.
- Added flock membership UID handling so member role changes target the correct membership document.
- Added Firebase member-role update support.
- Added Google new-account completion flow: Google profile preview, mobile, optional age, account type, and invited-flock detection.
- Invited Google users are automatically preselected as Member and pending invitations are claimed after completion.
- Added dashboard flock summary header with flock name, breed, age, birds alive, start date, and current date.
- Added Earnings metric beside Expenses.
- Added Recent Transactions feed with overlapping account + supplier avatars.
- Changed Recent Daily Logs presentation to use a user avatar when creator information is available.
- Renamed dashboard financial section to Expenses / Earnings and fixed credit selection behavior.
- Kept Daily Logs separate from financial transactions and retained existing financial category model.

Validation note: Flutter/Dart tooling is not installed in this execution environment, so `flutter analyze`, `flutter test`, and a release Web build could not be executed here. The source was inspected and edited directly; run the project validation commands on the development Mac before deployment.
