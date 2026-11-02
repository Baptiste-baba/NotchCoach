/// Avancement de la préparation des modèles, affichable dans l'UI : le premier lancement télécharge environ 630 Mo.
/// Les modèles sont prêts quand le flux renvoyé par `ParakeetModels.prepare()` se termine.
public enum ModelLoadState: Equatable, Sendable {
    /// Téléchargement depuis Hugging Face, `fraction` entre 0 et 1.
    case downloading(fraction: Double)
    /// Modèles présents sur le disque, chargement par Core ML.
    case loading
}
