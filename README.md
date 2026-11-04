# NotchCoach

App macOS de barre de menus qui écoute un call commercial (Meet, Zoom, Teams…), le transcrit en local et affiche dans la notch de courtes suggestions de réponse générées par Claude, au moment où le prospect finit de parler.

> Projet personnel, en cours de développement. L'app est pensée pour un usage individuel, en français, avec un abonnement Claude. Aucune clé d'API n'est utilisée.

## Comment ça marche

```
Audio du Mac (prospect) ─┐                                              ┌─> notch
                         ├─> transcription locale ─> conversation ─> Claude (CLI claude)
Micro (vous) ────────────┘   (Parakeet, par canal)   (déclencheur)
```

1. **Deux canaux audio.** L'audio du Mac, capté avec ScreenCaptureKit, est la voix du prospect. Le micro, capté avec AVAudioEngine, est la vôtre. Cette séparation tient lieu de diarisation : aucun modèle n'a à deviner qui parle.
2. **Transcription locale**, sur le Neural Engine. Silero VAD repère la fin de chaque prise de parole, puis Parakeet Ultra (via [FluidAudio](https://github.com/FluidInference/FluidAudio)) la transcrit d'un coup. Aucun audio ne quitte le Mac.
3. **Déclenchement.** Quand le prospect finit une phrase, les nouvelles répliques du call partent vers une session `claude` lancée au début du call et gardée prête. Il part au plus une demande toutes les 5 s.
4. **Affichage.** La réponse s'écrit mot par mot dans la notch : une ou deux phrases de 20 mots au plus, prêtes à être dites, appuyées sur votre playbook.

**Objectif de latence :** 3 s au plus entre la fin de la phrase du prospect et le premier mot affiché. En replay, on mesure entre 2 et 3,5 s environ. La première suggestion d'un call est souvent la plus lente.

## Fonctionnalités

- **Suggestions dans la notch.** Elles s'intègrent à la notch du MacBook. Sans notch, sur un écran externe principal, elles s'affichent dans une pilule centrée en haut de l'écran.
- **Historique du call.** La notch reste ouverte de la première suggestion à la fin du call et montre la dernière suggestion. Les précédentes se retrouvent en faisant défiler vers le haut.
- **Playbook.** Un fichier Markdown décrit votre offre, votre cible, vos prix et vos réponses validées aux objections. Claude s'appuie dessus et n'invente jamais un prix ni un engagement qui n'y figure pas.
- **Mode replay.** Il rejoue un fichier audio à la place d'un vrai call, pour tester et mesurer sans être au téléphone.
- **Robustesse.** Chaque partie se relance seule après une coupure :
  - Claude : jusqu'à 5 tentatives, puis une nouvelle à la phrase suivante du prospect ;
  - le micro : quand l'appareil audio change (des écouteurs branchés, par exemple) ;
  - l'audio du Mac : quand son flux s'arrête.
- **Invisible pendant un partage d'écran.** La fenêtre de la notch n'apparaît pas dans ce que vous partagez.
- **Discrète.** Pas d'icône dans le Dock : l'app vit dans la barre de menus. Elle ne prend jamais le focus à l'app de visio.

## Prérequis

- Un Mac Apple Silicon, sous macOS 15 ou plus récent.
- Xcode 27 ou plus récent, car le projet utilise le format de projet d'Xcode 27. Swift 6.
- [Claude Code](https://claude.com/claude-code) (le CLI `claude`), installé et connecté à votre compte Claude. L'app a été testée avec un abonnement Max et Claude Code 2.1.310.
- Une connexion Internet : pour Claude, et pour télécharger une fois les modèles de transcription (environ 630 Mo, depuis Hugging Face).
- Des écouteurs : sans eux, le micro capte aussi la voix du prospect qui sort des haut-parleurs.

## Installation

```bash
git clone https://github.com/Baptiste-baba/NotchCoach.git
cd NotchCoach
```

1. **Signature.** Créez le fichier de réglages propre à votre machine, puis indiquez-y votre équipe de développement (`DEVELOPMENT_TEAM`), que vous trouverez dans Xcode > Réglages > Comptes :

   ```bash
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

   Ce fichier est ignoré par git. Signer toujours avec la même identité permet à macOS de garder les autorisations (micro, enregistrement de l'écran) d'un build à l'autre.
2. **Compilation.**

   ```bash
   xcodebuild -project NotchCoach.xcodeproj -scheme NotchCoach -configuration Debug -derivedDataPath build build
   ```

   Vous pouvez aussi ouvrir `NotchCoach.xcodeproj` dans Xcode et lancer le schéma `NotchCoach`.
3. **Lancement.**

   ```bash
   open build/Build/Products/Debug/NotchCoach.app
   ```

   Lancez l'app avec `open` ou depuis le Finder plutôt qu'en exécutant directement son binaire. Sinon, macOS attribue les autorisations au terminal et non à NotchCoach.

**Claude Code.** Vérifiez dans un terminal que la commande `claude` fonctionne et que vous êtes connecté. Si besoin, lancez `claude`, puis `/login`. Une app graphique n'hérite pas du `PATH` du terminal : NotchCoach cherche donc le CLI avec votre shell de connexion (`zsh -lc 'command -v claude'`), puis garde le chemin trouvé. Pour en imposer un autre :

```bash
defaults write io.github.baptiste-baba.NotchCoach ClaudeBinaryPath /chemin/vers/claude
```

## Utilisation

### Autorisations

- **Micro** : macOS le demande au premier call.
- **Enregistrement de l'écran** : il est nécessaire pour capter l'audio du Mac. Activez NotchCoach dans Réglages Système > Confidentialité et sécurité > Enregistrement de l'écran, puis relancez l'app.

Sans l'une de ces autorisations, le call ne démarre pas, et la notch dit en rouge laquelle manque. Un écran d'accueil qui guide ces étapes est prévu.

### Le playbook

Le menu **« Modifier le playbook… »** ouvre `~/Library/Application Support/NotchCoach/playbook.md` dans votre éditeur Markdown par défaut. S'il n'existe pas encore, il est créé avec quatre rubriques vides : Offre, Cible, Pricing, Objections fréquentes et réponses validées. Le modèle ne contient volontairement aucun exemple : Claude pourrait sinon citer un faux prix à votre prospect.

- **Remplissez-le avec vos vrais éléments.** Claude reprend vos réponses validées quand elles conviennent. Il n'invente jamais un prix, une remise, un chiffre, une fonctionnalité ou un engagement absent du playbook : sans cette information, il reste général ou propose une question.
- **Il est lu au début de chaque call** : une modification compte à partir du call suivant.
- **Limites** : 50 000 caractères, enregistrés en UTF-8. Un playbook illisible ou trop long est ignoré : le call démarre sans lui, et la notch en donne la raison en rouge.

### Pendant un call

1. **Démarrage.** Dans la barre de menus, cliquez sur l'icône NotchCoach, puis sur **« Démarrer un call »**. Au premier call, l'app charge les modèles de transcription (et les télécharge au tout premier lancement), puis lance Claude. Ensuite, les modèles restent en mémoire et les calls suivants démarrent plus vite.
2. **Information du prospect.** Prévenez-le qu'un assistant prend des notes (voir [Usage responsable](#usage-responsable)).
3. **Ce que montre la notch.** Elle se déplie à la première suggestion et reste ouverte jusqu'à la fin du call.
   - Elle affiche la dernière suggestion. Faites défiler vers le haut, avec le trackpad au-dessus de la notch, pour relire les précédentes. Une nouvelle suggestion vous ramène en bas.
   - Quand Claude n'a rien d'utile à suggérer (politesses, banalités), rien ne change.
   - Les échecs s'ajoutent à l'historique en rouge : Claude n'a pas pu répondre (réseau coupé, limite d'usage de l'abonnement, erreur de l'API), Claude est indisponible, micro ou audio coupé, call sans playbook.
   - Les messages d'état passagers, comme « Claude redémarre… », s'affichent en gris et disparaissent une fois le problème réglé.
4. **Fin.** Cliquez sur **« Arrêter le call »**. La notch se replie, la transcription et l'historique sont effacés, et Claude s'arrête.

La notch s'affiche toujours sur l'écran principal, celui choisi dans Réglages Système > Moniteurs.

### Mode replay

Le mode replay rejoue un fichier audio à vitesse réelle, à la place d'un vrai call. C'est le seul moyen de tester tout le pipeline et de mesurer la latence sans être au téléphone.

```bash
./build/Build/Products/Debug/NotchCoach.app/Contents/MacOS/NotchCoach --replay Fixtures/call-objection-prix.wav
```

- **Le fichier** doit être en stéréo : canal gauche pour vous, canal droit pour le prospect. Tout format lisible par AVFoundation convient, l'app le convertit en 16 kHz.
- **Le déroulé.** Le call démarre au lancement. Le fichier fini, le call continue, notch ouverte avec tout l'historique, jusqu'à « Arrêter le call ». « Démarrer un call » rejoue alors le fichier depuis le début.
- **Le fichier fourni.** `Fixtures/call-objection-prix.wav` est un faux call d'une minute, autour d'une objection sur le prix, joué par les voix françaises de macOS. Pour le régénérer, installez les voix Jacques et Flo (Réglages Système > Accessibilité > Contenu énoncé), puis lancez :

  ```bash
  swift Fixtures/generate-call-objection-prix.swift
  ```

### Menu de debug

Dans un build Debug, le menu **« Tester Claude »** envoie un prompt fixe à Claude, puis affiche dans la notch sa réponse et le temps jusqu'au premier mot.

## Confidentialité

- **Aucun audio n'est écrit sur disque**, jamais.
- **La transcription se fait en local**, sur le Mac.
- **Un seul flux quitte le Mac** : le texte de la conversation et votre playbook, envoyés à Anthropic par le CLI `claude` pour générer les suggestions, selon les conditions de votre compte Claude.
- **Tout est effacé à la fin du call** : la transcription et l'historique ne vivent qu'en mémoire. La session `claude` est lancée sans persistance : rien n'est écrit dans `~/.claude/projects/`.
- **Les journaux masquent le contenu.** NotchCoach journalise avec `os.Logger`, et le contenu des transcriptions et des suggestions y est toujours masqué (`privacy: .private`).

## Sécurité

Ce que dit le prospect arrive directement dans le prompt de Claude : c'est une entrée non fiable, exposée à l'injection de prompt. Le process `claude` est donc isolé de tout ce qui pourrait agir au-delà de la génération de texte. Voici sa ligne de commande :

```
claude -p --input-format stream-json --output-format stream-json --verbose --include-partial-messages \
  --model haiku --tools "" --strict-mcp-config --setting-sources "" --no-session-persistence \
  --system-prompt <prompt>
```

- **Rien de votre configuration n'est chargé** : aucun outil, aucun serveur MCP, aucun réglage, plugin ni hook. Le prompt système de Claude Code est remplacé par celui du coach.
- **Le process est lancé directement, jamais via un shell**, avec un environnement réduit à `HOME`, `USER`, `PATH` et `LANG`. `ANTHROPIC_API_KEY` n'est jamais transmise : l'usage reste celui de votre abonnement.
- **La conversation passe uniquement par l'entrée standard**, jamais en argument visible avec `ps`. Le prompt système, playbook compris, est lui passé en argument.
- **Il tourne dans un dossier de travail dédié et vide** : `~/Library/Application Support/NotchCoach/ClaudeWorkingDirectory`.
- **Il s'arrête avec le call et avec l'app**, même si l'app plante, car son entrée standard se ferme alors.
- **Le prompt du coach** demande à Claude de traiter les répliques du prospect comme des données à analyser, jamais comme des instructions.

**Dépendances.** La seule dépendance externe, FluidAudio, est épinglée à la version 0.18.0, sans synthèse vocale ni diarisation. Les modèles téléchargés depuis Hugging Face sont figés sur un commit précis.

## Usage responsable

- **Informez toujours le prospect** en début de call qu'un assistant transcrit l'échange et prend des notes : c'est une obligation d'information du RGPD. Selon le pays, d'autres règles encadrent l'écoute d'un appel : vérifiez celles qui vous concernent.
- **L'invisibilité au partage d'écran** sert à garder propre ce que vous partagez, pas à cacher l'assistant au prospect.

## Architecture

Toute la logique vit dans le package Swift local `CoachKit`. La cible `App` reste mince : barre de menus, cycle de vie de l'app, démarrage et arrêt des calls.

| Module | Rôle |
|---|---|
| `AudioCapture` | Capture du micro (AVAudioEngine) et de l'audio du Mac (ScreenCaptureKit), convertis en 16 kHz mono. `LiveAudioSource` (vrai call) et `ReplayAudioSource` (fichier) suivent le protocole `AudioSource`. |
| `Transcription` | `ParakeetEngine` (FluidAudio), derrière le protocole `TranscriptionEngine` : un moteur par canal, des modèles partagés. |
| `Conversation` | `TranscriptBuffer` (répliques pas encore envoyées), `TriggerDetector` (quand demander une suggestion), `CallHistory` (ce que montre la notch) et `ConversationCoordinator`, qui les orchestre. |
| `ClaudeSession` | Le process `claude` et son protocole `stream-json` : streaming, interruption d'une réponse devenue obsolète, redémarrage avec backoff. Le protocole `LLMSession` permet une fausse session dans les tests. |
| `Prompting` | Le playbook et l'assemblage du prompt système. |
| `Call` | `CallPipeline` relie, pendant un call, la source audio, la transcription, la conversation, le playbook et Claude. |
| `NotchUI` | Le panel de la notch : un `NSPanel` non activant, placé au-dessus de la barre de menus et invisible au partage d'écran, avec la vue SwiftUI de l'historique. |

Le projet utilise Swift 6 en mode de concurrence strict. Chaque étape est un `actor`, les étapes communiquent par `AsyncStream`, et seule l'interface tourne sur le `@MainActor`.

Les prompts vivent dans des fichiers dédiés : `App/Prompts/coach-system.md` contient les consignes du coach, avec l'emplacement `{{playbook}}`, et `App/Prompts/playbook-template.md` le modèle du playbook.

## Structure du dépôt

```
NotchCoach/
├── NotchCoach.xcodeproj  # format Xcode 27, ne contient aucun réglage de build
├── Config/               # xcconfig et entitlements : seule source des réglages de build
├── App/                  # cible app : menu, cycle de vie, CallController, prompts
├── CoachKit/             # package Swift local, toute la logique
│   ├── Sources/          # AudioCapture, Transcription, Conversation, ClaudeSession, Prompting, Call, NotchUI
│   └── Tests/            # Swift Testing
├── Fixtures/             # call synthétique pour le replay, et son script de génération
└── CLAUDE.md             # spécification et règles de développement du projet
```

## Développement

**Tests.** Le package compte environ 170 tests Swift Testing. Ils couvrent toute la logique pure : déclencheur, répliques à envoyer, protocole `stream-json`, prompt, historique, coordinateur (avec une fausse session Claude) et conversion audio. La capture audio et l'interface se testent en replay et à la main.

```bash
cd CoachKit && swift test
```

**Mesurer la latence.** Chaque suggestion laisse une ligne dans le journal :

```bash
/usr/bin/log show --last 10m --info \
  --predicate 'subsystem == "io.github.baptiste-baba.NotchCoach" AND category == "Conversation"' | grep Suggestion
```

```
Suggestion n°3 : fin de tour 1075 ms, envoi 0 ms, Claude 1926 ms, total 3001 ms
```

Le chemin complet `/usr/bin/log` est nécessaire, car zsh a sa propre commande `log`. Dans Instruments, les repères (signposts) `Segment STT`, `Suggestion` et `Request` du sous-système `io.github.baptiste-baba.NotchCoach` découpent ce budget étape par étape.

**Réglages de build.** Ils se trouvent uniquement dans `Config/*.xcconfig` : le fichier projet n'en contient aucun. Seule l'équipe de signature, propre à chaque machine, est dans `Config/Local.xcconfig`, ignoré par git.

**Méthode de travail.** [`CLAUDE.md`](CLAUDE.md), en français, fait référence : contraintes, choix d'architecture, règles de sécurité et méthode de développement. Chaque fonctionnalité y est construite par couches : structure, modèles, interfaces, logique, erreurs, puis tests.

## Limites connues et feuille de route

- **Sans écouteurs**, le micro capte la voix du prospect, qui apparaît alors aussi dans la transcription comme la vôtre.
- **Les suggestions sont en français**, et leur qualité est en cours d'ajustement sur de vrais calls.
- **La première suggestion d'un call** est souvent la plus lente.
- **Prévu :**
  - un écran d'accueil pour les autorisations ;
  - un indicateur discret quand la notch est repliée (écoute en cours, Claude prêt ou non) ;
  - des réglages, dont le chemin du CLI `claude`.

## Licence

Aucune licence n'est fournie pour l'instant.
