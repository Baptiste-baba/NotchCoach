import os

/// Journal et repères de mesure du module, partagés par ses fichiers.
let logger = Logger(subsystem: "io.github.baptiste-baba.NotchCoach", category: "ClaudeSession")
let signposter = OSSignposter(subsystem: "io.github.baptiste-baba.NotchCoach", category: "ClaudeSession")
