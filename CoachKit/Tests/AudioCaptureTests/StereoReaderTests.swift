import AVFoundation
import Testing
@testable import AudioCapture

struct StereoReaderTests {
    @Test func readingToTheEndOfTheFileIsNotAFailure() throws {
        let files = try TemporaryAudioFiles()
        // Une longueur qui n'est pas un multiple du bloc : le dernier bloc est plus court.
        let url = try files.wav(frameCount: 10_000, channelValues: [0.25, -0.5])
        let reader = try #require(StereoReader(file: AVAudioFile(forReading: url), frameCount: 4096))

        var frameCount = 0
        while let block = reader.next() {
            frameCount += block.left.count
        }

        #expect(frameCount == 10_000)
        #expect(reader.readFailure == nil)
    }
}
