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

// MARK: - Artist profile lookup
// sound_presets.artist_id is artist_profiles.id (NOT auth.uid()).
// RLS: artist_id = (select id from artist_profiles where user_id = auth.uid())
// We must look up artist_profiles.id after every auth event.

private struct ArtistProfileIDRow: Codable { var id: UUID }

func fetchArtistProfileId(for userId: UUID) async throws -> UUID {
    let rows: [ArtistProfileIDRow] = try await supabase
        .from("artist_profiles")
        .select("id")
        .eq("user_id", value: userId.uuidString)
        .limit(1)
        .execute()
        .value
    guard let row = rows.first else {
        throw NSError(
            domain: "Aaikyam",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey:
                "No artist profile found for this account. " +
                "Please complete your profile at aaikyam.com first."]
        )
    }
    return row.id
}

// MARK: - App

@main
struct AaikyamPresetStudioApp: App {

    @State private var artistId: UUID? = nil
    @State private var profileError: String? = nil

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
                guard let session = try? await supabase.auth.session else { return }
                if let id = try? await fetchArtistProfileId(for: session.user.id) {
                    artistId = id
                }
                // If profile lookup fails, user lands on LoginView where they'll see the error.
            }
        }
    }
}
