# CLAUDE.md : NotchCoach (nom de travail)

## Le projet

App macOS qui écoute un call commercial (Meet, Zoom, Teams, etc.), le transcrit en local et affiche dans la notch des suggestions de réponse courtes générées par Claude, au moment où le prospect finit de parler.

Usage personnel uniquement. Le LLM passe par le CLI `claude` (Claude Code) en mode headless, authentifié avec l'abonnement Claude Max de l'utilisateur. Aucune clé API, aucun appel direct à api.anthropic.com.

Objectif : une app de qualité production, utilisée au quotidien, simple et rapide. Pas un MVP jetable, pas d'overengineering non plus.

## Contrainte n°1 : la latence

Tout le design découle de ça. Une suggestion qui arrive 6 s après la question du prospect ne sert à rien.

Budget cible, de la fin de la phrase du prospect au premier mot affiché :

| Étape | Cible |
|---|---|
| Finalisation du segment STT | ≤ 500 ms |
| Détection de fin de prise de parole | ~700 ms de silence |
| Premier token Claude (process déjà chaud) | ≤ 1,5 s |
| **Total** | **≤ 3 s** |

Règles qui en découlent :
- Le process `claude` est lancé au début du call et reste vivant jusqu'à la fin. Jamais un process par suggestion.
- Les réponses Claude sont streamées et affichées token par token.
- Chaque étape est instrumentée avec des `os_signpost` pour mesurer le budget réel dans Instruments. Toute optimisation se justifie par une mesure, pas une intuition.

## Stack

- Swift 6, mode de concurrence strict activé
- SwiftUI pour les vues, AppKit pour la fenêtre de la notch (`NSPanel`)
- macOS 15 minimum, Apple Silicon uniquement
- Capture audio : ScreenCaptureKit (audio système) + AVAudioEngine (micro)
- Transcription : FluidAudio (Parakeet, tourne sur le Neural Engine), derrière un protocole pour pouvoir changer de moteur
- LLM : CLI `claude` en sous-processus, protocole `stream-json` en entrée et en sortie
- Tests : Swift Testing

Dépendances externes autorisées : FluidAudio. Toute nouvelle dépendance doit être validée avec moi avant d'être ajoutée.

## Architecture

```
Audio système ─┐                                      ┌─> NotchUI
               ├─> Transcription ─> Conversation ─> ClaudeSession
Micro ─────────┘     (par canal)    (buffer + trigger)
```

Chaque étape est un `actor`. Les étapes communiquent par `AsyncStream`. Seule la couche UI est sur le `@MainActor`.

### Modules (package Swift local `CoachKit`)

**AudioCapture**
- `SystemAudioCapture` : `SCStream` avec `capturesAudio = true` et `excludesCurrentProcessAudio = true`. C'est la voix du prospect.
- `MicCapture` : `AVAudioEngine`, c'est la voix de l'utilisateur.
- Les deux sorties sont rééchantillonnées en 16 kHz mono Float32 avant de sortir du module.
- La séparation des canaux fait office de diarisation : `.me` = micro, `.prospect` = audio système. Pas de modèle de diarisation.
- `LiveAudioSource` réunit les deux captures pendant un vrai call, `ReplayAudioSource` lit un fichier à leur place. Les deux suivent le protocole `AudioSource`.

**Transcription**
- Protocole `TranscriptionEngine` : prend un flux audio, émet des `TranscriptSegment`.
- `TranscriptSegment { speaker, text, isFinal, start, end }`
- Une instance du moteur par canal.
- Implémentation : `ParakeetEngine` (FluidAudio). Silero VAD repère la fin de chaque prise de parole, puis Parakeet Ultra (`AsrModelVersion.ultra`, 25 langues européennes) transcrit le segment d'un coup sur le Neural Engine : les segments sont émis finaux, par phrase entière. Seule exception : une prise de parole de plus de 30 s est coupée en morceaux, et chaque morceau coupé alors que la personne parle encore est émis avec `isFinal: false`. Parakeet EOU, le modèle de streaming de FluidAudio, est exclu car il ne gère que l'anglais.
- Les modèles (environ 630 Mo) sont téléchargés au premier lancement depuis Hugging Face dans `~/Library/Application Support/FluidAudio/Models/`, chargés une seule fois et partagés par les moteurs des deux canaux.

**Conversation**
- `TranscriptBuffer` : accumule les segments, y compris les morceaux non finaux d'un monologue, et fournit, à chaque déclenchement, uniquement les segments nouveaux depuis le dernier message envoyé, formatés pour le prompt. Un segment n'est jamais envoyé deux fois : la session `claude` restant la même pendant tout le call, son historique sert de mémoire de la conversation (environ 15 000 tokens par heure de call, sans doublons). Après un redémarrage du process `claude`, dont la conversation repart vide, le message suivant contient toute la transcription du call depuis son début.
- `TriggerDetector` : logique pure, sans I/O, entièrement testée. Déclenche dès qu'arrive un segment final (`isFinal: true`) de `.prospect`, si aucune suggestion n'a été émise depuis 5 s (cooldown, pour éviter le spam).
  - Pas d'attente supplémentaire après ce segment : les ~0,75 s de silence qu'attend déjà le VAD avant de clore une prise de parole font office de détection de fin de prise de parole. Ce seuil se règle en mesurant à l'étape 5.
  - Un morceau non final (monologue de plus de 30 s) ne déclenche pas, mais son texte est bien envoyé à Claude avec la suite.
- Chaque déclenchement porte un `requestId` croissant.

**ClaudeSession**
- Actor qui possède le process `claude` et ses pipes stdin/stdout.
- Lancé au démarrage du call avec : modèle Haiku, sortie et entrée `stream-json`, system prompt construit depuis le playbook, aucun outil autorisé, répertoire de travail dédié et vide.
- **Ne pas inventer de flags.** Vérifier les options exactes avec `claude --help` avant d'écrire le code de lancement, et documenter dans ce fichier les flags retenus.
- Les apps GUI n'héritent pas du PATH du shell : résoudre le chemin du binaire via `/bin/zsh -lc 'command -v claude'` au premier lancement, le mettre en cache, et permettre de le surcharger dans les réglages. On met en cache le chemin renvoyé (`~/.local/bin/claude`, un lien symbolique), jamais sa cible versionnée, qui change à chaque mise à jour du CLI.
- Parsing ligne par ligne du JSON en sortie. Une ligne invalide est loguée et ignorée, elle ne fait jamais planter la session.
- Si un nouveau trigger arrive pendant une génération, la réponse en cours est marquée obsolète via son `requestId` et n'est plus affichée. Elle est aussi interrompue, sinon le CLI la terminerait avant de traiter la nouvelle requête : `{"type":"control_request","request_id":…,"request":{"subtype":"interrupt"}}` sur stdin. C'est le protocole des SDK Claude, absent de `claude --help`, vérifié sur 2.1.310 : la réponse interrompue se termine par un `result` avec `is_error: true` et `terminal_reason: aborted_streaming`, et une interruption sans réponse en cours ne produit aucun `result`.
- Haiku produit parfois des blocs de réflexion (`thinking_delta`) avant le texte : ils ne sont jamais affichés, mais coûtent de la latence. `--effort low` est une piste à mesurer à l'étape 5.
- Si le process meurt : redémarrage automatique avec backoff, état visible dans l'UI (« Claude redémarre… »). Après 5 tentatives ratées, la notch affiche en rouge « Claude est indisponible », et la phrase suivante du prospect relance Claude avec toute la transcription du call.
- Protocole `LLMSession` pour pouvoir mocker en test.

**Prompting**
- `Playbook` : fichier Markdown éditable par l'utilisateur dans `~/Library/Application Support/NotchCoach/playbook.md` (offre, cible, pricing, objections fréquentes et réponses validées). Chargé dans le system prompt au lancement de la session : une modification compte à partir du call suivant. S'il n'existe pas, l'app le crée avec ces rubriques vides, sans aucun exemple : Claude pourrait citer un faux prix au prospect. Le menu « Modifier le playbook… » l'ouvre dans l'éditeur par défaut, et une alerte explique s'il n'a pas pu être créé. Inutilisable au démarrage d'un call (illisible, pas en UTF-8, plus de 50 000 caractères), il est ignoré : le call démarre sans playbook et la notch en donne la raison en rouge.
- Format de sortie imposé à Claude : 1 ou 2 suggestions maximum, 20 mots maximum chacune, phrases prêtes à être dites à l'oral, en français. Pas de préambule, pas d'explication.
- Si rien d'utile à suggérer, Claude répond un token vide convenu (`-`) et l'UI n'affiche rien.
- Les prompts vivent dans des fichiers dédiés, pas en dur dans la logique.

**Call**
- `CallPipeline` : relie, pendant un call, la source audio, la transcription des deux canaux, la conversation, le playbook et la session Claude, et publie ce que la notch affiche. La cible App ne fait que le démarrer, l'arrêter et afficher ce qu'il publie.
- Un call démarre et s'arrête depuis le menu (« Démarrer un call », « Arrêter le call »). En mode replay, il démarre au lancement de l'app, et « Démarrer un call » rejoue le fichier depuis le début. Il se termine une fois le fichier fini, la dernière réponse de Claude arrivée et la notch repliée, pour que la dernière suggestion ne soit pas perdue.
- Les modèles de transcription sont chargés au premier call, puis gardés en mémoire pour les suivants.

**NotchUI**
- `NSPanel` avec `.nonactivatingPanel` : il ne prend jamais le focus à l'app de visio.
- Niveau au-dessus de la barre de menus, `collectionBehavior` avec `.canJoinAllSpaces` et `.fullScreenAuxiliary`.
- **`sharingType = .none` obligatoire** : la fenêtre doit rester invisible pendant un partage d'écran. C'est un point non négociable, à couvrir par un test manuel dans la checklist de release.
- Le panel est toujours sur l'écran principal (`NSScreen.screens.first`, celui choisi comme principal dans Réglages > Moniteurs, et non `NSScreen.main` qui suit le focus) et le suit quand la configuration des écrans change.
- Position calculée depuis `NSScreen.safeAreaInsets` et `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`. Si l'écran principal a une notch, le panel s'intègre avec : même hauteur, il la prolonge de chaque côté. Sans notch (écran externe), fallback en pilule centrée en haut de l'écran.
- État replié : indicateur discret (écoute active, session Claude prête ou non). État déplié : suggestion en cours. Animation sobre, pas de clignotement.
- Une suggestion reste affichée jusqu'à ce que la suivante la remplace, et au plus 20 s après la fin de sa réponse : la notch se replie ensuite. Pendant qu'une nouvelle suggestion se prépare, l'ancienne reste affichée jusqu'au premier mot de la nouvelle. Si Claude répond `-` (rien à suggérer), l'ancienne reste, toujours dans sa limite de 20 s.
- Si Claude ne peut pas répondre (réseau coupé, limite d'usage de l'abonnement, erreur de l'API), un message court en rouge remplace la suggestion, avec la même limite de 20 s. Les erreurs du démarrage d'un call sont aussi affichées en rouge.
- L'app vit dans la barre de menus (`LSUIElement = YES`), pas d'icône dans le Dock.

## Confidentialité

- Aucun audio n'est écrit sur disque. Jamais.
- La transcription se fait en local, mais le texte de la conversation est envoyé à Anthropic par le CLI `claude` pour générer les suggestions. C'est le seul flux de données qui quitte la machine.
- Le prospect est informé en début de call qu'un assistant prend des notes (obligation d'information du RGPD).
- Les transcriptions restent en mémoire et sont effacées à la fin du call. Un export manuel pourra exister plus tard, désactivé par défaut. Ça vaut aussi pour le process `claude`, lancé sans persistance de session (voir Sécurité).
- Logs via `os.Logger`. Le contenu des transcriptions et des suggestions est toujours logué avec `privacy: .private`.

## Sécurité

Ce que dit le prospect arrive directement dans le prompt : c'est une entrée non fiable (risque d'injection de prompt). Le process `claude` doit donc être isolé de tout ce qui peut agir au-delà de la génération de texte.

**Isolation du process `claude`**
- Il ne charge rien de la config globale de l'utilisateur : ni serveurs MCP, ni plugins, ni hooks, ni `~/.claude/CLAUDE.md`.
- Ligne de commande retenue, vérifiée sur Claude Code 2.1.310 :
  `claude -p --input-format stream-json --output-format stream-json --verbose --include-partial-messages --model haiku --tools "" --strict-mcp-config --setting-sources "" --no-session-persistence --system-prompt <prompt>`
  - `--tools ""` : aucun outil intégré (l'événement `system/init` liste `tools: []`).
  - `--strict-mcp-config`, sans `--mcp-config` : aucun serveur MCP (`mcp_servers: []`).
  - `--setting-sources ""` : aucun réglage utilisateur, donc aucun plugin ni hook de l'utilisateur. Seuls les 3 plugins intégrés au CLI restent listés.
  - `--system-prompt` : remplace le prompt par défaut de Claude Code.
  - `--no-session-persistence` : rien n'est écrit dans `~/.claude/projects/` (vérifié).
  - `--verbose` est obligatoire avec `--output-format stream-json` en mode `-p`, et `--include-partial-messages` fournit le texte token par token (`stream_event` > `content_block_delta`).
- Le CLI réémet un `system/init` à chaque message reçu, pas seulement au lancement : il ne sert pas de signal « session prête ».
- Une réponse en échec arrive comme une ligne `result` avec `is_error: true` et `subtype: success` : seul `is_error` est fiable.
- `--bare` est exclu : il ne lit jamais l'OAuth ni le trousseau, donc il est incompatible avec l'abonnement Max.
- Jamais de `--dangerously-skip-permissions` ni de mode `bypassPermissions`.

**Lancement du sous-processus**
- `Process` avec un `executableURL` absolu et un tableau d'arguments. Jamais via un shell.
- Environnement construit explicitement avec le strict nécessaire, jamais hérité tel quel : `HOME`, `USER`, `PATH`, `LANG`. `USER` est indispensable : sans lui, le CLI ne trouve pas les identifiants du trousseau et répond « Not logged in ». `ANTHROPIC_API_KEY` n'est jamais transmis : sinon la session bascule sur la facturation API.
- Le contenu de la conversation passe uniquement par stdin, jamais en argument (visible avec `ps`).
- Le chemin du binaire résolu via le PATH est vérifié (chemin absolu, fichier exécutable) et affiché dans les réglages.
- Le process suit le cycle de vie de l'app : terminé à la fin du call et à la fermeture de l'app. Il ne doit pas survivre à un crash (stdin se ferme à la mort du parent : vérifier que `claude` se termine bien dans ce cas).

**Dépendances**
- FluidAudio est épinglée à la version exacte 0.18.0 (commit `e152879`), avec `traits: []` : transcription et détection de voix seulement, sans synthèse vocale ni diarisation. SwiftPM télécharge quand même le binaire précompilé `NemoTextProcessing` à la résolution, mais il n'est pas lié dans l'app.
- Les modèles viennent de `huggingface.co` (dépôts `FluidInference/…`), sur la branche `main` par défaut, qui peut changer : leur révision est figée sur un commit précis via `ModelRegistry.revisionOverrides`.

## Permissions et distribution

- Enregistrement de l'écran (requis pour l'audio système via ScreenCaptureKit) et micro. Écran d'onboarding qui explique et vérifie les deux.
- `NSMicrophoneUsageDescription` dans l'Info.plist.
- App non sandboxée (elle lance un sous-processus), hardened runtime avec l'entitlement d'entrée audio. Pas de Mac App Store.

## Structure du repo

```
NotchCoach/
├── NotchCoach.xcodeproj  # format Xcode 27 (project.xcproj), ne contient aucun réglage de build
├── Config/               # xcconfig (Base, Debug, Release) et entitlements : seule source des réglages de build
├── App/                  # cible app, mince : lifecycle, menu bar, injection des dépendances
├── CoachKit/             # package Swift local, toute la logique ; un seul produit `CoachKit` qui regroupe tous les modules
│   ├── Sources/
│   │   ├── AudioCapture/
│   │   ├── Transcription/
│   │   ├── Conversation/
│   │   ├── ClaudeSession/
│   │   ├── Prompting/
│   │   ├── Call/
│   │   └── NotchUI/
│   └── Tests/
└── Fixtures/             # fichiers audio de calls de test, et le script qui génère le call synthétique
```

La cible App ne contient pas de logique métier. Si un fichier de `App/` dépasse ~100 lignes, c'est probablement qu'il manque une abstraction dans `CoachKit`.

## Commandes

```bash
# Build (dans ./build, ignoré par git)
xcodebuild -project NotchCoach.xcodeproj -scheme NotchCoach -configuration Debug -derivedDataPath build build

# Tests du package
cd CoachKit && swift test

# Call synthétique pour le replay (voix françaises de macOS)
swift Fixtures/generate-call-objection-prix.swift

# Mode replay : rejoue un fichier audio à la place d'un vrai call
./build/Build/Products/Debug/NotchCoach.app/Contents/MacOS/NotchCoach --replay Fixtures/call-objection-prix.wav
```

Le mode replay est une fonctionnalité de premier ordre, pas un bonus : c'est le seul moyen de tester le pipeline complet et de mesurer la latence sans être réellement au téléphone. Il remplace la capture audio par la lecture d'un fichier (stéréo : canal gauche = moi, canal droit = prospect) à vitesse réelle.

## Façon de travailler

- **Développer par couches, jamais une fonctionnalité entière d'un coup.** Pour chaque fonctionnalité, dans cet ordre, une couche par échange :
  1. **Structure** : fichiers, dossiers, types vides. Le projet compile.
  2. **Modèles** : les types de données d'entrée et de sortie (`struct`, `enum`), sans logique.
  3. **Interfaces** : les protocoles et les signatures publiques des actors (l'équivalent des endpoints ici), avec des corps vides ou `fatalError("TODO")`. Le câblage entre modules est fait.
  4. **Logique métier** : l'implémentation, cas nominal uniquement.
  5. **Erreurs** : types d'erreur dédiés par module, cas limites, comportement en cas d'échec (process qui meurt, permission refusée, audio coupé).
  6. **Tests unitaires** : sur la logique et les cas d'erreur de la couche 5.

  À la fin de chaque couche : build vert, résumé court de ce qui a été fait, puis arrêt. J'ai validé avant que la couche suivante commence. Si une couche révèle un problème dans une précédente, le signaler plutôt que de corriger en silence.
- Après chaque modification : build, puis tests. Si ça ne compile pas, on corrige avant de continuer.
- Ne pas refactorer du code hors du périmètre de la tâche demandée. Proposer, ne pas faire.
- Pas d'abstraction spéculative. Un protocole existe seulement s'il a au moins deux implémentations (réelle + mock compte).
- Toute logique pure (trigger, buffer, parsing JSON, formatage du prompt) est testée. La capture audio et l'UI se testent via le mode replay et à la main.
- En cas de doute sur une API Apple ou sur un flag du CLI `claude`, le dire et vérifier, plutôt que de deviner.
- Commits petits et atomiques, messages en anglais au format conventional commits.

## Ordre de construction

1. Squelette : app menu bar, package `CoachKit`, panel vide positionné sur la notch avec `sharingType = .none`.
2. `ClaudeSession` seule, testée avec un prompt fixe : lancement, streaming, redémarrage.
3. Mode replay + transcription des deux canaux, affichée brute dans la notch.
4. `TriggerDetector` + `TranscriptBuffer`, testés unitairement.
5. Branchement complet et mesure de la latence de bout en bout.
6. Playbook, vraie capture audio (micro et audio système) avec le démarrage et l'arrêt d'un call, onboarding des permissions, finitions UI.

Ne pas passer à l'étape suivante tant que la précédente ne fonctionne pas en replay.
