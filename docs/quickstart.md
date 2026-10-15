# Quickstart (60 seconds)

!!! tip "One minute, three folders"
    Copy → suppress stock → fire a signal.

After this page you can swing an M1 and stop it mid-windup.

## Prerequisites

- Roblox Studio (any place with an R15 or R6 rig)
- This repo's `Module/`, `Services/`, `Libraries/` folders

No Wally, no Rojo, no uploads. Tests run on Roblox's own public animations.

## 1. Install

Copy into `StarterPlayerScripts`, keeping the shape:

```text
StarterPlayerScripts/
  Module/AnimateService        -- the engine (ModuleScript)
  Services/AnimateService      -- one-file launcher (LocalScript)
  Libraries/AnimSignals        -- typed signal bus (ModuleScript)
  Libraries/Signal             -- SignalPlus v3.7.2, vendored (ModuleScript)
```

Driving it from your own module loader instead? Skip `Services/` and read [Module Mode](module-mode.md).

## 2. Kill stock Animate

Delete or disable Roblox's default `Animate` script in `StarterPlayer > StarterCharacterScripts`.

An empty `Animate` LocalScript suppresses it. The launcher does the rest.

## 3. (Optional) Give it legs

Add `R15Animations` and/or `R6Animations` folders as children of the `Services/AnimateService` script, each holding `Animation` objects named per slot:

`Idle`, `Walk`, `Run`, `Sprint`, `Jump`, `Fall`, `Climb`, `Swim`, `SwimIdle`, `Sit`

Stock-style `StringValue` slots work too. No folders at all is fine — the service runs combat-only and every Single still loads by asset id.

## 4. Swing something

From any LocalScript:

```luau
local AnimSignals = require(
    game.StarterPlayer.StarterPlayerScripts.Libraries.AnimSignals
)

-- snap into an M1 swing
AnimSignals.PlayCategoryTrack:Fire("M1", "rbxassetid://507766388", {
    FadeTime = 0.05,
    Priority = Enum.AnimationPriority.Action2,
})

-- feint it 0.2s later
task.delay(0.2, function()
    AnimSignals.StopCategoryTrack:Fire("M1", "rbxassetid://507766388", 0.05)
end)
```

`rbxassetid://507766388` is Roblox's default idle — it always loads, so you can test with zero uploads.

## 5. Prove it didn't leak

Copy `Tests/` next to `Services/` and `Module/`. Disable all but `AnimValidator`, press Play Solo:

```text
[Validator] PASS single reuse second load flat -- before 10 mid 11 after 11
[Validator] PASS stop path alive
[Validator] PASS oneoff no permanent leak
```

Reset your character. You should see:

```text
[Validator] PASS respawn rebuild == baseline -- got 10 want 10
```

Never 20, never 38. That's the whole promise.

## What you just got

- **LoadedBin** — that ID is now cached on your Animator. Fire it again and it replays in ~0.1ms.
- **Clean stop** — `StopCategoryTrack` faded it out, no orphaned weight.
- **Per-life safety** — reset and the track died with you. Fire again and it rebuilds warm.

Next: [Life of a Swing](life-of-a-swing.md) — follow one M1 from button press to replay.
