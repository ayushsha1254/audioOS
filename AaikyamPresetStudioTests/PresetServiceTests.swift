// The 7 mock-based tests below verify that the PresetRepository contract
// behaves correctly (filtering, upsert semantics, error propagation). This is
// useful for the ViewModel layer, which depends only on the protocol, not the
// concrete implementation.
//
// The smoke test at the bottom ("test_presetService_conformsToRepository")
// verifies that PresetService itself satisfies PresetRepository at compile time
// and can be constructed without crashing — without making live network calls.

import XCTest
import Supabase
@testable import AaikyamPresetStudio

// MARK: - Mock

final class MockPresetRepository: PresetRepository {
    var savedPresets: [PresetModel] = []
    var shouldThrow = false

    func loadAll(artistId: UUID) async throws -> [PresetModel] {
        if shouldThrow { throw URLError(.notConnectedToInternet) }
        return savedPresets.filter { $0.artistId == artistId }
    }

    func save(_ preset: PresetModel) async throws -> PresetModel {
        if shouldThrow { throw URLError(.notConnectedToInternet) }
        savedPresets.removeAll { $0.id == preset.id }
        savedPresets.append(preset)
        return preset
    }

    func delete(id: UUID) async throws {
        if shouldThrow { throw URLError(.notConnectedToInternet) }
        savedPresets.removeAll { $0.id == id }
    }
}

// MARK: - Tests

final class PresetServiceTests: XCTestCase {

    var mock: MockPresetRepository!
    let artistId = UUID()

    override func setUp() {
        super.setUp()
        mock = MockPresetRepository()
    }

    func test_save_storesPreset() async throws {
        var preset = PresetModel.cafeSet
        preset = PresetModel(id: preset.id, name: preset.name, artistId: artistId,
                             parameters: preset.parameters, voiceType: preset.voiceType)
        let saved = try await mock.save(preset)
        XCTAssertEqual(saved.id, preset.id)
        XCTAssertEqual(mock.savedPresets.count, 1)
    }

    func test_loadAll_returnsOnlyArtistPresets() async throws {
        let otherId = UUID()
        let p1 = PresetModel(id: UUID(), name: "A", artistId: artistId,  parameters: PresetParameters())
        let p2 = PresetModel(id: UUID(), name: "B", artistId: artistId,  parameters: PresetParameters())
        let p3 = PresetModel(id: UUID(), name: "C", artistId: otherId,   parameters: PresetParameters())
        _ = try await mock.save(p1)
        _ = try await mock.save(p2)
        _ = try await mock.save(p3)

        let results = try await mock.loadAll(artistId: artistId)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.artistId == artistId })
    }

    func test_save_upserts_existingPreset() async throws {
        var preset = PresetModel(id: UUID(), name: "Original", artistId: artistId, parameters: PresetParameters())
        _ = try await mock.save(preset)

        preset = PresetModel(id: preset.id, name: "Updated", artistId: artistId, parameters: PresetParameters())
        _ = try await mock.save(preset)

        XCTAssertEqual(mock.savedPresets.count, 1)
        XCTAssertEqual(mock.savedPresets.first?.name, "Updated")
    }

    func test_delete_removesPreset() async throws {
        let preset = PresetModel(id: UUID(), name: "ToDelete", artistId: artistId, parameters: PresetParameters())
        _ = try await mock.save(preset)
        XCTAssertEqual(mock.savedPresets.count, 1)

        try await mock.delete(id: preset.id)
        XCTAssertEqual(mock.savedPresets.count, 0)
    }

    func test_save_whenThrows_propagatesError() async {
        mock.shouldThrow = true
        let preset = PresetModel(id: UUID(), name: "Fail", artistId: artistId, parameters: PresetParameters())
        do {
            _ = try await mock.save(preset)
            XCTFail("Expected throw")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }

    func test_loadAll_whenThrows_propagatesError() async {
        mock.shouldThrow = true
        do {
            _ = try await mock.loadAll(artistId: artistId)
            XCTFail("Expected throw")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }

    func test_delete_whenThrows_propagatesError() async {
        mock.shouldThrow = true
        do {
            try await mock.delete(id: UUID())
            XCTFail("Expected throw")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }

    // MARK: - PresetService conformance smoke test

    /// Verifies that PresetService satisfies the PresetRepository protocol at
    /// compile time and can be constructed without crashing. No live network
    /// calls are made; the placeholder credentials are intentionally invalid.
    func test_presetService_conformsToRepository() {
        let client = SupabaseClient(
            supabaseURL: URL(string: "https://test.supabase.co")!,
            supabaseKey: "dummy-anon-key-for-compile-time-check"
        )
        let service = PresetService(supabase: client)
        // Assign to protocol type to confirm conformance at compile time.
        let _: PresetRepository = service
        XCTAssertTrue(true, "PresetService constructs and conforms to PresetRepository")
    }
}
