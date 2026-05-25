import SwiftUI
import Supabase

// MARK: - Supabase client (shared singleton)

private func makeSupabaseURL() -> URL {
    guard
        let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
        !urlString.isEmpty,
        !urlString.contains("placeholder"),
        let url = URL(string: urlString)
    else {
        fatalError("""
            SUPABASE_URL is missing or still set to a placeholder.
            Copy Secrets.xcconfig.example → Secrets.xcconfig and fill in your real credentials.
            """)
    }
    return url
}

let supabase = SupabaseClient(
    supabaseURL: makeSupabaseURL(),
    supabaseKey: Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
)

// MARK: - App

@main
struct AaikyamPresetStudioApp: App {

    @State private var artistId: UUID? = nil

    var body: some Scene {
        WindowGroup {
            Group {
                if let id = artistId {
                    NavigationView {
                        PresetListView(
                            artistId: id,
                            service: PresetService(supabase: supabase)
                        )
                    }
                    .navigationViewStyle(.stack)
                } else {
                    LoginView(supabase: supabase) { id in
                        artistId = id
                    }
                }
            }
            .task {
                // Restore session if already authenticated
                // supabase.auth.currentSession is a synchronous computed property in SDK 2.x
                if let session = try? await supabase.auth.session {
                    artistId = session.user.id
                }
            }
        }
    }
}
