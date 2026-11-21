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
    print("ECLIPSE GAMEPLAY SMOKE: PASS -- spatial culling, ribbon batching, enemies, salvage, sector, debrief, hangar")
    quit(0)
