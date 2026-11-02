import CoreGraphics
import Testing
@testable import NotchUI

/// Mesures relevées sur l'écran intégré d'un MacBook Pro 14" : notch de 185 × 32 pt, de x = 663,5 à 848,5.
private let builtInDisplay = ScreenMetrics(
    frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
    safeAreaTopInset: 32,
    auxiliaryTopLeftArea: CGRect(x: 0, y: 950, width: 663.5, height: 32),
    auxiliaryTopRightArea: CGRect(x: 848.5, y: 950, width: 663.5, height: 32)
)

/// Mesures relevées sur un écran externe sans notch, placé à droite de l'écran intégré.
private let externalDisplay = ScreenMetrics(
    frame: CGRect(x: 1512, y: 0, width: 3440, height: 1440),
    safeAreaTopInset: 0,
    auxiliaryTopLeftArea: nil,
    auxiliaryTopRightArea: nil
)

/// Variantes de l'écran intégré dont les mesures de notch sont incohérentes.
enum InconsistentNotch: CaseIterable, Sendable {
    case leftAreaOnly
    case rightAreaOnly
    case zeroHeight
    case overlappingAreas
    case touchingAreas

    var metrics: ScreenMetrics {
        var metrics = builtInDisplay
        switch self {
        case .leftAreaOnly:
            metrics.auxiliaryTopRightArea = nil
        case .rightAreaOnly:
            metrics.auxiliaryTopLeftArea = nil
        case .zeroHeight:
            metrics.safeAreaTopInset = 0
        case .overlappingAreas:
            metrics.auxiliaryTopRightArea = CGRect(x: 600, y: 950, width: 912, height: 32)
        case .touchingAreas:
            metrics.auxiliaryTopRightArea = CGRect(x: 663.5, y: 950, width: 848.5, height: 32)
        }
        return metrics
    }
}

struct NotchLayoutTests {
    let layout = NotchLayout()

    @Test func notchScreenExtendsNotchOnBothSides() {
        let placement = layout.placement(for: builtInDisplay)

        #expect(placement.style == .notch)
        #expect(placement.frame == CGRect(x: 651.5, y: 950, width: 209, height: 32))
    }

    @Test func notchPanelMatchesNotchWithoutExtension() {
        let placement = NotchLayout(notchSideExtension: 0).placement(for: builtInDisplay)

        #expect(placement.frame == CGRect(x: 663.5, y: 950, width: 185, height: 32))
    }

    @Test func screenWithoutNotchGetsCenteredPill() {
        let placement = layout.placement(for: externalDisplay)

        #expect(placement.style == .pill)
        #expect(placement.frame == CGRect(x: 3132, y: 1404, width: 200, height: 32))
    }

    @Test func pillUsesCustomSizeAndMargin() {
        let layout = NotchLayout(pillSize: CGSize(width: 100, height: 20), pillTopMargin: 10)

        let placement = layout.placement(for: externalDisplay)

        #expect(placement.frame == CGRect(x: 3182, y: 1410, width: 100, height: 20))
    }

    @Test(arguments: InconsistentNotch.allCases)
    func inconsistentNotchFallsBackToPill(_ notch: InconsistentNotch) {
        let placement = layout.placement(for: notch.metrics)

        #expect(placement.style == .pill)
        #expect(placement.frame == CGRect(x: 656, y: 946, width: 200, height: 32))
    }

    @Test func expandedNotchPanelCoversTheNotchAndHostsTextBelow() {
        let placement = layout.expandedPlacement(for: builtInDisplay, contentHeight: 80)

        #expect(placement.style == .notch)
        #expect(placement.frame == CGRect(x: 536, y: 870, width: 440, height: 112))
        #expect(placement.contentTopInset == 32)
    }

    @Test func expandedPanelGrowsDownwardWithItsTextAndKeepsItsWidth() {
        let short = layout.expandedPlacement(for: builtInDisplay, contentHeight: 80)
        let long = layout.expandedPlacement(for: builtInDisplay, contentHeight: 200)

        #expect(long.frame == CGRect(x: 536, y: 750, width: 440, height: 232))
        #expect(long.frame.maxY == short.frame.maxY)
        #expect(long.frame.width == short.frame.width)
    }

    @Test func expandedHeightIsRoundedUpToFitTheMeasuredText() {
        let placement = layout.expandedPlacement(for: builtInDisplay, contentHeight: 79.2)

        #expect(placement.frame.height == 112)
    }

    @Test func expandedPanelKeepsAtLeastOneLine() {
        let placement = layout.expandedPlacement(for: builtInDisplay, contentHeight: 10)

        #expect(placement.frame == CGRect(x: 536, y: 910, width: 440, height: 72))
    }

    @Test func expandedNotchPanelStopsAtAThirdOfTheScreen() {
        let placement = layout.expandedPlacement(for: builtInDisplay, contentHeight: 1000)

        // 982 / 3 = 327 pt, notch comprise.
        #expect(placement.frame == CGRect(x: 536, y: 655, width: 440, height: 327))
    }

    @Test func expandedNotchPanelIsNeverNarrowerThanTheCollapsedOne() {
        let layout = NotchLayout(expandedWidth: 100)

        let placement = layout.expandedPlacement(for: builtInDisplay, contentHeight: 60)

        #expect(layout.expandedWidth(for: builtInDisplay) == 209)
        #expect(placement.frame == CGRect(x: 651.5, y: 890, width: 209, height: 92))
    }

    @Test func expandedPillHasNoNotchInset() {
        let placement = layout.expandedPlacement(for: externalDisplay, contentHeight: 80)

        #expect(placement.style == .pill)
        #expect(placement.frame == CGRect(x: 3012, y: 1356, width: 440, height: 80))
        #expect(placement.contentTopInset == 0)
    }

    @Test func expandedPillStopsAtAThirdOfTheScreen() {
        let placement = layout.expandedPlacement(for: externalDisplay, contentHeight: 1000)

        // 1440 / 3 = 480 pt depuis le haut de l'écran, marge comprise.
        #expect(placement.frame == CGRect(x: 3012, y: 960, width: 440, height: 476))
    }

    @Test(arguments: InconsistentNotch.allCases)
    func inconsistentNotchExpandsAsPill(_ notch: InconsistentNotch) {
        let placement = layout.expandedPlacement(for: notch.metrics, contentHeight: 80)

        #expect(placement.style == .pill)
        #expect(placement.frame == CGRect(x: 536, y: 898, width: 440, height: 80))
    }
}
