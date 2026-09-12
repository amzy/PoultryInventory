# OvalOasis Flutter Web Deployment

Production domain:

`https://www.ovaloasis.in/`

The Flutter Web app is configured for the domain root. The production build **must** use:

```bash
flutter build web --release --base-href /
```

Do not use:

```bash
flutter build web --release --base-href /PoultryInventory/
```

The repository includes `web/CNAME` with `ovaloasis.in` and a GitHub Pages workflow at `.github/workflows/deploy-web.yml` that always builds with `/` as the base href.

## Verify the generated build

After building:

```bash
ls -l build/web/flutter_bootstrap.js
cat build/web/index.html | grep '<base href='
cat build/web/CNAME
```

Expected output:

```text
build/web/flutter_bootstrap.js exists
<base href="/">
ovaloasis.in
```

The browser should then request:

`https://www.ovaloasis.in/flutter_bootstrap.js`

and **not**:

`https://www.ovaloasis.in/PoultryInventory/flutter_bootstrap.js`

## GitHub Pages

In the repository settings:

1. Open **Settings → Pages**.
2. Set the source to **GitHub Actions**.
3. Configure the custom domain as `ovaloasis.in` (or the exact domain you have configured in DNS).
4. Enable HTTPS after DNS verification completes.

The app uses Flutter hash routes, so these URLs remain valid:

- `https://www.ovaloasis.in/#/privacy-policy`
- `https://www.ovaloasis.in/#/terms-and-conditions`
