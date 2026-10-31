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

**Transcription**
- Protocole `TranscriptionEngine` : prend un flux audio, émet des `TranscriptSegment`.
- `TranscriptSegment { speaker, text, isFinal, start, end }`
- Une instance du moteur par canal.
- Implémentation : `ParakeetEngine` (FluidAudio).

**Conversation**
- `TranscriptBuffer` : fenêtre glissante des derniers échanges (environ 3 minutes ou N tokens, la valeur la plus petite), formatée pour le prompt.
- `TriggerDetector` : logique pure, sans I/O, entièrement testée. Déclenche quand :
  - le dernier segment final vient de `.prospect`,
  - suivi de ~700 ms sans nouveau segment prospect,
  - et qu'aucune suggestion n'a été émise depuis X secondes (cooldown, pour éviter le spam).
- Chaque déclenchement porte un `requestId` croissant.

**ClaudeSession**
- Actor qui possède le process `claude` et ses pipes stdin/stdout.
- Lancé au démarrage du call avec : modèle Haiku, sortie et entrée `stream-json`, system prompt construit depuis le playbook, aucun outil autorisé, répertoire de travail dédié et vide.
- **Ne pas inventer de flags.** Vérifier les options exactes avec `claude --help` avant d'écrire le code de lancement, et documenter dans ce fichier les flags retenus.
- Les apps GUI n'héritent pas du PATH du shell : résoudre le chemin du binaire via `/bin/zsh -lc 'command -v claude'` au premier lancement, le mettre en cache, et permettre de le surcharger dans les réglages.
- Parsing ligne par ligne du JSON en sortie. Une ligne invalide est loguée et ignorée, elle ne fait jamais planter la session.
- Si un nouveau trigger arrive pendant une génération, la réponse en cours est marquée obsolète via son `requestId` et n'est plus affichée.
- Si le process meurt : redémarrage automatique avec backoff, état visible dans l'UI.
- Protocole `LLMSession` pour pouvoir mocker en test.

**Prompting**
- `Playbook` : fichier Markdown éditable par l'utilisateur dans `~/Library/Application Support/NotchCoach/playbook.md` (offre, cible, pricing, objections fréquentes et réponses validées). Chargé dans le system prompt au lancement de la session.
- Format de sortie imposé à Claude : 1 ou 2 suggestions maximum, 20 mots maximum chacune, phrases prêtes à être dites à l'oral, en français. Pas de préambule, pas d'explication.
- Si rien d'utile à suggérer, Claude répond un token vide convenu (`-`) et l'UI n'affiche rien.
- Les prompts vivent dans des fichiers dédiés, pas en dur dans la logique.

**NotchUI**
- `NSPanel` avec `.nonactivatingPanel` : il ne prend jamais le focus à l'app de visio.
- Niveau au-dessus de la barre de menus, `collectionBehavior` avec `.canJoinAllSpaces` et `.fullScreenAuxiliary`.
- **`sharingType = .none` obligatoire** : la fenêtre doit rester invisible pendant un partage d'écran. C'est un point non négociable, à couvrir par un test manuel dans la checklist de release.
- Le panel est toujours sur l'écran principal (`NSScreen.screens.first`, celui choisi comme principal dans Réglages > Moniteurs, et non `NSScreen.main` qui suit le focus) et le suit quand la configuration des écrans change.
- Position calculée depuis `NSScreen.safeAreaInsets` et `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`. Si l'écran principal a une notch, le panel s'intègre avec : même hauteur, il la prolonge de chaque côté. Sans notch (écran externe), fallback en pilule centrée en haut de l'écran.
- État replié : indicateur discret (écoute active, session Claude prête ou non). État déplié : suggestion en cours. Animation sobre, pas de clignotement.
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
- Flags retenus, présents dans `claude --help`. Un test doit vérifier que plugins et hooks sont réellement coupés :
  - `--tools ""` : aucun outil intégré.
  - `--strict-mcp-config`, sans `--mcp-config` : aucun serveur MCP.
  - `--setting-sources` restreint : les réglages utilisateur ne sont pas chargés.
  - `--system-prompt` : remplace le prompt par défaut de Claude Code.
  - `--no-session-persistence` : rien n'est écrit dans `~/.claude/projects/`.
- `--bare` est exclu : il ne lit jamais l'OAuth ni le trousseau, donc il est incompatible avec l'abonnement Max.
- Jamais de `--dangerously-skip-permissions` ni de mode `bypassPermissions`.

**Lancement du sous-processus**
- `Process` avec un `executableURL` absolu et un tableau d'arguments. Jamais via un shell.
- Environnement construit explicitement avec le strict nécessaire, jamais hérité tel quel. `ANTHROPIC_API_KEY` n'est jamais transmis : sinon la session bascule sur la facturation API.
- Le contenu de la conversation passe uniquement par stdin, jamais en argument (visible avec `ps`).
- Le chemin du binaire résolu via le PATH est vérifié (chemin absolu, fichier exécutable) et affiché dans les réglages.
- Le process suit le cycle de vie de l'app : terminé à la fin du call et à la fermeture de l'app. Il ne doit pas survivre à un crash (stdin se ferme à la mort du parent : vérifier que `claude` se termine bien dans ce cas).

**Dépendances**
- FluidAudio est épinglée à une version exacte. Vérifier d'où viennent les modèles qu'elle télécharge et figer leur version.

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
│   │   └── NotchUI/
│   └── Tests/
└── Fixtures/             # fichiers audio de calls de test
```

La cible App ne contient pas de logique métier. Si un fichier de `App/` dépasse ~100 lignes, c'est probablement qu'il manque une abstraction dans `CoachKit`.

## Commandes

```bash
# Build
xcodebuild -project NotchCoach.xcodeproj -scheme NotchCoach -configuration Debug build

# Tests du package
cd CoachKit && swift test

# Mode replay : rejoue un fichier audio à la place d'un vrai call
./build/Debug/NotchCoach.app/Contents/MacOS/NotchCoach --replay Fixtures/call-objection-prix.wav
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
6. Playbook, onboarding des permissions, finitions UI.

Ne pas passer à l'étape suivante tant que la précédente ne fonctionne pas en replay.
