import AudioCapture
import Foundation
import Transcription

/// Segment de deux secondes qui commence à `start` secondes du début du call.
func segment(
    _ speaker: Speaker,
    _ text: String,
    startingAt start: TimeInterval,
    isFinal: Bool = true
) -> TranscriptSegment {
    TranscriptSegment(speaker: speaker, text: text, isFinal: isFinal, start: start, end: start + 2)
}
