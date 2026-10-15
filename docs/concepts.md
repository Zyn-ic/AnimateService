# Core Concepts

Seven ideas. Learn these and the API is obvious.

## 1. Locomotion core profiles

Full suites: `Idle`, `Walk`, `Run`, `Sprint`, `Jump`, `Fall`, `Climb`, `Swim`, `SwimIdle`, `Sit`, `ToolNone`.

- **Adaptive speed dividends** — playback matches movement speed: Walk `/16`, Run `/18`, Sprint `/22`, Climb `/12`, Swim `/16`.
- **Rig-scale aware** — with `ApplyRigScale = true`, velocity is normalised by `Character:GetScale()`. Giant bosses stop moonwalking.
- **Profile swapping** — `SetCoreProfile("Injured")` swaps the whole suite instantly (warrior → ninja → limp). Must be loaded first via `LoadProfile` or `ExtraProfiles`.

## 2. LoadedBin & global dedup (`_byId`)

Every track enters the bin, keyed by clean ID (`rbxassetid://123` ↔ `123`):

- System A loads `m1_combo1` as `"M1"`, system B wants it as `"Single"` — they **share the exact same track**.
- Never loaded twice on the same life. Second load is flat: `10 → 11 → 11`.

## 3. Singles vs OneOffs

- **Kept Singles** (M1s, dashes, blocks, skills) — loaded once, replayed at ~0.1ms, kept across `StopCategoryTrack`. For moves used repeatedly.
- **OneOffs** (cutscenes, awakenings, downslams) — auto-disconnect markers and `:Destroy()` the instant `Stopped` fires. Zero footprint. Fire-and-forget.

## 4. Playing-cap watchdog

Loads are free, plays are budgeted:

- **200/200 `LoadAnimation` calls succeed** — loading isn't capped.
- Playing is: the engine refuses past **64 active tracks** per `Animator` (down from 256).
- So the service guards the right thing: **no cap on loaded**, warn past **48 concurrent playing** (5s throttle) — headroom for anything else on the rig.
- OneOffs auto-destroy, death wipes the bin.

## 5. Marker fanout

Native `:GetMarkerReachedSignal()` allows one connection per track without plumbing, and breaks on reload.

- `OnMarker()` creates **one** native connection and fans out to N listeners via `task.spawn`.
- Hit detection, shake, sound and particles all hook `"hitreg"` independently.
- Listeners live on the track → die with the character. Rebind each life, ideally right before you play.
- `OnMarker` returns a handle with `Disconnect()`. `ClearMarkers` drops every listener on a marker — or the whole clip when you omit the name. Use it when a move is cancelled.

## 6. Death & respawn

- **Tracks die with the character** (`Parent == nil`).
- **The stale-reference trap:** calling `:Play()` on a dead track throws **no error** — silent fail. Never hold raw tracks; dispatch by ID.
- Asset data stays warm in `ContentProvider`, so 10 core tracks rebuild in under a millisecond.
- Remembered: loaded profiles, active core (unless `PersistProfiles = false`), preload cache. Forgotten: tracks, marker listeners, active overlay (definition remembered — re-arm it).

## 7. One-shots end for everyone

A non-looped track that finishes only ends *locally*. Without an explicit `Stop`, other clients freeze on its last frame.

Every non-looped category track gets an `Ended → Stop(0.05)` hook automatically. Playback is never cut short (markers, hit windows, tail frames all run) and the end replicates after. On by default, nothing to call.
