# AnimateService

**Stock `Animate` was built for obbies — not anime combat.**
Drop-in replacement for Roblox's default `Animate`, also usable as a plain module. Fire signals, or `require` it and call it directly. LoadedBin dedup, 0.1ms preload dispatch, marker fanout, partial-body combat.

[Docs](https://zyn-ic.github.io/AnimateService/) · [Releases](https://github.com/Zyn-ic/AnimateService/releases)

## Features

- **LoadedBin registry** — every track indexed by clean ID and reused; Singles stay loaded till death, OneOffs unload themselves.
- **Preload dispatch** — system-side `PreloadAsync`, cold ~125ms → warm ~0.1ms.
- **Marker fanout** — N systems hear `Hit` / `CanCancel` on the same track.
- **Clean stops** — `StopCategoryTrack` / `StopAllInCategory` for feints, interrupts, stuns.
- **Partial-body combat** — hands at `Action2+`, legs free. Walk while blocking.

## Built around

| System | What | Read |
|---|---|---|
| **Singles vs OneOffs** | Kept combos vs fire-and-forget finishers | [Core Concepts](https://zyn-ic.github.io/AnimateService/concepts/) |
| **Priority** | `Action4` > `Action3` > `Action2` > `Movement` > `Core` (+ clamp) | [Priority](https://zyn-ic.github.io/AnimateService/priority/) |
| **Markers** | One native conn, N listeners via `task.spawn` | [Markers](https://zyn-ic.github.io/AnimateService/markers/) |
| **Profiles** | Full locomotion swaps + arms-layer overlays | [Profiles](https://zyn-ic.github.io/AnimateService/profiles/) |
| **Signals** | 12-verb typed bus, or direct `require` calls | [Signal Catalog](https://zyn-ic.github.io/AnimateService/signals/) |

## Getting Started

1. Copy `Module/`, `Services/`, `Libraries/` into `StarterPlayerScripts` (keep the shape).
2. Delete stock `Animate` in `StarterPlayer > StarterCharacterScripts` (empty `Animate` suppresses it).
3. Fire a swing:
   ```lua
   AnimSignals.PlayCategoryTrack:Fire("M1", "rbxassetid://123456789", {
       FadeTime = 0.05,
       Priority = Enum.AnimationPriority.Action2,
   })
   ```
4. Prove it: copy `Tests/` next door, run `AnimValidator` solo — `10 → 11 → 11`, never 20.

New here? [Quickstart](https://zyn-ic.github.io/AnimateService/quickstart/) → [Life of a Swing](https://zyn-ic.github.io/AnimateService/life-of-a-swing/) → [Combat Recipes](https://zyn-ic.github.io/AnimateService/recipes/).

## Documentation

Full docs: [zyn-ic.github.io/AnimateService](https://zyn-ic.github.io/AnimateService/) (architecture, priority, signals, module mode, recipes, benchmarks, API).

## Credits

- MIT. See `LICENSE`.
- `Libraries/Signal.luau` is SignalPlus v3.7.2 by Alexander Lindholt (MIT).
