# Clearspace Mobile (iOS)

Native SwiftUI app giving the team mobile access to Clearspace internal tools.
Two app modules so far: **sales_space** (CRM) and **safe_space** (site safety).
Android will be a separate Kotlin app later.

## Requirements
- Xcode 15+ (Mac App Store)
- XcodeGen (`brew install xcodegen`)

## Getting started
```bash
xcodegen            # generates ClearspaceMobile.xcodeproj from project.yml
open ClearspaceMobile.xcodeproj
```
Then pick an iPhone simulator and press Run. The `.xcodeproj` is generated —
edit `project.yml`, not the project file.

## Tests
UI tests drive the real app in the simulator (taps, navigation, scrolling):
```bash
xcodebuild -project ClearspaceMobile.xcodeproj -scheme ClearspaceMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Launch arguments used by tests and screenshots:
`-preview` (skip login, sample data), `-app=<module id>`, `-screen=<destination id>`,
`-drawer`, `-palette`.

## Structure
```
ClearspaceMobile/
├── App/          entry, login, AppShell, app registry, settings
├── Kit/          shared UI: lists, rows, badges, charts, drawer,
│                 command palette, liquid-glass bottom bar, AppModule
├── Auth/         Supabase GoTrue PKCE + Keychain session
├── Networking/   bearer-authed JSON client
├── Apps/
│   ├── SalesSpace/   models, service, screens, module
│   └── SafeSpace/    models, service, screens, module
└── Theme/
```

`AppShell` hosts whichever `AppModule` is selected and owns all the chrome
(drawer, bottom bar, command palette, create sheet). It knows nothing about any
specific product.

## Adding an app

1. `Apps/<Name>/` — models, a `<Name>Service` protocol, a mock implementation,
   and screens assembled from `Kit/` components.
2. `<Name>Module.swift` — one `AppModule` value: nav groups, default screen,
   create actions, search groups, and closures mapping a destination id to a
   screen and a `DetailRoute` to a detail view.
3. Register it in `App/ClearspaceApps.swift`.

No shell changes. Detail navigation goes through the shared `DetailRoute`, so
there is one `navigationDestination` for the whole app.

## Auth

One Microsoft SSO login covers every module: the shared Clearspace auth project
`lwerfpaarwndjgovyykl` (auth.clearspace.to). sales_space moved onto it in
"split-auth-to-master-supabase"; the other apps were already there. Configured in
`ClearspaceMobile/Auth/AuthConfig.swift`; the app's callback
(`clearspacemobile://auth-callback`) is allowlisted on that project.

## Backend status

- **safe_space** — **live** against `https://safe.clearspace.to`. It already
  accepted bearer tokens and gates on `auth_app_access`, so no backend work was
  needed. Signed-in users see real data; access is denied with the API's own
  message if their account lacks the `safe_space` grant.
- **sales_space** — still sample data. Needs a bearer-auth path on `/api/v1`
  before it can serve live data (see the plan file).

Signing in with "Explore with sample data" (or any run with `-preview`) forces
every module onto mock data, which is what the tests use.

### Wire-format tests

`ClearspaceMobileTests/SafeSpaceDecodingTests.swift` decodes fixtures shaped like
safe_space's real responses. If the API contract changes, these fail before
anything reaches a phone. Notable rules they lock in:

- Calendar dates (`report_date`, `talk_date`) are parsed **and** rendered in UTC —
  rendering them locally shifts them a day back west of UTC.
- A submission's `data` is decoded **without** snake_case conversion, because its
  keys are the form's own field keys.
- Unknown status values fall back rather than failing the screen.
