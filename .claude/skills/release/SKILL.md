---
name: release
description: Build, notarize, and release a new version of MicOver app. Use when the user wants to create a new release or bump the version.
---

# Release Workflow

This skill handles the complete release process for MicOver macOS app.

## Prerequisites

- Ensure you are on the `main` branch with latest changes
- All changes should be committed and pushed
- Apple Developer credentials must be configured in `macOS/.env`

## Release Steps

### 1. Determine Version Number

Check the current version and recent tags:

```bash
git tag -l | sort -V | tail -5
grep -E "MARKETING_VERSION" macOS/macOS.xcodeproj/project.pbxproj | head -2
```

Ask the user what version to release if not specified. Follow semantic versioning (MAJOR.MINOR.PATCH).

### 2. Bump Version in Xcode Project

Update `MARKETING_VERSION` in `macOS/macOS.xcodeproj/project.pbxproj`. There are multiple occurrences - update all of them.

### 3. Commit Version Bump

```bash
git add -A && git commit -m "chore: bump version to X.Y.Z"
git push
```

### 4. Create Git Tag

Create an annotated tag with release notes:

```bash
git tag -a vX.Y.Z -m "$(cat <<'EOF'
vX.Y.Z

## New Features
- Feature 1
- Feature 2

## Improvements
- Improvement 1

## Bug Fixes
- Fix 1
EOF
)"
git push origin vX.Y.Z
```

### 5. Build and Notarize App

Run the notarization script from the macOS directory:

```bash
cd macOS && ./notarize.sh
```

This will:
- Archive the app with Release configuration
- Export with Developer ID signing
- Submit to Apple notarization service
- Staple the notarization ticket

### 6. Build DMG

After notarization completes, build the DMG:

```bash
./build-dmg.sh
```

The DMG will be created at `macOS/build/MicOver-X.Y.Z.dmg`

### 7. Create GitHub Release

Create a GitHub release and upload the DMG:

```bash
gh release create vX.Y.Z --title "vX.Y.Z" --notes "$(cat <<'EOF'
## New Features
- Feature 1

## Improvements
- Improvement 1

## Bug Fixes
- Fix 1
EOF
)"

gh release upload vX.Y.Z macOS/build/MicOver-X.Y.Z.dmg
```

### 8. Verify Release

```bash
gh release view vX.Y.Z
```

## Notes

- The notarization process may take several minutes
- If notarization fails, check Apple Developer account status and credentials in `.env`
- Always test the DMG by mounting it before announcing the release
