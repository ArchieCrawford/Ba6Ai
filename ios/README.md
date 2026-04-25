# BA6 AI — iOS

Native iOS app. SwiftUI + Liquid Glass. MLX on-device inference with
Core ML and remote fallbacks. Secure Enclave identity. Core Data +
CloudKit memory. Metal video pipeline. App Intents for Siri/Shortcuts.

## Requirements

- **macOS 15+ on Apple Silicon**
- **Xcode 26** (Liquid Glass APIs: `glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`)
- **iOS 26** deployment target
- **XcodeGen** — `brew install xcodegen`
- Physical device with **A17 Pro or newer** strongly recommended (MLX is CPU-only on simulator)
- Apple Developer account if you want CloudKit sync

## First-time build

```bash
cd ios
xcodegen generate    # produces Ba6Ai.xcodeproj from project.yml
open Ba6Ai.xcodeproj
```

In Xcode:

1. Select the **Ba6Ai** scheme and your device.
2. Set your development team under *Signing & Capabilities*.
3. Build & run.

First launch downloads the default model (~1.9 GB for Qwen 2.5 3B · 4-bit)
from Hugging Face into the app sandbox. Subsequent launches are instant.

## Architecture

Layered per the BA6 spec:

```
ios/Sources/
├── App/                @main entry + AppModel bootstrap + RootView
├── AI/                 inference, prompts, memory context
│   ├── InferenceEngine.swift     router that picks the right provider
│   ├── InferenceTypes.swift      Sendable request / chat-turn types
│   ├── PromptEngine.swift        persona + memory-injection format
│   ├── MemoryContext.swift       embedding + retrieval bridge
│   ├── ModelCatalog.swift        on-device LLMs we ship
│   ├── Providers/
│   │   ├── MLXProvider.swift     on-device LLM/VLM (primary)
│   │   ├── CoreMLProvider.swift  Neural Engine path (embeddings now,
│   │   │                          tiny distilled LLM hook ready)
│   │   └── RemoteProvider.swift  signed SSE cloud fallback
│   └── Video/
│       ├── VideoEngine.swift     VLM understanding via MLXVLM
│       ├── VideoFrameSampler.swift
│       ├── VideoGenerator.swift  Metal frame loop + AVAssetWriter
│       ├── VideoModelCatalog.swift
│       ├── VideoWriter.swift
│       ├── MetalRenderer.swift
│       └── Shaders.metal
├── Data/               persistence + identity
│   ├── Persistence.swift                 NSPersistentCloudKitContainer
│   ├── Memory/MemoryStore.swift          @MainActor Core Data store
│   ├── Memory/Models.swift               value types + NSManagedObject
│   ├── Memory/VectorIndex.swift          in-memory cosine similarity
│   └── Identity/
│       ├── DeviceIdentity.swift          Secure Enclave P256
│       └── RequestSigner.swift           signed cloud requests
├── UI/                 Liquid Glass component library
│   ├── Theme.swift           tokens (radius, motion, surface, glow)
│   ├── GlassPanel.swift      base glass surface w/ depth + glow
│   ├── GlassCard.swift       interactive expandable card
│   ├── GlassButton.swift     wraps .glass / .glassProminent
│   ├── GlassChip.swift       status pill (live pulse glow)
│   ├── GlassTabBar.swift     floating tab bar w/ pill + matched-geo
│   └── GlowEffect.swift      reusable glow + liquid highlight
├── Features/           feature surfaces
│   ├── Chat/                 streaming bubbles, glass composer
│   ├── Memory/               expandable memory cards
│   ├── Video/                Understand + Generate panes
│   ├── Settings/             identity, models, memory, privacy
│   └── Camera/               Vision OCR helper (Phase 4 ingest)
├── Integrations/       system surfaces
│   ├── AppIntents/
│   │   ├── AskBA6Intent.swift        "Hey Siri, ask BA6 …"
│   │   └── BA6IntentRouter.swift     router shared by intents
│   └── Notifications/
│       └── NotificationService.swift
└── Resources/
    ├── Info.plist
    ├── Ba6Ai.entitlements
    └── BA6AI.xcdatamodeld/           Core Data + CloudKit schema
```

### Hybrid inference routing

`InferenceEngine` picks between providers per call:

| User preference | Routing                                                                  |
|-----------------|--------------------------------------------------------------------------|
| `.localOnly`    | Always MLX on-device.                                                    |
| `.cloudBoost`   | Always Remote.                                                           |
| `.auto`         | Image / video attachments → MLX. Estimated context > 4k tokens → Remote. Otherwise MLX if ready, else Remote. |

The user toggles preference from Settings or per-conversation in the
chat toolbar. The Liquid Glass chip in the chat header reflects which
provider answered the last turn.

### Memory model

* **Core Data + CloudKit** (`NSPersistentCloudKitContainer`).
* iCloud sync is **off by default**. Toggle from Settings; data stays
  in the user's private database.
* `MemoryContext` calls `CoreMLProvider.embed(...)` (NLEmbedding under
  the hood) on every "remember that …" capture, stores the vector
  alongside the row, and rebuilds the in-memory cosine-similarity
  index on launch.

### App Intents (Siri / Shortcuts)

Two intents ship out of the box:

* **AskBA6Intent** — `"Hey Siri, ask BA6 about ..."` returns a streamed
  answer. Capped at 6 KB so Siri readback stays usable.
* **RememberFactIntent** — `"Hey Siri, BA6 remember that ..."` writes
  directly to the memory store, no LLM round-trip.

Both run in-process (no `openAppWhenRun`) so the Lock Screen / standby
experience feels native.

### Liquid Glass UI

Every surface routes through `UI/`:

* `Theme.Motion.standard` is the only spring you ever reach for —
  consistency comes from one source of truth.
* `GlassPanel` and `GlassCard` add the dual-layer depth shadow,
  `liquidHighlight` top edge, and optional accent glow.
* `GlassTabBar` uses `matchedGeometryEffect` for the selection pill
  and a glowing solid pill on the active tab.
* `GlassChip` pulses softly when status is non-neutral (loading, etc.)
  so live state feels alive, not blinking.

## Phase status

- **Phase 1** — MLX engine, streaming, chat ✅
- **Phase 2** — Core Data memory + retrieval ✅
- **Phase 3** — Secure Enclave identity + signed cloud requests ✅
- **Phase 4** — Camera + Files + Share Extension — helpers landed, UI
  surfaces stubbed
- **Phase 5** — Cloud Boost backend — Swift client live, server is
  out-of-repo
- **Phase 6** — App Intents / Siri ✅, UserNotifications scaffolding ✅,
  CloudKit toggle ✅

## Customising

| To do | Edit |
|-------|------|
| Swap models | `Sources/AI/ModelCatalog.swift` |
| Change persona | `Sources/AI/PromptEngine.swift` |
| Tune routing | `Sources/AI/InferenceEngine.swift` |
| Adjust motion | `Sources/UI/Theme.swift` |
| Add a Siri phrase | `Sources/Integrations/AppIntents/AskBA6Intent.swift` |
| Wire Core ML LLM | `Sources/AI/Providers/CoreMLProvider.swift` |

## Legacy web app

Original React/Netlify app is preserved under `archive/web-v1/` at
the repo root. The web at `/` is now a marketing-only landing page.
