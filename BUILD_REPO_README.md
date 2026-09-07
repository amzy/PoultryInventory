# Poultry Inventory — Private Mobile Build Repository

This is a complete Flutter project copy intended to live in a separate private GitHub repository and be built by the owner's M2 MacBook Air self-hosted GitHub Actions runner.

## Included
- Flutter application source (`lib/`)
- Android project (`android/`)
- Web project (`web/`)
- App icon assets (`assets/app_icons/`)
- Google Sheets integration
- Daily Log automatic Starting Birds calculation
- GitHub Actions mobile build workflow
- iOS preparation script (`scripts/prepare_ios.sh`)

## Builds
The workflow manually builds:
- Android release APK
- Android release AAB
- iOS unsigned IPA

No App Store Connect, TestFlight, Google Play, or signing credentials are configured.

## Runner
The workflow expects your M2 Mac runner to have these labels:
- `self-hosted`
- `macOS`
- `ARM64`
- `poultry`

Recommended runner name: `Poultry-MacBook-Air-M2`.

## Run a build
GitHub → Actions → Build Poultry Inventory Mobile Apps → Run workflow.

Provide a version such as `1.0.0` and build number such as `1`.

The completed workflow exposes three downloadable artifacts: APK, AAB, and unsigned IPA.
