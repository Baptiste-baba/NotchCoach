/// Délais d'attente entre deux redémarrages du process après sa mort : doublés à chaque tentative, plafonnés.
struct RestartBackoff {
    var initialDelay: Duration = .milliseconds(500)
    var maximumDelay: Duration = .seconds(8)
    /// Au-delà, la session abandonne et passe à l'état `failed`.
    var maximumAttempts = 5

    /// Délai avant la tentative numéro `attempt` (à partir de 1) : 0,5 s, 1 s, 2 s, 4 s, 8 s, 8 s…
    func delay(forAttempt attempt: Int) -> Duration {
        let exponent = min(max(attempt - 1, 0), 30)
        return min(initialDelay * (1 << exponent), maximumDelay)
    }
}
