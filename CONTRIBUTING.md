# Contributing to Meterya App

Contributions are welcome. This repository covers the Flutter web interface, browser behavior, visualization, and German and English UI translations. For substantial changes, open a feature request before starting implementation so the approach can be discussed.

## Where to report issues

- [Meterya](https://github.com/roman-kiefer/meterya/issues/new/choose): installation, Compose, and cross-component issues.
- [Meterya API](https://github.com/roman-kiefer/meterya-api/issues/new/choose): backend, persistence, and the bundled Keycloak provider and theme.
- [Meterya App](https://github.com/roman-kiefer/meterya-app/issues/new/choose): web interface and browser behavior.

Search existing issues before opening a new one. If the responsible component is unclear, start in Meterya and link related component issues instead of copying the same report into several repositories.

Use the bug report or feature request form. Include the app image tag and, where possible, digest, or the source commit and Flutter version. Include the API version if relevant. The latest tag changes over time. Include the browser and version, operating system, screen size when relevant, and whether the app was built from source or deployed with Docker Compose.

Suspected vulnerabilities belong in the confidential process described in [SECURITY.md](SECURITY.md), not in public issues or pull requests.

## Protect private data

Use synthetic examples. Remove passwords, tokens, cookies, authorization headers, SMTP credentials, personal email addresses, household data, and identifying details from logs, screenshots, photos, and reproduction files. Do not attach configured `.env` files, rendered realm files, database dumps, or backups. Do not paste expanded `docker compose config` output.

## Development and validation

Fork the repository, create a focused branch from `main`, and read the README and any applicable `AGENTS.md` instructions. Keep unrelated formatting or refactoring out of the change.

Use a Flutter SDK compatible with `pubspec.yaml`; the release workflow records the SDK version used for publishing.

```sh
flutter pub get
flutter analyze
flutter test
flutter build web
```

For visible changes, check narrow and wide layouts, light and dark appearance, and keyboard interaction. Add focused tests when behavior changes and include screenshots where they help reviewers.

Maintain both `lib/l10n/app_de.arb` and `lib/l10n/app_en.arb` for new UI text. Keep placeholder names and ICU select keys consistent, run `flutter gen-l10n`, and do not commit generated localization files or build output. See the README for language behavior.

An end-to-end authentication check needs the API, Keycloak, and the same-origin proxy routes described in the README. Use a disposable deployment and synthetic household data.

## Pull requests

Write new repository text, issue descriptions, commit messages, and pull requests in English. Existing German and English product translations and website documentation remain maintained in both languages.

Explain what changes and why, link relevant issues, and list the checks performed and their results. State explicitly when checks were skipped. Update documentation when behavior or configuration changes. Flag compatibility changes, database effects, and operator actions needed for deployment.

Maintainers manage release tags and image publication. A contribution does not need to publish an image or create a release.

## Community and licensing

Follow the [Code of Conduct](CODE_OF_CONDUCT.md). Report conduct concerns confidentially to [conduct@meterya.com](mailto:conduct@meterya.com). Communicate respectfully and keep discussion focused on the work.

By contributing, you agree that your contribution may be distributed under the repository's [license](LICENSE). Preserve existing third-party license notices.
