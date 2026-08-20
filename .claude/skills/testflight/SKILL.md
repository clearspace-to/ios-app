---
name: testflight
description: Ship a new Clearspace Mobile build to TestFlight — bumps the build number, archives, signs, uploads to App Store Connect, and verifies Apple processed it. Use when asked to release, ship, publish, or upload a TestFlight build.
---

# TestFlight Release

Ships the current state of the repo to TestFlight for internal testers.

## Prerequisites (fail fast if missing)

- App Store Connect API key at `~/.appstoreconnect/private_keys/AuthKey_342DVT6RFF.p8`.
  If missing, ask the user to download it from App Store Connect → Users and Access →
  Integrations (key ID `342DVT6RFF`) and place it there. Never commit the .p8.
- Xcode with the iOS platform installed (`xcodebuild -showsdks` lists an iOS SDK).
- `xcodegen` on PATH (`brew install xcodegen`).
- Working tree should be on the code you intend to ship; warn if there are
  uncommitted changes unrelated to the release.

## Steps

1. Run the release script (from the repo root):

   ```
   ./.claude/skills/testflight/release.sh
   ```

   It bumps `CURRENT_PROJECT_VERSION` in `project.yml`, regenerates the Xcode
   project, archives unsigned, exports with cloud-managed App Store distribution
   signing via the API key, and uploads with `altool`. Takes a few minutes; run
   it in the background and read the output when it exits.

2. If upload succeeds, commit the build-number bump (project.yml and the
   regenerated ClearspaceMobile.xcodeproj) with a message like
   `Bump build number to N for TestFlight`.

3. Poll until Apple finishes processing (usually 5–15 min):

   ```
   python3 ./.claude/skills/testflight/check_build.py
   ```

   Done when the newest build shows `VALID`. Internal testers in the
   "Internal Testers" group get it automatically — no review, no manual step.

4. Report the shipped build number and processing state to the user.

## Known failure modes

- **"Your team has no devices" during archive** — something reverted to signed
  archiving. Archive must run with `CODE_SIGNING_ALLOWED=NO`; distribution
  signing happens only at export (the team has no registered devices, so
  automatic *development* signing can never work).
- **altool error 90474 (orientations)** — `UISupportedInterfaceOrientations`
  must live in the Info.plist `properties` in project.yml; `INFOPLIST_KEY_*`
  build settings are ignored because the target uses a custom Info.plist.
- **altool "bundle version must be higher"** — build number already used;
  the script bumps it, so this usually means a previous run bumped without
  committing. Re-run the script.
- **Xcode dies at launch with `Symbol not found ... CoreDevice`** — stale
  support frameworks after an Xcode update. Fix:
  `sudo xcodebuild -runFirstLaunch` (user must run it, needs password).

## Facts

- App Store Connect app: "Clearspace Mobile", Apple ID 6803644015,
  bundle ID `to.clearspace.mobile`, team `W4Y8D5GH62`.
- API key ID `342DVT6RFF`, issuer `48a9d8c2-81f0-43e1-a7cb-10a8c146a5ae`
  (ids are not secrets; the .p8 file is).
- Internal tester group: "Internal Testers" (has access to all builds).
