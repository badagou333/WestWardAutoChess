extends "res://scripts/board_trial.gd"
## Main board's 2D depth presentation. The inherited simulation is unchanged.
const GroundProjection = preload("res://scripts/presentation/board_depth_projection.gd")
const DepthStage = preload("res://scripts/presentation/board_depth_stage.gd")
const DepthUI = preload("res://scripts/presentation/board_depth_ui.gd")
const DepthHUD = preload("res://scripts/presentation/board_depth_hud.gd")
const DirectionalView = preload("res://scripts/presentation/board_directional_view.gd")
const BODY_SCALE := 0.9
var stage

func _ready() -> void:
	super._ready()
	stage=DepthStage.new()
	stage.z_index=-100
	add_child(stage)
	stage.setup(self)
	# Shared events retain their release/contact clocks and draw in screen space.
	combat.z_index=1900

func display_center(cell: Vector2i) -> Vector2:
	return GroundProjection.center(cell)

func display_cell_at(pixel: Vector2) -> Vector2i:
	return GroundProjection.cell_at(pixel)

func _tick(delta: float) -> void:
	super._tick(delta)
	# A projectile can kill an actor after its final move interpolation but before
	# the inherited alive-only sorting pass. Freeze the death pose at that foot depth.
	for actor in actors:
		if is_instance_valid(actor.node): actor.node.z_index=int(actor.node.position.y)

func _register(id: String, key: String, node, friendly: bool, cell: Vector2i) -> void:
	super._register(id,key,node,friendly,cell)
	var pack: Dictionary=DirectionalView.load_pack(node.presentation.role)
	if not pack.is_empty():
		var previous=node.presentation
		var view=DirectionalView.new()
		view.copy_playback(previous,_record(id),pack)
		node.add_child(view)
		node.presentation=view
		previous.free()
	node.scale=Vector2.ONE*BODY_SCALE
	node.presentation.show_shadow=false
	for child in node.get_children():
		if child.get_script()==Style: child.free()
	var hud=DepthHUD.new()
	hud.setup(node,friendly,id)
	hud.z_as_relative=false
	hud.z_index=2000
	node.add_child(hud)

func _default_face(node, friendly: bool) -> void:
	if node.presentation.has_method("keep_board_direction"):
		node.presentation.keep_board_direction()
		return
	super._default_face(node,friendly)

func _create_ui() -> void:
	board_overlay=Node2D.new()
	board_overlay.z_index=1
	add_child(board_overlay)
	ui=DepthUI.new()
	add_child(ui)
	ui.setup(self)
	for field in ["title_label","status_label","info_label","enemies_label","start_button","retry_button","pause_button","speed_button","withdraw_button","roster_buttons","formation_buttons"]:
		set(field,ui.get(field))

func _draw() -> void:
	pass # The projected stage owns ground, thickness and cell highlights.

func _draw_overlay() -> void:
	pass

func _input(event: InputEvent) -> void:
	# F is the old monk sample comparison, available only in the legacy scene.
	if event is InputEventKey and event.keycode==KEY_F: return
	# A result panel intercepts gestures over itself, while retry and other
	# controls outside it remain usable. Match the existing help modal policy.
	if is_instance_valid(ui) and ui.result_panel.visible and event is InputEventMouseButton:
		if ui.result_panel.get_global_rect().has_point(event.position): return
	super._input(event)
