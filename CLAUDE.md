# CLAUDE.md

## safe_space is the source of truth

This iOS app is a client for the **safe_space** backend (`/Users/markgoh/Code/safe_space`).
Before building or changing any SafeSpace feature, read that repo's `CLAUDE.md` — it has the
schema rules, status flows, shared-table contracts, and two-Supabase-project setup that the
iOS code must follow. The backend defines what the API accepts; don't guess status values,
field names, or validation rules from the iOS side alone.

## Auto-filling creation forms from a project page

When a creation form (Daily Report / FPU, Toolbox Talk, Form Submission, etc.)
is launched from inside a project's detail view, it must arrive pre-filled
with that project — never make the user re-pick it from a list.

**Pattern** (see `DailyReportFormView` + `SafetyProjectDetailView`):
- The form takes an explicit `preselectedProjectNumber: String? = nil` init
  param and seeds its `@State` from it in a custom `init`. Do not rely solely
  on the module-wide `SafeSpaceModule.lastViewedProjectNumber` static — that
  hack only helps when the form is opened through the *global* "+" button and
  goes stale if the user visited another project first. Reading it as a
  last-resort fallback (when no explicit value was passed) is fine.
- The project detail view owns a `@State private var showNewX = false` and a
  `.sheet(isPresented:)` presenting the form with its own `projectNumber`
  passed straight in — not the global create-sheet in the module file.
- On successful submit, the form posts `.safeSpaceRecordCreated`; the detail
  view observes it via `.onReceive(NotificationCenter.default.publisher(for:))`
  and reloads, so the new record shows up without a manual pull-to-refresh.

Apply this same shape to any future "create X for this project" button
(Toolbox Talks, Form Submissions, etc.) rather than inventing a new mechanism
per form.
