# Repository Guidelines

## Project Structure & Module Organization

This repository contains a small macOS SwiftUI app, `RemoteDock`.

- `remoteDock/`: application source code
- `remoteDock/Models/`: data models such as `RemoteHost` and `HostStatus`
- `remoteDock/Services/`: system-facing logic such as clipboard, ping, config storage, and Ghostty SSH launch
- `remoteDock/Views/`: reusable SwiftUI views such as `HostCard` and `HostEditorView`
- `remoteDock/Assets.xcassets/`: app icons and color assets
- `remoteDock.xcodeproj/`: Xcode project
- `README.md`, `TODO.md`: user-facing project notes and roadmap

Keep UI state in SwiftUI views, and move reusable non-UI logic into `Services` or `Models`.

## Build, Test, and Development Commands

- `open remoteDock.xcodeproj`: open the project in Xcode
- `xcodebuild -project remoteDock.xcodeproj -scheme remoteDock -destination 'platform=macOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build`: build from the command line
- `open .DerivedData/Build/Products/Debug/remoteDock.app`: launch the built app

Run with `My Mac` in Xcode for normal development. Command-line builds are useful for quick verification before committing.

## Coding Style & Naming Conventions

Use Swift conventions already present in the repo:

- 4-space indentation
- `UpperCamelCase` for types: `RemoteHost`, `HostStore`
- `lowerCamelCase` for properties and methods: `openSSHSession`, `configFileURL`
- One primary type per file when practical

Prefer small SwiftUI views and focused service types. Keep comments sparse and only where behavior is non-obvious.

## Testing Guidelines

There is currently no test target. When adding tests, create a dedicated test target and place tests by feature area, mirroring `Models` and `Services`.

Recommended naming:

- `RemoteHostTests`
- `HostStoreTests`
- `PingServiceTests`

Focus first on pure Swift logic such as JSON persistence, command generation, and error handling.

## Commit & Pull Request Guidelines

Recent history uses short, imperative commit subjects, often with Conventional Commit prefixes:

- `feat: stabilize Ghostty SSH launch workflow`
- `docs: add project README and TODO`

Prefer:

- `feat: ...` for features
- `fix: ...` for bug fixes
- `docs: ...` for documentation

Pull requests should include a short summary, affected files or behavior, manual verification steps, and screenshots for UI changes.

## Security & Configuration Notes

Host data is stored in `~/Library/Application Support/RemoteDock/hosts.json`. Do not commit personal IPs, usernames, or private machine details unless intentionally using local sample data.
