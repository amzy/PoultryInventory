# Web deployment / custom domain

The Flutter Web application uses the custom production domain:

https://www.ovaloasis.in/

## Flutter Web base path

Because the application is hosted at the domain root, Flutter Web must be built with:

```bash
flutter build web --release --base-href /
```

Do **not** use `/PoultryInventory/` as the base href for the production site. Using the old GitHub Pages sub-path can break asset loading and client-side navigation on `ovaloasis.in`.

## Custom domain

The repository contains `web/CNAME` with:

```text
ovaloasis.in
```

When the web build is deployed, this file is copied into `build/web/CNAME` so GitHub Pages can retain the custom domain.

In GitHub, configure:

**Repository → Settings → Pages → Custom domain**

Set it to:

`ovaloasis.in`

Then enable HTTPS after GitHub finishes verifying the DNS configuration.

## DNS

At the DNS provider for `ovaloasis.in`, configure the records required by GitHub Pages for the repository. Use GitHub's current Pages documentation as the authoritative source for the exact A/AAAA/CNAME records for the repository.

## Google OAuth

The Google Sign-In Web OAuth client must allow the production browser origin:

`https://ovaloasis.in`

Do not add a path such as `/PoultryInventory/` to the authorized JavaScript origin.

Also ensure `ovaloasis.in` is present in Firebase Authentication → Settings → Authorized domains if Firebase Authentication is used on the web app.

The existing Web OAuth client ID in `web/index.html` remains unchanged; changing the domain does not require changing the client ID, but its authorized origins must include the new domain.

For local development, continue using the local development origin configured for your Flutter web run command.
