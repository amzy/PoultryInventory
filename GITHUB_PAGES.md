# GitHub Pages deployment

This project is configured to build and deploy Flutter Web automatically with GitHub Actions.

## Production URL

https://amzy.github.io/PoultryInventory/

## How deployment works

Push the Flutter source to the `main` branch. The workflow in `.github/workflows/deploy-web.yml` will:

1. Install Flutter on GitHub's runner.
2. Run `flutter pub get`.
3. Run `flutter build web --release --base-href /PoultryInventory/`.
4. Publish `build/web` to GitHub Pages.

You can also run the workflow manually from **GitHub → Actions → Build and Deploy Flutter Web → Run workflow**.

## GitHub Pages setting

In the repository, open **Settings → Pages** and set **Build and deployment → Source** to **GitHub Actions**.

## Google OAuth

The production browser origin is:

`https://amzy.github.io`

Do not add `/PoultryInventory/` to the Google OAuth Authorized JavaScript origin. The path is handled by Flutter's base href.

For local development on port 8080, use:

`http://localhost:8080`

The Web OAuth client ID configured in `web/index.html` is:

`395473159192-7i9le93o7tt2nsva4bq8dasf67i9bnrj.apps.googleusercontent.com`
