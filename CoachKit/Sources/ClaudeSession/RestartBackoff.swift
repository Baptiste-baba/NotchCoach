/// Délais d'attente entre deux redémarrages du process après sa mort.
struct RestartBackoff {
    /// Délai avant la tentative numéro `attempt` (à partir de 1).
    func delay(forAttempt attempt: Int) -> Duration {
        fatalError("TODO")
    }
}
