/// Transcription d'un canal avec FluidAudio : Silero VAD repère la fin de chaque prise de parole, puis
/// Parakeet Ultra transcrit le segment d'un coup sur le Neural Engine.
public actor ParakeetEngine: TranscriptionEngine {}
