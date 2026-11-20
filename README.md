# ECLIPSE: THE HOLLOW SKY

An original atmospheric 3D arcade game prototype, developed using **only free and legally usable tools**.

## Play

Open `project.godot` in **Godot 4.5.1+**, then press **F6** in the main scene or **F5** for the project. The scene builds its world and all visible game geometry at runtime: **no downloaded, proprietary, or AI-unlicensed art assets**.

**Controls:** A/D or left/right arrows to strafe; W/S or up/down arrows to climb/dive; Space to boost; Shift to brake; Enter to start; touch controls are shown on Android. Controller left stick and face buttons also work.

The first prototype is a score-and-survival flight course through luminous ruins. Navigate the signal gates in sequence, use boost strategically, and protect your three shield charges. Run complete when the final gate is reached; missed gates damage the ship.

## Project layout

- `scripts/game.gd`: game states, scoring, gate progression, timing
- `scripts/sky_world.gd`: deterministic procedural scenery and light design
- `scripts/flight.gd`: arcade flight and custom procedural craft
- `scripts/interface.gd`: menu, HUD, results, mobile touch inputs
- `scenes/main.tscn`: lean entry scene
- `.github/workflows/validate.yml`: automated Godot load/smoke validation

## Design and licensing

All source geometry, text, layout, and visual effects in this repository are original code created specifically for this project. No external texture packs, sound libraries, 3D models, or licensed branding are required. Godot Engine is open source (MIT license), but its engine code is not included in this repository.

**Stage:** Vertical slice / prototype. The build is not yet a visually benchmarked or device-tested release. Android export and performance tuning follow after the scene passes validation.
