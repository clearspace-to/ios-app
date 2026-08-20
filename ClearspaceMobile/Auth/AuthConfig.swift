import Foundation

/// The shared Clearspace auth project (auth.clearspace.to) — one Microsoft SSO
/// login for every Clearspace app. sales_space moved onto it in
/// "split-auth-to-master-supabase"; safe_space, SLT/VLT, ClearCare and clear_view
/// were already here. One sign-in covers every module in this app.
///
/// `anonKey` is Supabase's *publishable* anon key (safe to ship in the app binary).
enum AuthConfig {
    static let supabaseURL = URL(string: "https://lwerfpaarwndjgovyykl.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx3ZXJmcGFhcnduZGpnb3Z5eWtsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMzI4ODEsImV4cCI6MjA3MzYwODg4MX0.hgw7iJoA80KG9nkUnzHN3mKPDgziDic6l9gvxYrZ8Pk"
    static let callbackScheme = "clearspacemobile"
    static let redirectURI = "clearspacemobile://auth-callback"
}
