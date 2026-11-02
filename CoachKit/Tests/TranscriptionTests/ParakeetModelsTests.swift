import FluidAudio
import Testing
@testable import Transcription

/// Traduction de l'avancement de FluidAudio, qui consacre la moitié de sa progression à la compilation.
struct ParakeetModelsTests {
    private func state(_ fraction: Double, _ phase: DownloadPhase) -> ModelLoadState {
        ParakeetModels.loadState(for: DownloadProgress(fractionCompleted: fraction, phase: phase))
    }

    @Test func downloadPercentageCoversOnlyTheDownload() {
        #expect(state(0.25, .downloading(completedFiles: 2, totalFiles: 8)) == .downloading(fraction: 0.5))
        #expect(state(0.1, .downloading(completedFiles: 0, totalFiles: 8)) == .downloading(fraction: 0.2))
    }

    @Test func finishedDownloadIsShownAsLoading() {
        // Modèles déjà sur le disque : FluidAudio annonce d'emblée un téléchargement terminé, à 50 %.
        #expect(state(0.5, .downloading(completedFiles: 8, totalFiles: 8)) == .loading)
    }

    @Test func listingAndCompilingAreShownAsLoading() {
        #expect(state(0, .listing) == .loading)
        #expect(state(0.75, .compiling(modelName: "Encoder")) == .loading)
    }

    @Test func outOfRangeFractionIsClamped() {
        #expect(state(-0.1, .downloading(completedFiles: 0, totalFiles: 8)) == .downloading(fraction: 0))
    }

    @Test func pinnedRevisionsAreFullCommitHashes() {
        for pin in [ModelPin.parakeetUltra, ModelPin.sileroVAD] {
            let isHexadecimal = pin.revision.allSatisfy { $0.isHexDigit }
            #expect(pin.revision.count == 40)
            #expect(isHexadecimal)
            #expect(pin.repository.hasPrefix("FluidInference/"))
        }
    }
}
