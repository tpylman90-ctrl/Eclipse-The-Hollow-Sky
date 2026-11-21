extends Node3D
## Original lightweight arcade combat: aiming, projectiles, aerial enemies, bosses and drops.
## No physics-body spam: timed, analytic 3D collisions keep Android draw/CPU costs low.

signal enemy_destroyed(points: int, salvage: int, elite: bool)
signal plasma_fired
signal hostile_struck
signal player_damaged(amount: int)
signal supply_collected(kind: String)

var world
var ship
var sector := 1
var weapon_level := 0
var hostiles: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var supplies: Array[Dictionary] = []
var timer := 0.0
var next_fire := 0.0
var rng := RandomNumberGenerator.new()
var cyan_mat: StandardMaterial3D
var enemy_mat: StandardMaterial3D
var armor_mat: StandardMaterial3D
var elite_mat: StandardMaterial3D
var enemy_glow: StandardMaterial3D
var heal_mat: StandardMaterial3D
var ammo_mesh: CylinderMesh
var hostile_mesh: CylinderMesh
var body_mesh: SphereMesh
var wing_mesh: BoxMesh
var tiny_mesh: SphereMesh


func _ready() -> void:
    cyan_mat = _glow(Color("#76fff2"), 3.1)
    enemy_mat = _glow(Color("#ff704b"), 3.0)
    elite_mat = _glow(Color("#e5a5ff"), 4.0)
    enemy_glow = _glow(Color("#ffae53"), 2.8)
    heal_mat = _glow(Color("#73ffad"), 3.0)
    armor_mat = StandardMaterial3D.new()
    armor_mat.albedo_color = Color("#405869")
    armor_mat.metallic = 0.72
    armor_mat.roughness = 0.27
    ammo_mesh = CylinderMesh.new()
    ammo_mesh.top_radius = 0.16
    ammo_mesh.bottom_radius = 0.25
    ammo_mesh.height = 2.1
    ammo_mesh.radial_segments = 7
    hostile_mesh = CylinderMesh.new()
    hostile_mesh.top_radius = 0.19
    hostile_mesh.bottom_radius = 0.44
    hostile_mesh.height = 2.4
    hostile_mesh.radial_segments = 6
    body_mesh = SphereMesh.new()
    body_mesh.radius = 1.17
    body_mesh.height = 2.34
    body_mesh.radial_segments = 12
    body_mesh.rings = 8
    wing_mesh = BoxMesh.new()
    wing_mesh.size = Vector3(5.2, 0.19, 0.65)
    tiny_mesh = SphereMesh.new()
    tiny_mesh.radius = 0.49
    tiny_mesh.height = 0.98
    tiny_mesh.radial_segments = 10
    tiny_mesh.rings = 6


func _glow(tint: Color, power: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.emission_enabled = true
    material.emission = tint
    material.emission_energy_multiplier = power
    return material


func _mesh(parent: Node3D, shape: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.mesh = shape
    part.position = at
    part.material_override = mat
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(part)
    return part


func bind(w: Node3D, craft: Node3D) -> void:
    world = w
    ship = craft


func reset_sector(new_sector: int, new_weapon_level: int) -> void:
    for item in hostiles:
        (item["node"] as Node3D).queue_free()
    for bullet in shots:
        (bullet["node"] as Node3D).queue_free()
    for supply in supplies:
        (supply["node"] as Node3D).queue_free()
    hostiles.clear()
    shots.clear()
    supplies.clear()
    sector = new_sector
    weapon_level = new_weapon_level
    timer = 0.0
    next_fire = 0.0
    rng.seed = 93811 + sector * 817
    var count_per_gate := mini(3, 1 + int(sector / 2))
    for gate_i in range(world.gates.size()):
        var center: Vector3 = world.gates[gate_i].position
        for count in range(count_per_gate):
            var x: float = center.x + (float(count) - float(count_per_gate - 1) * 0.5) * 15.0 + rng.randf_range(-9.0, 9.0)
            var y: float = center.y + rng.randf_range(-6.0, 9.0)
            var z: float = center.z - 12.0 - float(count) * 16.0 - rng.randf_range(0.0, 17.0)
            _spawn_hostile(Vector3(x, y, z), false)
        if gate_i == 4:
            _spawn_hostile(center + Vector3(rng.randf_range(-12.0, 12.0), 4.0, -47.0), true)
        if gate_i % 2 == 1:
            _spawn_supply(center + Vector3(0.0, 0.0, 18.0), "shield" if gate_i == 3 else "energy")
        if gate_i % 2 == 0:
            _spawn_supply(center + Vector3(rng.randf_range(-5.0, 5.0), -3.0, 34.0), "salvage")


func _spawn_hostile(at: Vector3, elite: bool) -> void:
    var root := Node3D.new()
    root.name = "AetherWarden" if elite else "HunterDrone"
    root.position = at
    add_child(root)
    var scale_factor := 2.25 if elite else 1.0
    root.scale = Vector3.ONE * scale_factor
    _mesh(root, body_mesh, Vector3.ZERO, armor_mat)
    var core := _mesh(root, tiny_mesh, Vector3(0.0, 0.16, -0.97), elite_mat if elite else enemy_mat)
    core.scale = Vector3(1.4, 1.4, 1.0)
    _mesh(root, wing_mesh, Vector3(0.0, -0.12, 0.34), armor_mat)
    for side in [-1.0, 1.0]:
        var nozzle := _mesh(root, hostile_mesh, Vector3(side * 2.4, -0.19, 0.44), enemy_glow)
        nozzle.rotation.x = PI * 0.5
        nozzle.scale = Vector3(0.8, 0.8, 0.56)
    if elite:
        var crown := TorusMesh.new()
        crown.inner_radius = 2.7
        crown.outer_radius = 2.84
        crown.rings = 32
        crown.ring_segments = 6
        var ring := _mesh(root, crown, Vector3(0.0, 0.3, 0.2), elite_mat)
        ring.rotation.x = PI * 0.5
    hostiles.append({
        "node": root,
        "origin": at,
        "hp": (12 + sector * 3) if elite else (2 + mini(sector / 2, 3)),
        "elite": elite,
        "phase": rng.randf_range(0.0, TAU),
        "frequency": rng.randf_range(0.63, 1.3),
        "cooldown": rng.randf_range(0.55, 2.5)
    })


func _spawn_supply(at: Vector3, kind: String) -> void:
    var root := Node3D.new()
    root.position = at
    root.name = "Supply_" + kind
    add_child(root)
    var sphere := SphereMesh.new()
    sphere.radius = 1.4
    sphere.height = 2.8
    sphere.radial_segments = 12
    sphere.rings = 8
    _mesh(root, sphere, Vector3.ZERO, heal_mat if kind == "shield" else (cyan_mat if kind == "energy" else enemy_glow))
    var torus := TorusMesh.new()
    torus.inner_radius = 2.2
    torus.outer_radius = 2.4
    torus.rings = 28
    torus.ring_segments = 5
    var halo := _mesh(root, torus, Vector3.ZERO, cyan_mat)
    halo.rotation.x = PI / 2.0
    supplies.append({"node": root, "kind": kind, "phase": rng.randf_range(0.0, TAU)})


func update_combat(delta: float) -> void:
    timer += delta
    next_fire = maxf(0.0, next_fire - delta)
    if Input.is_action_pressed("fire") and next_fire <= 0.0:
        fire()
        next_fire = maxf(0.13, 0.33 - float(weapon_level) * 0.052)
    _update_hostiles(delta)
    _update_shots(delta)
    _update_supplies(delta)


func fire() -> void:
    if ship == null:
        return
    var aim := Vector3.FORWARD
    var nearest_angle := 0.955
    var origin: Vector3 = ship.global_position + Vector3(0.0, -0.07, -4.3)
    for data in hostiles:
        var hostile: Node3D = data["node"]
        var to_enemy: Vector3 = hostile.global_position - origin
        if to_enemy.z < -5.0 and to_enemy.length() < 170.0:
            var alignment: float = to_enemy.normalized().dot(Vector3.FORWARD)
            if alignment > nearest_angle:
                nearest_angle = alignment
                aim = to_enemy.normalized()
    plasma_fired.emit()
    var shot_count := 2 if weapon_level >= 2 else 1
    for i in range(shot_count):
        var side: float = float(i) * 2.0 - float(shot_count - 1)
        _spawn_shot(origin + Vector3(side * 0.9, 0.0, 0.0), aim, false)
    if shots.size() > 90:
        _erase_shot(0)


func _spawn_shot(at: Vector3, direction: Vector3, hostile: bool) -> void:
    var bullet := MeshInstance3D.new()
    bullet.mesh = ammo_mesh
    bullet.position = at
    bullet.material_override = enemy_mat if hostile else cyan_mat
    bullet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var velocity: Vector3 = direction.normalized() * (62.0 if hostile else 190.0)
    bullet.quaternion = Quaternion(Vector3.UP, velocity.normalized())
    add_child(bullet)
    shots.append({
        "node": bullet,
        "velocity": velocity,
        "hostile": hostile,
        "life": 2.4 if hostile else 1.8
    })


func _update_hostiles(delta: float) -> void:
    for i in range(hostiles.size() - 1, -1, -1):
        var data: Dictionary = hostiles[i]
        var n: Node3D = data["node"]
        var base: Vector3 = data["origin"]
        var t: float = timer * float(data["frequency"]) + float(data["phase"])
        n.position = base + Vector3(sin(t) * 4.6, cos(t * 1.18) * 3.4, sin(t * 0.43) * 1.7)
        n.rotation.z = sin(t) * 0.19
        n.rotation.y = sin(t * 0.6) * 0.20
        var dz: float = ship.global_position.z - n.global_position.z
        if dz < -43.0:
            n.queue_free()
            hostiles.remove_at(i)
            continue
        data["cooldown"] = float(data["cooldown"]) - delta
        if dz > 22.0 and dz < 138.0 and float(data["cooldown"]) <= 0.0:
            var toward: Vector3 = ship.global_position + Vector3(0.0, 0.0, -3.0) - n.global_position
            if toward.length() > 1.0:
                _spawn_shot(n.global_position + Vector3(0.0, 0.0, -1.4), toward.normalized(), true)
            data["cooldown"] = rng.randf_range(1.35, 2.9) * (0.77 if bool(data["elite"]) else 1.0)


func _update_shots(delta: float) -> void:
    for i in range(shots.size() - 1, -1, -1):
        var data: Dictionary = shots[i]
        var bullet: Node3D = data["node"]
        var velocity: Vector3 = data["velocity"]
        bullet.position += velocity * delta
        data["life"] = float(data["life"]) - delta
        if float(data["life"]) <= 0.0:
            _erase_shot(i)
            continue
        if bool(data["hostile"]):
            if bullet.global_position.distance_to(ship.global_position) < 3.7:
                player_damaged.emit(1)
                _erase_shot(i)
        else:
            var struck := false
            for j in range(hostiles.size() - 1, -1, -1):
                var enemy_data: Dictionary = hostiles[j]
                var n: Node3D = enemy_data["node"]
                var radius: float = 6.3 if bool(enemy_data["elite"]) else 2.8
                if bullet.global_position.distance_to(n.global_position) < radius:
                    hostile_struck.emit()
                    enemy_data["hp"] = int(enemy_data["hp"]) - (1 + mini(weapon_level, 1))
                    struck = true
                    if int(enemy_data["hp"]) <= 0:
                        var boss: bool = bool(enemy_data["elite"])
                        enemy_destroyed.emit(2400 if boss else 300, 75 if boss else 15, boss)
                        n.queue_free()
                        hostiles.remove_at(j)
                    break
            if struck:
                _erase_shot(i)


func _erase_shot(index: int) -> void:
    if index < 0 or index >= shots.size():
        return
    var data: Dictionary = shots[index]
    (data["node"] as Node3D).queue_free()
    shots.remove_at(index)


func _update_supplies(delta: float) -> void:
    for i in range(supplies.size() - 1, -1, -1):
        var data: Dictionary = supplies[i]
        var node: Node3D = data["node"]
        node.rotation.y += delta * 1.34
        node.position.y += sin(timer * 2.5 + float(data["phase"])) * delta * 0.46
        if node.global_position.distance_to(ship.global_position) < 6.0:
            supply_collected.emit(str(data["kind"]))
            node.queue_free()
            supplies.remove_at(i)
        elif node.global_position.z > ship.global_position.z + 38.0:
            node.queue_free()
            supplies.remove_at(i)


func count_alive() -> int:
    return hostiles.size()
