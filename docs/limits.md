# Limits & Roadmap

No surprises. What's true today, and what's next.

## Known limits

- **No eviction.** Kept Singles stay loaded until death. `Keep` and per-entry `LastUsed` / `Refs` are recorded but nothing reads them yet.
- **Signals aren't queued.** A fire before the bus connects — or between lives — is lost. Profiles, overlay defs and `Preload` are remembered; play/stop/marker with no rig are dropped.
- **Markers + active overlay don't survive respawn.** Rebind / re-arm each life (`OnRigReady` is your friend).
- **Server NPC rigs** via `AnimateService.Rig.new(model)` should work but are untested.
- **Assets are per-owner.** Uploads only load where you own (or share) them. Tests use public defaults so they run anywhere.

## Roadmap ideas

- Optional eviction (LRU on `LastUsed` / `Refs`) for giant movesets.
- Queued early fires (or explicit `WaitForReady` bus) so top-level fires stop vanishing.
- First-class NPC rig support + server tests.
- Overlay persistence option (remember *active* overlay, not just definitions).

PRs welcome — keep the bin flat and the dispatches warm.

## Credits

- MIT. See `LICENSE`.
- `Libraries/Signal.luau` is SignalPlus v3.7.2 by Alexander Lindholt (MIT) — header retained, `Signal` / `Connection` types re-exported by `AnimSignals`.
