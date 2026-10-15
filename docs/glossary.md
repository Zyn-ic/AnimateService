# Glossary

Small words, big consequences. Skim this once — it'll save you a jittery afternoon.

| Term | What it means |
| :--- | :--- |
| **Single** | A kept combat track (`M1`, `Skill`, `Block`). Loaded once, replayed forever, survives `Stop`. Dies only on death. |
| **OneOff** | A fire-and-forget clip (`PlayOneOff`). Auto-`Destroy()`s on `Stopped`. Zero footprint. Cutscenes, downslams, awakenings. |
| **LoadedBin** | The per-life track registry (`_categories` + `_byId`). Every loaded track lives here, keyed by clean ID. |
| **Clean ID** | Normalised asset ID (`rbxassetid://123` ↔ `123`). Dedup key — same clip under two categories shares one track. |
| **`_byId`** | Global dedup map inside the bin. If system A loads `m1_combo1` as `"M1"` and system B wants it as `"Single"`, they get the same track. |
| **Core profile** | A full locomotion suite (`Idle`, `Walk`, `Run`, …). Replaces locomotion when activated via `SetCoreProfile`. |
| **Overlay** | An arms-layer set that plays *on top* of the active core (dagger stance, weapon guard). Legs fall through to core. |
| **Marker** | A named keyframe (`"Hit"`, `"Impact"`, `"hitreg"`). Hook N callbacks via `BindMarker` / `OnMarker`. |
| **Fanout** | One native `GetMarkerReachedSignal` connection, N listeners via `task.spawn`. Everyone hears the marker. |
| **Watchdog** | Playing-cap guard. Loads are free (200/200 succeed); plays are budgeted (engine cap 64, warn at 48). |
| **Stale reference** | A raw `AnimationTrack` held across respawn. Its `Parent` is `nil` and `:Play()` fails silently. Dispatch by ID instead. |
| **Ended hook** | Auto `Ended → Stop(0.05)` on every non-looped category track, so one-shots end for *everyone*, not just you. |
| **Clamp** | `ClampCombatPriority = true` forces combat tracks to `Action2`–`Action4`. Anything lower becomes `Action2`. Training wheels for combat games. |
| **Rig** | The per-life controller (`AnimateService.Rig`). Owns one character's `Animator`, profiles, bin and state machine. `Rig.new(model)` works on any Humanoid rig. |

## The two caches (don't mix them up)

- **`ContentProvider:PreloadAsync()`** — downloads keyframe bytes from Roblox's cloud to your client. Creates zero tracks.
- **`LoadedBin`** — maps an `AnimationTrack` already loaded onto your `Animator`.

> Rule of thumb: if your loading screen already preloaded the IDs, `PlayCategoryTrack` lands in under **0.1ms** with no hitch.
