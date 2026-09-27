class_name CrewActor3D
extends Node3D
## Articulated 3D actor with a joint hierarchy and authored AnimationPlayer clips.
## No sprites, billboards or screen-space character positions.
var person: CrewMember
var rig: Node3D
var animation: AnimationPlayer
var joints: Dictionary = {}
var ring: MeshInstance3D
var tool: Node3D
var path := PackedVector3Array()
var path_station: String = ""
var active_clip: String = ""
var moving: bool = false
var skin: Color
var uniform: Color


func setup(member: CrewMember, index: int, station_slot: int = 0) -> void:
	person = member
	name = member.id.to_pascal_case()
	skin = [
		Color("ad7d5e"),
		Color("c99875"),
		Color("97664d"),
		Color("81583f"),
		Color("bf9275"),
		Color("b99884"),
		Color("d5ac8c")
	][index]
	uniform = Color("c47c35") if member.id != "vale" else Color("c9d5d0")
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	var hips := joint("Hips", rig, Vector3(0, 0.88, 0))
	InteriorProps.box(hips, Vector3.ZERO, Vector3(0.36, 0.23, 0.25), Color("343d49"))
	var chest := joint("Chest", hips, Vector3(0, 0.18, 0))
	var torso := InteriorProps.box(chest, Vector3(0, 0.20, 0), Vector3(0.47, 0.47, 0.29), uniform)
	torso.scale.x = 0.93 if index % 2 else 1.0
	InteriorProps.box(chest, Vector3(0, 0.18, -0.161), Vector3(0.085, 0.42, 0.033), Color("303a46"))
	InteriorProps.box(
		chest, Vector3(-0.15, 0.29, -0.17), Vector3(0.09, 0.13, 0.043), Color("c5d0cb")
	)
	for x in [-0.145, 0.145]:
		InteriorProps.box(
			chest, Vector3(x, 0.10, -0.17), Vector3(0.115, 0.13, 0.055), uniform.darkened(0.20)
		)
		InteriorProps.box(
			chest, Vector3(x, 0.04, 0.15), Vector3(0.10, 0.13, 0.075), Color("535660")
		)
	InteriorProps.box(hips, Vector3(0, 0.08, 0), Vector3(0.41, 0.073, 0.30), Color("182331"))
	InteriorProps.box(
		hips, Vector3(0, 0.08, -0.17), Vector3(0.12, 0.073, 0.026), InteriorProps.EDGE
	)
	var neck := joint("Neck", chest, Vector3(0, 0.49, 0))
	capsule(neck, Vector3(0, 0.045, 0), 0.074, 0.12, skin)
	var head := joint("Head", neck, Vector3(0, 0.17, 0))
	var skull := MeshKit.sphere(head, Vector3.ZERO, 0.158, skin)
	skull.scale = Vector3(0.91, 1.16, 0.94)
	MeshKit.sphere(head, Vector3(0, -0.015, -0.145), 0.040, skin.lightened(0.05))
	for x in [-0.157, 0.157]:
		MeshKit.sphere(head, Vector3(x, 0.0, 0), 0.039, skin)
	for x in [-0.056, 0.056]:
		MeshKit.sphere(head, Vector3(x, 0.039, -0.139), 0.018, Color("15191e"))
		InteriorProps.box(
			head, Vector3(x, 0.071, -0.137), Vector3(0.045, 0.018, 0.014), Color("38302b")
		)
	InteriorProps.box(
		head, Vector3(0, -0.077, -0.138), Vector3(0.063, 0.011, 0.012), skin.darkened(0.3)
	)
	var hair := MeshKit.sphere(
		head,
		Vector3(0, 0.075, 0.031),
		0.153,
		[Color("332d2d"), Color("8b8983"), Color("251f24"), Color("342c24")][index % 4]
	)
	hair.scale = Vector3(1, 0.65, 0.92)
	if index == 2 or index == 4:
		MeshKit.sphere(head, Vector3(0, 0.055, 0.17), 0.078, Color("332822"))
	for side in [-1, 1]:
		var suffix := "L" if side < 0 else "R"
		var shoulder := joint("Shoulder" + suffix, chest, Vector3(side * 0.28, 0.36, 0))
		capsule(shoulder, Vector3(0, -0.13, 0), 0.093, 0.32, uniform)
		InteriorProps.box(shoulder, Vector3(0, 0.01, 0), Vector3(0.23, 0.14, 0.30), Color("697279"))
		var elbow := joint("Elbow" + suffix, shoulder, Vector3(0, -0.29, 0))
		capsule(elbow, Vector3(0, -0.115, 0), 0.071, 0.28, Color("35404b"))
		InteriorProps.box(elbow, Vector3(0, -0.15, -0.065), Vector3(0.115, 0.12, 0.040), uniform)
		var wrist := joint("Wrist" + suffix, elbow, Vector3(0, -0.25, 0))
		capsule(wrist, Vector3(0, -0.045, 0), 0.068, 0.14, skin)
		var hip := joint("Hip" + suffix, hips, Vector3(side * 0.12, -0.06, 0))
		capsule(hip, Vector3(0, -0.18, 0), 0.102, 0.39, Color("313c4a"))
		var knee := joint("Knee" + suffix, hip, Vector3(0, -0.36, 0))
		capsule(knee, Vector3(0, -0.16, 0), 0.079, 0.35, Color("364453"))
		InteriorProps.box(
			knee, Vector3(0, 0.0, -0.084), Vector3(0.16, 0.16, 0.072), Color("7b807e")
		)
		InteriorProps.box(
			knee, Vector3(0, -0.34, -0.065), Vector3(0.19, 0.16, 0.34), Color("202832")
		)
		InteriorProps.box(
			knee, Vector3(0, -0.409, -0.065), Vector3(0.20, 0.037, 0.35), Color("101720")
		)
	tool = Node3D.new()
	tool.name = "HandTool"
	joints.WristR.add_child(tool)
	InteriorProps.box(tool, Vector3(0, -0.09, -0.02), Vector3(0.09, 0.20, 0.10), InteriorProps.GOLD)
	InteriorProps.pipe(
		tool, Vector3(0, -0.03, -0.02), Vector3(0, -0.03, -0.27), 0.027, InteriorProps.EDGE
	)
	tool.visible = false
	for node in joints.values():
		MeshKit.bake(node)
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.35
	mesh.outer_radius = 0.37
	mesh.rings = 40
	mesh.ring_segments = 6
	ring = MeshKit.part(self, mesh, Vector3(0, 0.05, 0), Color("80d9df"), 1.1)
	var hit := StaticBody3D.new()
	hit.collision_layer = 4
	hit.set_meta("crew", member.id)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.85
	collision.shape = shape
	collision.position.y = 0.87
	hit.add_child(collision)
	add_child(hit)
	animation = AnimationPlayer.new()
	animation.name = "AnimationPlayer"
	add_child(animation)
	create_animations()
	position = (
		member.deck_position
		if member.has_deck_position
		else InteriorLayout.station_point(member.station, station_slot)
	)
	member.deck_position = position
	member.has_deck_position = true
	InteriorStyle.apply(self)


func joint(title: String, parent: Node3D, point: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = title
	node.position = point
	parent.add_child(node)
	joints[title] = node
	return node


func capsule(parent: Node3D, point: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 4
	var part := MeshKit.part(parent, mesh, point, color)
	var mat := MeshKit.material(color)
	mat.metallic = 0.0
	part.material_override = mat


func rotation_track(clip: Animation, joint_name: String, values: Array[Vector3]) -> void:
	var track := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, str(get_path_to(joints[joint_name])) + ":rotation")
	for i in values.size():
		clip.track_insert_key(track, float(i) / (values.size() - 1) * clip.length, values[i])


func position_track(clip: Animation, joint_name: String, values: Array[Vector3]) -> void:
	var old_track := clip.find_track(
		str(get_path_to(joints[joint_name])) + ":position", Animation.TYPE_VALUE
	)
	if old_track >= 0:
		clip.remove_track(old_track)
	var track := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, str(get_path_to(joints[joint_name])) + ":position")
	for i in values.size():
		clip.track_insert_key(track, float(i) / (values.size() - 1) * clip.length, values[i])


func create_animations() -> void:
	var library := AnimationLibrary.new()
	for key in ["idle", "walk", "console", "repair", "garden", "medical", "cook", "guard", "rest"]:
		var clip := Animation.new()
		clip.length = 0.82 if key == "walk" else 2.4
		clip.loop_mode = Animation.LOOP_LINEAR
		for title in joints:
			rotation_track(clip, title, [Vector3.ZERO, Vector3.ZERO])
		# Replace a joint's neutral track when authoring its visible activity.
		position_track(
			clip, "Hips", [Vector3(0, 0.88, 0), Vector3(0, 0.892, 0), Vector3(0, 0.88, 0)]
		)
		if key == "walk":
			for suffix in ["L", "R"]:
				var sign_value := 1.0 if suffix == "L" else -1.0
				animate_rotation(
					clip,
					"Hip" + suffix,
					[
						Vector3(0.56 * sign_value, 0, 0),
						Vector3(-0.56 * sign_value, 0, 0),
						Vector3(0.56 * sign_value, 0, 0)
					]
				)
				animate_rotation(
					clip,
					"Knee" + suffix,
					[
						Vector3(-0.08 if suffix == "L" else -0.8, 0, 0),
						Vector3(-0.80 if suffix == "L" else -0.08, 0, 0),
						Vector3(-0.08 if suffix == "L" else -0.8, 0, 0)
					]
				)
				animate_rotation(
					clip,
					"Shoulder" + suffix,
					[
						Vector3(-0.46 * sign_value, 0, 0),
						Vector3(0.46 * sign_value, 0, 0),
						Vector3(-0.46 * sign_value, 0, 0)
					]
				)
				animate_rotation(
					clip,
					"Elbow" + suffix,
					[Vector3(-0.18, 0, 0), Vector3(-0.30, 0, 0), Vector3(-0.18, 0, 0)]
				)
			animate_rotation(
				clip,
				"Chest",
				[Vector3(0, 0.05, 0.02), Vector3(0, -0.05, -0.02), Vector3(0, 0.05, 0.02)]
			)
		elif key == "rest":
			position_track(
				clip, "Hips", [Vector3(0, 0.52, 0), Vector3(0, 0.525, 0), Vector3(0, 0.52, 0)]
			)
			for suffix in ["L", "R"]:
				animate_rotation(clip, "Hip" + suffix, [Vector3(1.2, 0, 0), Vector3(1.2, 0, 0)])
				animate_rotation(clip, "Knee" + suffix, [Vector3(-1.5, 0, 0), Vector3(-1.5, 0, 0)])
				animate_rotation(
					clip,
					"Shoulder" + suffix,
					[Vector3(-0.3, 0, 0), Vector3(-0.35, 0, 0), Vector3(-0.3, 0, 0)]
				)
			animate_rotation(
				clip, "Head", [Vector3(0.16, 0, 0), Vector3(0.20, 0, 0), Vector3(0.16, 0, 0)]
			)
		elif key in ["console", "medical", "cook", "repair", "garden"]:
			var lean := 0.24 if key in ["garden", "repair"] else 0.08
			animate_rotation(
				clip,
				"Chest",
				[Vector3(-lean, 0, 0), Vector3(-lean - 0.06, 0.06, 0), Vector3(-lean, 0, 0)]
			)
			for suffix in ["L", "R"]:
				var base := 0.5 if suffix == "L" else 0.8
				animate_rotation(
					clip,
					"Shoulder" + suffix,
					[Vector3(base, 0, 0), Vector3(base - 0.18, 0.12, 0), Vector3(base, 0, 0)]
				)
				animate_rotation(
					clip,
					"Elbow" + suffix,
					[Vector3(0.75, 0, 0), Vector3(0.55, 0, 0), Vector3(0.75, 0, 0)]
				)
				animate_rotation(
					clip,
					"Wrist" + suffix,
					[Vector3(0, 0, -0.15), Vector3(0.15, 0, 0.2), Vector3(0, 0, -0.15)]
				)
			if key == "console":
				animate_rotation(
					clip,
					"ShoulderL",
					[Vector3(.65, 0, -.08), Vector3(.48, 0, -.08), Vector3(.65, 0, -.08)]
				)
				animate_rotation(
					clip,
					"ShoulderR",
					[Vector3(.48, 0, .08), Vector3(.65, 0, .08), Vector3(.48, 0, .08)]
				)
				animate_rotation(
					clip,
					"Head",
					[Vector3(-.12, -.15, 0), Vector3(-.06, .15, 0), Vector3(-.12, -.15, 0)]
				)
			elif key == "cook":
				animate_rotation(
					clip,
					"ElbowR",
					[
						Vector3(.65, -.20, 0),
						Vector3(.95, 0, -.10),
						Vector3(.65, .20, 0),
						Vector3(.40, 0, .10),
						Vector3(.65, -.20, 0)
					]
				)
				animate_rotation(
					clip, "WristR", [Vector3(.1, 0, -.2), Vector3(-.1, 0, .2), Vector3(.1, 0, -.2)]
				)
				animate_rotation(
					clip,
					"ElbowL",
					[Vector3(.95, 0, -.2), Vector3(.98, 0, -.2), Vector3(.95, 0, -.2)]
				)
			elif key == "medical":
				animate_rotation(
					clip,
					"ShoulderL",
					[Vector3(.75, 0, -.15), Vector3(.76, 0, -.15), Vector3(.75, 0, -.15)]
				)
				animate_rotation(
					clip,
					"ShoulderR",
					[Vector3(.55, -.2, .1), Vector3(.90, .1, .1), Vector3(.55, -.2, .1)]
				)
				animate_rotation(
					clip,
					"Head",
					[Vector3(-.2, -.15, 0), Vector3(-.35, .15, 0), Vector3(-.2, -.15, 0)]
				)
			elif key == "repair":
				animate_rotation(
					clip, "ElbowR", [Vector3(.45, 0, 0), Vector3(1.0, 0, 0), Vector3(.45, 0, 0)]
				)
				animate_rotation(
					clip,
					"Chest",
					[Vector3(-.18, -.08, 0), Vector3(-.28, .08, 0), Vector3(-.18, -.08, 0)]
				)
			if key == "garden":
				animate_rotation(clip, "HipR", [Vector3(0.3, 0, 0), Vector3(0.3, 0, 0)])
				animate_rotation(
					clip,
					"KneeR",
					[Vector3(-0.50, 0, 0), Vector3(-0.55, 0, 0), Vector3(-0.50, 0, 0)]
				)
		else:
			animate_rotation(
				clip, "Head", [Vector3(0, -0.2, 0), Vector3(0.035, 0.2, 0), Vector3(0, -0.2, 0)]
			)
			animate_rotation(
				clip,
				"ShoulderL",
				[Vector3(0, 0, -0.04), Vector3(0.03, 0, -0.06), Vector3(0, 0, -0.04)]
			)
		library.add_animation(key, clip)
	animation.add_animation_library("", library)


func animate_rotation(clip: Animation, title: String, values: Array[Vector3]) -> void:
	var track := clip.find_track(
		str(get_path_to(joints[title])) + ":rotation", Animation.TYPE_VALUE
	)
	if track >= 0:
		clip.remove_track(track)
	rotation_track(clip, title, values)


func play_pose(clip: String, clock: float) -> void:
	if active_clip != clip:
		# The simulation clock explicitly seeks each pose, so no real-time blend clock
		# may retain an old pose while the AnimationPlayer is paused between samples.
		animation.play(clip, 0.0)
		active_clip = clip
	animation.seek(fmod(clock, animation.get_animation(clip).length), true)
	animation.pause()
	tool.visible = clip == "repair"


func sync(
	state: InteriorState, nav: InteriorNavigation, selected: bool, hovered: bool, delta: float
) -> void:
	visible = not person.away
	ring.visible = selected or hovered
	if not visible:
		return
	var destination := nav.work_position(state, person.station, person.id)
	if not destination.is_finite():
		destination = person.deck_position
	var clock := state.sim_seconds + state.accumulator
	if person.travel_remaining > 0:
		if (
			path_station != person.station
			or path.is_empty()
			or person.transfer_path.is_empty()
			or (not person.transfer_path.is_empty() and path != person.transfer_path)
		):
			path = (
				person.transfer_path
				if not person.transfer_path.is_empty()
				else nav.route(InteriorLayout.station_point(person.previous_station), destination)
			)
			if person.transfer_path.is_empty() and not path.is_empty():
				var elapsed := person.travel_duration - person.travel_remaining
				var duration := maxf(1, InteriorNavigation.length(path) / 1.55)
				person.begin_route(path, duration)
				person.travel_remaining = maxf(0, duration - elapsed)
			path_station = person.station
		var fraction := (
			1.0 - maxf(0, person.travel_remaining - state.accumulator) / person.travel_duration
		)
		var point := InteriorNavigation.sample(path, fraction)
		var ahead := InteriorNavigation.sample(path, minf(1, fraction + 0.015))
		var direction := ahead - point
		position = point
		if direction.length() > 0.001:
			rotation.y = lerp_angle(
				rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * 12)
			)
		rig.position = rig.position.lerp(Vector3.ZERO, minf(1, delta * 8))
		moving = true
		play_pose("walk", clock)
	else:
		if moving:
			position = person.deck_position if person.has_deck_position else destination
			moving = false
			path.clear()
			path_station = ""
		elif person.has_deck_position:
			position = person.deck_position
		else:
			position = destination
		person.deck_position = position
		person.has_deck_position = true
		rotation.y = lerp_angle(
			rotation.y, float(InteriorLayout.ROOMS[person.station].facing), minf(1, delta * 5)
		)
		var poses := {
			"bridge": "console",
			"quarters": "rest",
			"mess": "cook",
			"medbay": "medical",
			"engineering": "repair",
			"fabrication": "repair",
			"storage": "idle",
			"hydroponics": "garden",
			"airlock": "guard"
		}
		rig.position = rig.position.lerp(
			(
				Vector3(0, 0.20, 0.65)
				if person.station == "quarters" and not person.off_station
				else Vector3.ZERO
			),
			minf(1, delta * 4)
		)
		play_pose(
			(
				poses[person.station]
				if (
					not person.off_station
					and person.health > 15
					and (state.powered[person.station] or person.station == "quarters")
				)
				else "idle"
			),
			clock
		)
