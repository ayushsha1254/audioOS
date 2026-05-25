import Foundation
import Supabase

// MARK: - Repository Protocol (enables mocking in tests)

protocol PresetRepository {
    func loadAll(artistId: UUID) async throws -> [PresetModel]
    func save(_ preset: PresetModel) async throws -> PresetModel
    func delete(id: UUID) async throws
}

// MARK: - Live Supabase implementation

final class PresetService: PresetRepository {

    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    /// Fetch all presets for an artist, ordered newest-first.
    func loadAll(artistId: UUID) async throws -> [PresetModel] {
        try await supabase
            .from("sound_presets")
            .select()
            .eq("artist_id", value: artistId.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    /// Upsert a preset (insert or replace by id). Returns the persisted row.
    func save(_ preset: PresetModel) async throws -> PresetModel {
        try await supabase
            .from("sound_presets")
            .upsert(preset)
            .select()
            .single()
            .execute()
            .value
    }

    /// Delete a preset by id.
    func delete(id: UUID) async throws {
        try await supabase
            .from("sound_presets")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
