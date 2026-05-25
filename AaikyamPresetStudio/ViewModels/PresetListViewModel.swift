import Foundation

@MainActor
final class PresetListViewModel: ObservableObject {

    @Published var presets:   [PresetModel] = []
    @Published var isLoading: Bool = false
    @Published var error:     String?

    private let service:   PresetRepository
    private let artistId:  UUID

    init(artistId: UUID, service: PresetRepository) {
        self.artistId = artistId
        self.service  = service
    }

    func loadPresets() async {
        isLoading = true
        error = nil
        do {
            presets = try await service.loadAll(artistId: artistId)
        } catch {
            self.error = "Couldn't load presets: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func delete(id: UUID) async {
        do {
            try await service.delete(id: id)
            presets.removeAll { $0.id == id }
        } catch {
            self.error = "Delete failed: \(error.localizedDescription)"
        }
    }
}
