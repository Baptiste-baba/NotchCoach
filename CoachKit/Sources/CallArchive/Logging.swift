import os

/// Journal du module, partagé par ses fichiers. Jamais le contenu d'un call : seulement le nom de son fichier et la
/// raison d'un échec.
let logger = Logger(subsystem: "io.github.baptiste-baba.NotchCoach", category: "CallArchive")
