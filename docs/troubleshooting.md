# Troubleshooting

## Nothing plays

- **Fired before `Start`?** Early fires vanish. Load lazily once the service is up — not at script top.
- **Between lives?** No rig = play/stop/marker dropped (`nil`). Use `WaitForRig()` / `OnRigReady()`.
- **Unknown profile?** `SetCoreProfile` to an unloaded name warns instead of freezing. `LoadProfile` first (or `ExtraProfiles`).
- **Stock Animate fighting you?** Delete/disable it in `StarterPlayer > StarterCharacterScripts`. An empty `Animate` LocalScript suppresses it.

## Combat looks wrong

- **Punch contends with legs?** You omitted `Priority` (loads at `Core`). Pass `Action2`+ — or `ClampCombatPriority = true`.
- **Block jitters while walking?** Same cause. Hands-only clips belong *above* locomotion. See [Priority](priority.md).
- **Legs frozen during guard?** Your clip keys the legs. Leave lower torso + legs unkeyed for partial-body.
- **Stray `Core` clip stomping walk?** Set `LocomotionPriority = Movement`.

## Markers never fire

- **No marker in the clip?** Checks print `SKIP` until you set `MarkerClip`/`MarkerName` in `TestKit`.
- **Bound after death?** Listeners die with the character. Rebind each life, right before you play.
- **Move cancelled?** `ClearMarkers` on feint/interrupt, or stale listeners pile on the reused track.

## OneOff won't unload / count grows

- OneOffs destroy on `Stopped`. If your clip loops (`Looped = true`), it never stops — force `Looped = false` for finishers.
- Kept Singles intentionally stay till death (no eviction). That's not a leak — `10 → 11 → 11` is healthy. `10 → 20` after respawn is a leak (check you're not double-building rigs).

## Silent fails

- **`:Play()` on a held track does nothing, no error?** It died with the last character (`Parent == nil`). Dispatch by ID, never hoard tracks.
- **`_G.__AnimateServiceDebug()` is nil?** You're in the server Command Bar. Call it from a LocalScript. Or `Config.Debug = false` shipped it away.

## Assets won't load

Clips you upload only load in experiences you own (or shared with). Tests use Roblox public defaults for that reason. `BACKPACK`-style ownership errors are Roblox telling you the asset isn't yours to play here.

Still stuck? Run `AnimValidator` alone and paste the full client log — it distinguishes reuse / stop / OneOff / respawn failures line by line.
