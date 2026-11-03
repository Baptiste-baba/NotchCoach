/// Source de l'audio d'un call, canal par canal : la vraie capture (`LiveAudioSource`) ou un fichier rejoué
/// (`ReplayAudioSource`).
public protocol AudioSource: Actor {}
