# ECLIPSE: THE HOLLOW SKY — Stride Android game

**This is the game, not the Stride FPS graphics test.** The Godot game at the repository root remains independent; the old Stride FPS compatibility experiment remains under `experiments/stride-graphics-test/`. Do not conflate them.

## Android game implemented (first playable Stride sector)
- Aether Skiff, third-person chase camera, free aerial strafing/climbing, automatic forward flight, boost/recharge, brake
- Seven beacon gates, time limit, hull/shields, missed-gate penalties, score
- Floating cliffs and islands, ruined platforms, sun, cloud banks and aether crystals
- Hunter drones, large Warden encounter, visible plasma bolts, enemy hit detection
- Salvage from signals/enemies; persistent hangar credits and three upgrade lanes (hull, weapon, reactor)
- Android HUD + left flight stick + BOOST / FIRE / BRAKE + launch/hangar upgrade controls, keyboard fallback

This is a playable **engine-port milestone**, not yet content parity with the full Godot build. Advanced mission variety, custom meshes/GLB, VFX, audio and Android GPU telemetry will follow after phone testing.

## Source
- `source/EclipseDirector.cs`: full game loop and world
- `source/EclipseBridge.cs`: multi-touch input plus HUD state
- `source/EclipseActivity.cs` + `source/FlightHud.cs`: Android activity / touch UI
- `source/MainScene.sdscene`: clean original Stride scene, camera, lighting
- `build-eclipse.ps1`: GitHub cloud generation, packaging verification

## Build
Actions → **Build Eclipse Stride Android Game** → Run workflow, or push an isolated game source change. Successful runs upload `eclipse-hollow-sky-stride-android` with `Eclipse-The-Hollow-Sky-Stride-v1.apk`.

The official Stride FPS template provides a known-good NuGet/Android build *bootstrap only*. The script deletes **all FPS scene assets and all FPS C# gameplay scripts**, then inserts the original Eclipse scene, game logic, and Android activity. The FPS arena and gun are not part of this game. Uses free open-source tooling and no GPU training time.

## First phone QA
Install signed APK, start the sortie, steer through the signals. Confirm skiff visible, camera follows, seven gates progress, left flight stick, fire/boost/brake, hangar upgrades and restart. Measure actual FPS/temperatures against the established Godot build. CI build success is **not** a substitute for an Android runtime test.
