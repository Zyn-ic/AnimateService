# Benchmarks

Numbers measured live in Play Solo on a 10-slot core. Your counts follow your folders — the behaviours hold for any setup.

## The headline

- **Initial core:** exactly **10 tracks** on spawn.
- **Zero leak on respawn:** rebuilds 10. Never 20, never 38.
- **Cold vs warm:** un-preloaded fetch **~125.9ms**, preloaded dispatch **~0.1ms**.
- **Reuse flat:** `PlayCategoryTrack` on a loaded ID stays `10 → 11 → 11`. Zero allocations.

```text
[Validator] PASS single reuse second load flat -- before 10 mid 11 after 11
[PartialTest] CONFIRMED old track dead after respawn: parentNil=true replayOk=true
[PartialTest] same id dispatches in 0.1ms after respawn (content cached, only the track is new)
```

## Replay without re-loading (same life)

Loading an already-loaded animation reuses the existing `AnimationTrack`. Count stays flat:

```text
[Validator] PASS single reuse second load flat -- before 10 mid 11 after 11
```

First load `10 → 11`. Second load `11 → 11`.

## The two caches

- **`ContentProvider:PreloadAsync()`** — downloads bytes from Roblox's cloud. Creates zero tracks.
- **`LoadedBin`** — maps an `AnimationTrack` on your `Animator`.

> If your loading screen already preloaded the IDs, `PlayCategoryTrack` lands in under **0.1ms** with no hitch.

## Across death

```text
[PartialTest] CONFIRMED old track dead after respawn: parentNil=true replayOk=true
```

- `parentNil = true` — old track detached and destroyed.
- `replayOk = true` — the engine doesn't throw on `:Play()` of a dead track; it fails silently. (Don't hoard tracks.)
- `0.1ms` — asset bytes survive, only the track is new.

## Watchdog math

- **Engine cap:** 64 active tracks per `Animator` (down from 256). Past it, new plays are refused.
- **Service warn:** 48 concurrent playing (5s throttle) — headroom for anything else on the rig.
- **200/200 loads succeed** — loading isn't capped, so load your whole moveset. Budget plays, not loads.

Run the proofs: [Tests](tests.md) — `AnimValidator` (reuse + respawn), `AnimStutterTest` (cold vs warm), `AnimOneOffTest` (warm OneOff + auto-unload).
