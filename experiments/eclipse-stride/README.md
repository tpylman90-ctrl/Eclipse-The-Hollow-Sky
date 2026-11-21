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


## v3 Android graphics foundation (experimental / requires device verification)

**Starting point:** The v2 game scene is visible on an Android phone; a screenshot showed ~24 update ticks/sec. This is not the GPU render FPS and does not by itself establish a bottleneck.

The v3 branch changes:
- Replaces the 40 multi-entity blob islands with eight merged **per-material** mesh chunks; each has faceted tapered undersides, temple slabs, arches and crystal peaks. These are generated from original vertex data and have explicit bounds for Stride frustum culling.
- Replaces the 68 separate cloud spheres with four mesh-batched cloudbank sections.
- Rebuilds the flyable Aether Skiff as a consolidated sharp-planform, two-engine hard-surface model. It is an **original code-generated model**, not a Blender GLB import.
- Maintains the seven-gate progression, enemies, player controls, hangar, saves, loading screens and separate Godot root.
- Adds an Android main-menu **GRAPHICS** selector: PERFORMANCE (720x405 requested), BALANCED (960x540), QUALITY (1280x720). The graphics manager requests a backbuffer resize. The environment also changes streaming distance, and directional shadows only enable on QUALITY. Device drivers may ignore or refuse resizing; in that case the scene stays playable and shows a fallback status.
- Replaces the misleading update-only telemetry with both **render FPS** (Stride DrawTime) and **update ticks/sec**. The flight HUD also shows update ms, draw calls, triangles and managed heap MB. These are not guaranteed GPU frame-time measurements.
- Collects a lightweight 10-second interval benchmark CSV under app-local storage as `eclipse_stride_v3_benchmark.csv`.

**Phone test matrix:** Start/launch/render on each quality preset, compare real draw FPS + draw calls + triangles; fly through all seven gates; verify restart/hangar and input; compare after 10+ minutes for thermal throttling. Capture screenshots with rendered FPS and draw counts. If graphics disappear after a preset change, relaunch and select BALANCED.

**Not yet validated:** Full device GPU timings, ASTC packaging, normal-map/trim-sheet authored textures, Blender GLB pipeline, advanced bloom/SSR or true asset LOD switching. Those require scene assets and subsequent on-device profile-guided passes. Do not claim these effects exist in v3. The official Stride Game Profiler, RenderDoc and Android GPU Inspector are appropriate for deeper investigation.

**Version:** The v2 bootstrap already installs the Stride 4.4.4 official starter; v3 keeps the same tested 4.4.4 versions rather than partially rewriting its packages to 4.4.3. v3 uses a distinct Android application ID and APK filename; the last working v2 commit is preserved in `archive/eclipse-stride-v2-2026-11-21`.

## Source
- `source/EclipseDirector.cs`: full game loop and world
- `source/EclipseBridge.cs`: multi-touch input plus HUD state
- `source/EclipseActivity.cs` + `source/FlightHud.cs`: Android activity / touch UI
- `source/MainScene.sdscene`: clean original Stride scene, camera, lighting
- `build-eclipse.ps1`: GitHub cloud generation, packaging verification

## Build
Actions → **Build Eclipse Stride Android Game** → Run workflow, or push an isolated game source change. Successful runs upload `eclipse-hollow-sky-stride-android` with `Eclipse-The-Hollow-Sky-Stride-v3.apk`.

The official Stride FPS template provides a known-good NuGet/Android build *bootstrap only*. The script deletes **all FPS scene assets and all FPS C# gameplay scripts**, then inserts the original Eclipse scene, game logic, and Android activity. The FPS arena and gun are not part of this game. Uses free open-source tooling and no GPU training time.

## First phone QA
Install signed APK, start the sortie, steer through the signals. Confirm skiff visible, camera follows, seven gates progress, left flight stick, fire/boost/brake, hangar upgrades and restart. Measure actual FPS/temperatures against the established Godot build. CI build success is **not** a substitute for an Android runtime test.

## v2 startup and camera repair
The Android application follows **Stride engine splash → staged game asset initialization → Eclipse main menu/hangar → sortie preparation → 3D flight**. Gate checks and the sortie timer are inactive while either loading screen is displayed. Initial loading actually creates shared PBR materials, cloud atmosphere, the Aether Skiff, the seven-gate environment, and calibrates the chase camera in separate update phases.

The v1 screenshot showed gameplay HUD over a black renderer. It was traced to a mismatch between the custom camera's `Slot` and the GraphicsCompositor's active camera ID, compounded by a stale `DefaultScene` GUID. The v2 build reads those IDs from the generated project and verifies they are aligned before building. Gameplay buttons and the menu launch area have additional clearance from Android's right navigation area.

v2 is built with a distinct Android application ID so it can be installed alongside v1. GitHub build checks validate the package, but the renderer's behavior still needs a device screenshot.
