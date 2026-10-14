# Meterya App

Meterya App is the Flutter web interface for household energy data. It uses the Meterya API for calculations and storage and Keycloak for sign-in. The browser communicates with all three services through one HTTPS origin.

## Features

- Workspaces, members, roles, and metering points
- Readings, tariffs, consumption, cost views, and monthly billing
- Reading photos, virtual meters, meter transitions, and heat pump views
- Audit history, reports, and operator backup and restore
- Responsive layout with system, light, and dark appearance modes

## Release image

The [release workflow](.github/workflows/release.yml) runs Flutter analysis, tests, and a web build for pull requests and commits on `main`. A version tag such as `v1.0.0` also publishes the static web image for `linux/amd64` and `linux/arm64`:

```text
ghcr.io/<owner>/meterya-app:v1.0.0
```

Replace `<owner>` with the lowercase GitHub repository owner. The image serves the built app on port `8080`; it contains no API credentials. The first release uses version `1.0.0+1` in `pubspec.yaml`.

## Use with Docker Compose

The complete deployment Compose file will live in the proxy repository. It can reference the app image as a private service:

```yaml
services:
  web:
    image: ghcr.io/<owner>/meterya-app:v1.0.0
    restart: unless-stopped
```

The HTTPS proxy should send `/api/*`, `/auth/*`, and `/health/*` to the API, `/identity/*` to Keycloak, and other paths to `web:8080`. The web image serves Flutter routes such as `/profile` and `/invitations/accept` through its `index.html` fallback. Keep the browser, API, and Keycloak on the same public HTTPS origin so server-side authentication cookies work. Do not expose the web container directly to the internet.

Authenticate Docker on the deployment host before pulling the private image; the GitHub credential needs `read:packages` access. The proxy repository will document the full Compose startup and configuration.

## Development checks

Use a Flutter SDK compatible with the Dart constraint in `pubspec.yaml`. The release workflow uses Flutter `3.47.4`.

```sh
flutter pub get
flutter analyze
flutter test
flutter build web
```

The compiled files are in `build/web/`. They are generated and are not committed. The app uses relative API paths and needs the proxy routes above for an end-to-end sign-in flow.

The source code is licensed under [AGPL-3.0-only](LICENSE). The SVG logo and favicon contain CC BY-SA 4.0 license metadata. Copyright © 2026 Meterya contributors.
