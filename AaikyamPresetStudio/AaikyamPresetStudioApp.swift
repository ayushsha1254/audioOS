import SwiftUI
import Supabase

// MARK: - Supabase client (shared singleton)

let supabase = SupabaseClient(
    supabaseURL: URL(string: Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "")!,
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
                    artistId = UUID(uuidString: session.user.id.uuidString)
                }
            }
        }
    }
}
