# BA6 AI — iOS

Native iOS app. SwiftUI + Liquid Glass. MLX on-device inference.
Secure Enclave identity. SQLite + vector-indexed memory.

## Requirements

- **macOS 15+ on Apple Silicon**
- **Xcode 26** (needed for the Liquid Glass APIs — `glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`)
- **iOS 26** deployment target
- **XcodeGen** — `brew install xcodegen`
- Physical device with **A17 Pro or newer** recommended (iPhone 15 Pro, 16, 16 Pro). Simulator runs but MLX is CPU-only there.

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

Mirrors the blueprint from product spec §7:

```
ios/Sources/
├── App/                   @main entry + AppModel bootstrap
├── Core/
│   ├── LLMEngine/         MLX wrapper + streaming, ModelCatalog
│   ├── Memory/            GRDB store + vector index
│   ├── Identity/          Secure Enclave + software fallback
│   └── Crypto/            Request signing for Cloud Boost
├── Features/
│   ├── Chat/              Liquid Glass chat surface
│   ├── Settings/          Identity + memory controls
│   ├── Camera/            Vision OCR ingest (Phase 4)
│   ├── ShareExtension/    Share-sheet target (Phase 4, stub)
│   └── Files/             PDF + text ingest (Phase 4, stub)
└── Services/
    ├── CloudBoost/        Optional signed cloud offload
    └── Sync/              CloudKit mirror (Phase 5, stub)
```

## Phases shipped in this scaffold

- **Phase 1** — MLX engine + streaming + chat UI ✅
- **Phase 2** — Memory schema + vector index ✅ (retrieval wired in; embedding pipeline follows)
- **Phase 3** — Secure Enclave identity + signed requests ✅
- **Phase 4** — Camera / Share / Files — stubs only
- **Phase 5** — Cloud Boost client skeleton ✅ (no backend yet)

## Design rules (non-negotiable)

1. **Stream tokens immediately.** Anything else feels slow.
2. **Ship small models first.** 3B@4-bit before anything larger.
3. **Every surface is Liquid Glass.** Use `glassEffect` / `GlassEffectContainer`, not custom materials.
4. **No accounts.** Identity = device key. Fingerprint only.
5. **Memory is user-controlled.** Every fact is listable, forgettable, wipeable.

## Swapping in your own models

Edit `Sources/Core/LLMEngine/ModelCatalog.swift`. The `id:` string is the
Hugging Face repo — any MLX-quantized instruct model works, e.g.
`mlx-community/Mistral-7B-Instruct-v0.3-4bit`. Larger models need an
iPhone 15 Pro or iPad with 8 GB+ of RAM.

## Legacy web app

The original React/Netlify web app still lives in the repo root
(`src/`, `netlify/`, `index.html`, `migrations.sql`). It's no longer
the primary product; keeping it around for reference while the native
port lands. Delete when you're ready.
