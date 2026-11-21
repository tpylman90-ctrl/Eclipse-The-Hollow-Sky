extends SceneTree
## Offline stage compiler for GitHub CI and local Godot editor builds.
## Bake geometry once, merge compatible static objects by material and spatial chunk,
## save engine-native PackedScenes. Flight, beacons and combat remain fully interactive.
##
## Run: godot --headless --path . --script res://tools/bake_stage.gd

const WorldScript = preload("res://scripts/sky_world.gd")
const ArtScript = preload("res://scripts/art_direction.gd")
const OUTPUT_DIR := "res://generated"
const CHUNK_METERS := 165.0
const BATCH_THRESHOLD := 3

var error_count := 0


func _initialize() -> void:
    call_deferred("_compile")


func _compile() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
    var world := WorldScript.new()
    world.name = "CompiledWorld"
    root.add_child(world)
    var art := ArtScript.new()
    art.name = "CompiledArchitecture"
    root.add_child(art)
    await process_frame
    if world.gates.size() != 7:
        push_error("World generation failed to create seven signal gates")
        quit(1)
        return
    # Geometry must be generated while the scripts are attached.
    var world_metrics := _batch_static(world, true)
    var art_metrics := _batch_static(art, false)
    _own_children(world, world)
    _own_children(art, art)
    world.set_script(null)
    art.set_script(null)
    var world_ok := _save_tree(world, OUTPUT_DIR + "/world.scn")
    var art_ok := _save_tree(art, OUTPUT_DIR + "/architecture.scn")
    if world_ok and art_ok:
        print("ECLIPSE STAGE BAKE: PASS world=", world_metrics, " architecture=", art_metrics)
        quit(0)
    else:
        push_error("ECLIPSE STAGE BAKE: FAIL")
        quit(1)


func _save_tree(target: Node3D, destination: String) -> bool:
    var packed := PackedScene.new()
    var result: Error = packed.pack(target)
    if result != OK:
        push_error("Packing failed for " + destination + ": " + error_string(result))
        return false
    result = ResourceSaver.save(packed, destination, ResourceSaver.FLAG_COMPRESS)
    if result != OK:
        push_error("Saving failed for " + destination + ": " + error_string(result))
        return false
    return FileAccess.file_exists(destination) and FileAccess.get_file_as_bytes(destination).size() > 1024


func _own_children(parent: Node, scene_root: Node) -> void:
    for child in parent.get_children():
        child.owner = scene_root
        _own_children(child, scene_root)


func _batch_static(stage: Node3D, protect_gate_children: bool) -> Dictionary:
    var renderables: Array[MeshInstance3D] = []
    _collect_meshes(stage, renderables, protect_gate_children)
    # Material identity + locality + shadow casting are required to preserve appearance.
    # Spatial chunks preserve frustum culling; batch across an entire level would not.
    var groups: Dictionary = {}
    for item in renderables:
        if item.mesh == null or item.mesh.get_surface_count() != 1:
            continue
        if item.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
            continue
        var material: Material = item.material_override
        if material == null:
            material = item.mesh.surface_get_material(0)
        if material == null:
            continue
        if material is BaseMaterial3D:
            var base := material as BaseMaterial3D
            if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
                continue
        var pos: Vector3 = item.global_position
        var shadow: bool = item.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        var key := "%d:%d:%d:%d:%d" % [
            material.get_instance_id(),
            int(floor(pos.x / CHUNK_METERS)),
            int(floor(pos.z / CHUNK_METERS)),
            int(floor(pos.y / 110.0)),
            int(shadow)
        ]
        if not groups.has(key):
            groups[key] = {"material": material, "members": [], "shadow": shadow}
        groups[key]["members"].append(item)

    var old_count := renderables.size()
    var merged_count := 0
    var resulting_batches := 0
    var batch_holder := Node3D.new()
    batch_holder.name = "CompiledStaticBatches"
    stage.add_child(batch_holder)
    var batch_index := 0
    for key in groups.keys():
        var data: Dictionary = groups[key]
        var items: Array = data["members"]
        if items.size() < BATCH_THRESHOLD:
            continue
        var tool := SurfaceTool.new()
        tool.begin(Mesh.PRIMITIVE_TRIANGLES)
        for item in items:
            var mi := item as MeshInstance3D
            # Strip parent transforms, preserving every source vertex in stage space.
            var transform := stage.global_transform.affine_inverse() * mi.global_transform
            tool.append_from(mi.mesh, 0, transform)
        var final_mesh := tool.commit()
        if final_mesh == null or final_mesh.get_surface_count() == 0:
            error_count += 1
            continue
        var result := MeshInstance3D.new()
        result.name = "Batch_%03d" % batch_index
        batch_index += 1
        result.mesh = final_mesh
        result.material_override = data["material"]
        result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(data["shadow"]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        batch_holder.add_child(result)
        for item in items:
            (item as MeshInstance3D).free()
        resulting_batches += 1
        merged_count += items.size()
    # Every 3+ merged source renderables become exactly one draw unit.
    return {
        "initial_meshes": old_count,
        "merged_meshes": merged_count,
        "static_batches": resulting_batches,
        "estimated_meshes_after": old_count - merged_count + resulting_batches,
        "batch_errors": error_count
    }


func _collect_meshes(node: Node, output: Array[MeshInstance3D], skip_gates: bool) -> void:
    for child in node.get_children():
        if skip_gates and child.name.begins_with("Gate_"):
            continue
        if child is MeshInstance3D:
            output.append(child)
        _collect_meshes(child, output, skip_gates)
