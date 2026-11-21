extends SceneTree
## CI gameplay integration smoke test, beyond simply launching the title screen.
## Runs without APK/device and checks that combat, sector, and progression paths work.

func _initialize() -> void:
    call_deferred("_test")


func _test() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        push_error("Could not load main scene")
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    game._start()
    await process_frame
    if game.render_budget.total_static < 150:
        push_error("Spatial budget failed to discover compiled environment meshes")
        quit(1)
        return
    if game.render_budget.hidden_static <= 0:
        push_error("Spatial budget failed to cull distant static geometry")
        quit(1)
        return
    if game.sky_fx.cascades.size() != 14:
        push_error("Missing batched aetherfall groups")
        quit(1)
        return
    for fall in game.sky_fx.cascades:
        if fall.get_node_or_null("BatchedAetherfallRibbons") == null:
            push_error("Aetherfall is not using combined ribbons")
            quit(1)
            return
    # The animated 7-ring course must use instancing after stage bake.
    for gate in game.world.gates:
        var ornaments: Node3D = gate.get_node("Ornaments")
        if ornaments.get_child_count() != 2:
            push_error("Gate ornaments still contain unbatched draw nodes")
            quit(1)
            return
        for decoration in ornaments.get_children():
            if not decoration is MultiMeshInstance3D:
                push_error("Expected instanced gate ornaments")
                quit(1)
                return
            var mm := (decoration as MultiMeshInstance3D).multimesh
            if mm == null or mm.instance_count != 12:
                push_error("Expected 12 ornaments in each gate instanced group")
                quit(1)
                return
    # Validate four profiles on the same baked scene without a scene reload.
    for quality in range(4):
        game.graphics_index = quality
        game._apply_graphics()
        if game.mobile_budget.preset != quality:
            push_error("Performance preset did not apply")
            quit(1)
            return
        if absf(game.mobile_budget.current_scale - game.mobile_budget.INITIAL_SCALES[quality]) > 0.01:
            push_error("Performance preset render resolution incorrect")
            quit(1)
            return
    var sun_for_profiles := game.world.find_child("PrimarySun", true, false) as DirectionalLight3D
    if sun_for_profiles == null or sun_for_profiles.directional_shadow_mode != DirectionalLight3D.SHADOW_ORTHOGONAL:
        push_error("FPS MAX did not reduce directional shadow splits")
        quit(1)
        return
    game.graphics_index = 1
    game._apply_graphics()
    var initial_scale: float = game.mobile_budget.current_scale
    # Drive the supervisor with synthetic GPU-like slow frame timings;
    # using the real CI runner's FPS would make this test non-deterministic.
    for i in range(110):
        game.mobile_budget.tick(0.041, false)
    if game.mobile_budget.current_scale >= initial_scale:
        push_error("Auto60 controller did not lower resolution after sustained slow frames")
        quit(1)
        return
    game._apply_graphics()
    if game.mobile_budget.percent_scale() != 90:
        push_error("Auto60 profile did not recover its starting resolution")
        quit(1)
        return

    # Verify 60fps pacing is selectable but never imposed on Ultra by default,
    # and that the no-shadow diagnostic cleanly restores the sun.
    game._toggle_benchmark() # VSYNC -> UNLOCKED
    game._toggle_benchmark() # UNLOCKED -> CAP 60
    if Engine.max_fps != 60:
        push_error("Optional 60fps benchmark cap failed")
        quit(1)
        return
    game._toggle_benchmark() # CAP 60 -> NO SHADOW
    var sun := game.world.find_child("PrimarySun", true, false) as DirectionalLight3D
    if sun == null or sun.shadow_enabled:
        push_error("Shadow-off diagnostic failed")
        quit(1)
        return
    game._toggle_benchmark() # NO SHADOW -> VSYNC
    if Engine.max_fps != 0 or not sun.shadow_enabled:
        push_error("Shadow and frame limit restoration failed")
        quit(1)
        return
    if game.combat.count_alive() < 5:
        push_error("Expected hunter drones on sortie launch")
        quit(1)
        return
    if game.max_hull < 3:
        push_error("Player hull initialization failed")
        quit(1)
        return
    var old_score: int = game.score
    game._enemy_destroyed(300, 15, false)
    if game.score <= old_score or game.total_kills != 1:
        push_error("Enemy defeat did not award score or combo")
        quit(1)
        return
    var salvage_before: int = game.run_salvage
    game._supply_collected("salvage")
    if game.run_salvage <= salvage_before:
        push_error("Pickup salvage not awarded")
        quit(1)
        return
    game._complete_sector()
    await process_frame
    if game.sector != 2 or game.gate_index != 0:
        push_error("Sector progression / reset failed")
        quit(1)
        return
    if game.combat.count_alive() < 5:
        push_error("Next sector lacks enemy spawns")
        quit(1)
        return
    game._finish(false)
    await process_frame
    if game.mode != 2:
        push_error("Debrief state failed")
        quit(1)
        return
    game._return_hangar()
    await process_frame
    if game.mode != 0:
        push_error("Hangar return failed")
        quit(1)
        return
    print("ECLIPSE GAMEPLAY SMOKE: PASS -- profiles, adaptive render scaling, shadow LOD, spatial culling, ribbon batching, enemies, salvage, sector, debrief, hangar")
    quit(0)
