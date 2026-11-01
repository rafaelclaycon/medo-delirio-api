# AltStore PAL distribution

**Status: on hold (Nov 2026).** Nothing is on the server yet. [`source.json`](source.json) is a template with placeholders.

AltStore PAL is available in Brazil (iOS 26.5+, device physically in Brazil, Brazilian App Store account). Hosting is just static files over HTTPS: no Vapor code and no endpoints. nginx serves everything straight from disk.

## Where things live

- **Server folder:** `/var/www/altstore/`
- **Source URL:** `https://api.medodelirioios.club/altstore/source.json`
- **Add-source link:** `altstore-pal://source?url=https://api.medodelirioios.club/altstore/source.json`

```
/var/www/altstore/
├── source.json
├── icon.png              ← 1024×1024 app icon
└── adp/
    └── <version>/        ← ADP contents directly inside, untouched
        ├── manifest.json
        ├── (extensionless signature file)
        └── ...
```

## Checklist

### Apple / AltStore (manual, not started)

- [ ] Get the app approved for alternative distribution (notarization, marketplace eligibility)
- [ ] Get AltStore's marketplace token and add AltStore PAL as a marketplace in App Store Connect
- [ ] Create an ADP for the build and download it

### Server, one-time setup

- [ ] Create the folder and take ownership so FileZilla can write:
  ```bash
  sudo mkdir -p /var/www/altstore/adp
  sudo chown -R $USER:$USER /var/www/altstore
  ```
- [ ] Find the site config: `grep -rl "medodelirioios.club" /etc/nginx/`
- [ ] In the `server` block with `listen 443 ssl`, above the existing `location /`, add:
  ```nginx
  location /altstore/ {
      alias /var/www/altstore/;
      types {
          application/json json;
          image/png        png;
      }
      default_type application/octet-stream;
  }
  ```
  Keep the trailing `/` on both paths. `.ipa` files and the extensionless signature file get `application/octet-stream` via `default_type`.
- [ ] `sudo nginx -t`, then `sudo systemctl reload nginx`
- [ ] Upload `icon.png`

### source.json placeholders

- [ ] `marketplaceID`: App Store Connect → App Information → Apple ID
- [ ] `version`, `buildVersion`, `date`, `localizedDescription` (what's new)
- [ ] `downloadURL`: replace `MARKETING_VERSION` with the ADP folder name
- [ ] `size`: bytes of **one** `.ipa` from the ADP's `variant` folder, not the whole ADP
- [ ] Check `appPermissions` against the signed app. AltStore refuses the install on any mismatch. Unzip a variant `.ipa` and run:
  ```bash
  codesign -d --entitlements - Payload/*.app
  ```
  The template lists the app and widget entitlements plus `NSPhotoLibraryUsageDescription`, all taken from the iOS project.

## Per release

1. Build → App Store Connect → new ADP → download it.
2. Upload the ADP with FileZilla (SFTP, **Transfer type: Binary**) to `/var/www/altstore/adp/<version>/`. Never edit or regenerate `manifest.json`, because its hashes must stay identical.
3. Add a new entry at the **top** of `versions[]` in `source.json` (AltStore treats order as recency), then upload it.
4. Delete old ADP folders, keeping one or two. Each is about 900 MB and the Nanode has 25 GB.

## Verify

- `curl -I https://api.medodelirioios.club/altstore/source.json` returns `200` with `Content-Type: application/json` (`404` means a path/slash problem, `403` means permissions)
- The `manifest.json` URL is reachable and byte-identical to the download
- Add the source in AltStore PAL on an iPhone in Brazil and install

## Optional: listing on explore.alt.store

Add `"fediUsername"` to the source (it can't be changed later), then POST `{"source": "<source url>"}` to `https://api.altstore.io/federate`.

## References

- [AltStore: Make a Source](https://faq.altstore.io/developers/make-a-source)
- [AltStore PAL release notes](https://faq.altstore.io/release-notes/altstore-pal)
