import SwiftUI
import Supabase

struct PresetListView: View {
    @StateObject private var vm: PresetListViewModel
    @State private var selectedPreset: PresetModel? = nil
    @State private var showStudio = false

    private let artistId: UUID
    private let service:  PresetRepository

    init(artistId: UUID, service: PresetRepository) {
        self.artistId = artistId
        self.service  = service
        _vm = StateObject(wrappedValue: PresetListViewModel(artistId: artistId, service: service))
    }

    var body: some View {
        ZStack {
            Color.warmBackground.ignoresSafeArea()

            if vm.isLoading {
                ProgressView()
                    .tint(.warmAccent)
            } else if vm.presets.isEmpty {
                emptyState
            } else {
                presetList
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("My Presets")
                    .font(.custom("Syne-Bold", size: 20))
                    .foregroundColor(.warmPrimaryText)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { selectedPreset = nil; showStudio = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New")
                    }
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(.warmAccent)
                }
            }
        }
        .task { await vm.loadPresets() }
        .sheet(isPresented: $showStudio, onDismiss: {
            Task { await vm.loadPresets() }
        }) {
            NavigationView {
                PresetStudioView(
                    preset:    selectedPreset,
                    artistId:  artistId,
                    service:   service
                )
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.error ?? "")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🎙")
                .font(.system(size: 64))
            Text("No presets yet")
                .font(.custom("Syne-Bold", size: 22))
                .foregroundColor(.warmPrimaryText)
            Text("Record your voice and\ndial in your sound.")
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundColor(.warmSecondaryText)
                .multilineTextAlignment(.center)
            Button(action: { selectedPreset = nil; showStudio = true }) {
                Text("Create Your First Preset")
                    .font(.custom("Syne-Bold", size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.warmPrimaryText)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Preset List

    private var presetList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.presets) { preset in
                    presetCard(preset)
                }
                Button(action: { selectedPreset = nil; showStudio = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.warmSecondaryText)
                        Text("Create New Preset")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.warmSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.warmCard)
                    .cornerRadius(14)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .refreshable { await vm.loadPresets() }
    }

    // MARK: - Preset Card

    private func presetCard(_ preset: PresetModel) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.custom("Syne-Bold", size: 17))
                    .foregroundColor(.warmPrimaryText)

                HStack(spacing: 6) {
                    if let vt = preset.voiceType {
                        Text(vt)
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(.warmSecondaryText)
                    }
                    if let updatedAt = preset.updatedAt {
                        Text("·").foregroundColor(.warmSecondaryText)
                        Text(updatedAt, style: .relative)
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(.warmSecondaryText)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.warmSecondaryText)
        }
        .padding(16)
        .background(Color.warmCard)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedPreset = preset
            showStudio = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await vm.delete(id: preset.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        PresetListView(
            artistId: UUID(),
            service: PreviewPresetListService()
        )
    }
}

private final class PreviewPresetListService: PresetRepository {
    func loadAll(artistId: UUID) async throws -> [PresetModel] {
        [.cafeSet, .raw, .bigRoom]
    }
    func save(_ p: PresetModel) async throws -> PresetModel { p }
    func delete(id: UUID) async throws { }
}
