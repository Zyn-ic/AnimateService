# Rig API

The per-life workhorse. `AnimateService.Rig.new(model)` works on any Humanoid rig (NPCs untested but structurally supported). The controller owns one for your LocalPlayer automatically.

```luau
local rig = AnimateService.Rig.new(model)
rig:LoadProfile("__Default__", def)
rig:SetActiveProfile("__Default__")
rig:Init()
rig:Start()
-- later: rig:Destroy()
```

Constructor stops + destroys leftover engine tracks, waits for `Humanoid` / `Animator`.

## Profiles

- `HasProfile(name): boolean`
- `LoadProfile(name, def): Rig` — skips if destroyed / exists. `SwimIdle` normalised, `Priority = LocomotionPriority`, `Looped = (name ~= "Jump")`.
- `SetActiveProfile(name?): Rig` — `nil` → last loaded. Warns on unknown. Stops active tracks, re-evaluates.
- `ChangeAll(name, def): Rig` — destroy old record + reload (used by `ReplaceProfile`).

## Playback

- `PlaySingle(category, animId, opts?: PlayOpts): AnimationTrack?` — `LoadCategory` with `AutoPlay = true`.
- `PlayOneOff(animId, opts?: PlayOpts): AnimationTrack?` — `category = "OneOff"`, `Looped = false`, `Stopped:Once → destroy`.
- `LoadCategory(category, animId, opts?: LoadOptions): AnimationTrack?` — three-tier lookup (same-bucket → `_byId` share → fresh `LoadAnimation`), honouring `AutoPlay / PreloadOnly / Priority / Looped / MarkerName+Callback / OnLoaded`.
- `StopCategory(category, animId?: string, fade?: number)` — default fade `0.05`.
- `StopAllCategory(category, fade?)`.
- `Preload(ids: { string })` — no-op if destroyed. Deduped process-wide.

## Markers

- `OnMarker(category, animId, marker, cb): MarkerHandle?` — lazy-loads (`AutoPlay = false`) on miss. One native conn per marker, fanout via `task.spawn`.
- `ClearMarkers(category, animId, marker?)`.
- `GetMarkerListenerCount(category, animId, marker): number`.

Non-looped category tracks get an automatic `Ended → Stop(0.05)` so one-shots end for everyone.

## Queries

- `GetTrack(category, animId): AnimationTrack?`
- `IsPlaying(category, animId): boolean`
- `GetLoadedCount(): number`
- `GetLoadedList(): { [cleanId]: string }`
- `GetProfileCount(): number`
- `GetAnimatorPlayingCount(): number` (`pcall(GetPlayingAnimationTracks)`)

## Locomotion tuning

- `SetLocomotionWeight(mult, fade?)` — scale `_activeTracks` weight.
- `ChangeAnimateParams(patch)` — raw thresholds/dividends: `SprintThreshold = 24`, `RunThreshold = 17`, `WalkThreshold = 0.01`, `SprintDividend = 22`, `RunDividend = 18`, `WalkDividend = 16`, `ClimbDividend = 12`, `SwimDividend = 16`, `JumpDuration = 0.31`, `ApplyRigScale = true`.

`_speed()` = horizontal `HumanoidRootPart.AssemblyLinearVelocity` magnitude `/ Character:GetScale()` when `ApplyRigScale`.

State map (`Running / Climbing / Swimming(speed)`, `StateChanged`, `Died`):

| State | Track |
| :--- | :--- |
| `Dead / GettingUp / FallingDown / PlatformStanding / Physics` | stop all core + overlay |
| `Seated` | `Sit (0.5)` |
| `FreeFalling` (and not mid-jump) | `Fall (0.3)` |
| `Climbing` | `Climb (0.1, speed/12)` |
| `Swimming` | `speed < 5 → SwimIdle (0.2)` else `Swim (0.3, speed/16)` |
| `Jumping` | `Jump (0.1)` |
| `Running` + still | `Idle (0.1)` |
| `speed >= 24` | `Sprint (0.2, speed/22)` |
| `speed >= 17` | `Run (0.2, speed/18)` |
| `speed > 0.01` | `Walk (0.15, speed/16)` |
| else | `Idle (0.1)` |

## Overlays

- `SetOverlayProfile(name?, priority?): Rig` — re-evaluates if running.
- `ClearOverlay(): Rig`.

Overlay plays in lockstep after every core track (`_playOverlayAnim` at the end of `_playProfileAnim`), same `FadeTime/Speed`, priority = passed or `DefaultOverlayPriority`.

## Lifecycle

- `Init(): Rig` — connects `StateChanged / Running / Climbing / Swimming / Died`.
- `Start(): Rig` — seeds state, evaluates once.
- `Destroy()` — disconnect all, destroy active + profile + category tracks, clear markers/`EndStopConn`, reset counts.
