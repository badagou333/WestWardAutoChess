extends SceneTree

func gather(node: Node, result: Array[Node]) -> void:
	result.append(node)
	for child in node.get_children():
		gather(child, result)

func _initialize() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var path := ProjectSettings.globalize_path("res://probe.glb")
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("GLB import failed: " + str(error))
		quit(1)
		return
	var model: Node = document.generate_scene(state)
	if model == null:
		push_error("GLB scene generation failed")
		quit(1)
		return
	root.add_child(model)
	var nodes: Array[Node] = []
	gather(model, nodes)
	var meshes := 0
	var skinned_meshes := 0
	var skeleton: Skeleton3D
	var player: AnimationPlayer
	for node in nodes:
		if node is MeshInstance3D:
			meshes += 1
			if node.skin != null:
				skinned_meshes += 1
		if node is Skeleton3D:
			skeleton = node
		if node is AnimationPlayer:
			player = node
	if skeleton == null or player == null:
		push_error("Missing skeleton or animation player")
		quit(1)
		return
	var clips := player.get_animation_list()
	var selected := ""
	for clip in clips:
		if clip != "RESET":
			selected = clip
			break
	var head := skeleton.find_bone("head")
	if selected.is_empty() or head < 0:
		push_error("Missing probe clip or head bone")
		quit(1)
		return
	player.play(selected)
	player.advance(0.0)
	var first := skeleton.get_bone_pose_rotation(head)
	player.advance(0.45)
	var second := skeleton.get_bone_pose_rotation(head)
	var delta := first.angle_to(second)
	var passed := meshes == 3 and skinned_meshes == 3 and skeleton.get_bone_count() == 2 and delta > 0.01
	var report := {
		"godot_version": Engine.get_version_info().string,
		"import_error": error,
		"mesh_instances": meshes,
		"skinned_meshes": skinned_meshes,
		"bone_count": skeleton.get_bone_count(),
		"animations": Array(clips),
		"tested_animation": selected,
		"animation_length_seconds": player.get_animation(selected).length,
		"head_pose_change_radians": delta,
		"passed": passed,
		"scope": "Headless import and animation data; no Godot graphical rendering or game integration"
	}
	var output := FileAccess.open("res://godot-result.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	print("GODOT_PROBE " + JSON.stringify(report))
	model.queue_free()
	quit(0 if passed else 1)
