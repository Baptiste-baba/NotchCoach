/// Qui parle. La séparation des canaux fait office de diarisation : micro = moi, audio système = prospect.
public enum Speaker: Hashable, Sendable, CaseIterable {
    case me
    case prospect
}
