# Releasing

For maintainers. A release needs a Developer ID certificate, an App Store Connect API key and the update signing key.

1. Raise `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`, and add to `CHANGELOG.md`.
2. Run `scripts/release.sh` with these in the environment:

   | Name | What it is |
   | --- | --- |
   | `DEVELOPER_ID_IDENTITY` | Name or hash of the certificate in your keychain |
   | `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID`, `ASC_API_KEY_P8` | For notarizing. The last one is the key's contents |
   | `SPARKLE_ED_PRIVATE_KEY` | Signs updates and the feed |

   It builds, signs, notarizes and zips the app into `dist/`, then writes and signs `site/public/appcast.xml`.
3. Commit, then create a GitHub release named `v` plus the version, with the zip attached.
4. Push the site. Do this after the release exists, since the feed links to its download.
5. Update the version and checksum in [the Homebrew tap](https://github.com/Rad-Soft/homebrew-tap).

Never change the update signing key. Installed copies only trust the one in their own `Info.plist`.
