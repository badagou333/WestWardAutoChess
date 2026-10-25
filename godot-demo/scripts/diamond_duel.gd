extends "res://scripts/audio_trial.gd"
## D-20261018-002: two fixed instances on one shared complete-diamond mask.
const Diamond = preload("res://scripts/data/diamond_duel_board.gd")
const DuelUI = preload("res://scripts/presentation/diamond_duel_ui.gd")
const DuelStage = preload("res://scripts/presentation/diamond_duel_stage.gd")
const DuelView = preload("res://scripts/presentation/diamond_duel_view.gd")
const DuelHUD = preload("res://scripts/presentation/board_depth_hud.gd")
var stage
var artwork_ok := true

func _ready() -> void:
	super._ready()
	audio_feedback.enabled=false
	stage=DuelStage.new()
	add_child(stage)
	stage.setup(self)

func valid_cell(cell: Vector2i) -> bool: return Diamond.valid(cell)
func legal_cells() -> Array[Vector2i]: return Diamond.cells()
func display_center(cell: Vector2i) -> Vector2: return Diamond.center(cell)
func display_cell_at(pixel: Vector2) -> Vector2i: return Diamond.cell_at(pixel)
func display_move(first: Vector2i, last: Vector2i, fraction: float) -> Vector2:
	return Diamond.point(Vector2(first).lerp(Vector2(last),fraction))

func sync_display_actor(actor: Dictionary) -> void:
	if is_instance_valid(actor.node):
		actor.node.scale=Vector2.ONE
		actor.node.z_index=int(actor.node.position.y)

func _default_face(node, _friendly: bool) -> void:
	if not is_instance_valid(node) or node.presentation==null: return
	for other in actors:
		if other.node!=node and is_instance_valid(other.node):
			node.presentation.face(other.node.position-node.position)
			return

func _register(id: String, key: String, node, friendly: bool, cell: Vector2i) -> void:
	super._register(id,key,node,friendly,cell)
	var actor: Dictionary=_record(id)
	actor.invalid_cell=Diamond.INVALID
	actor.step_hint=Diamond.INVALID
	actor.route_goal=Diamond.INVALID
	var previous=node.presentation
	var view:=DuelView.new()
	if not view.attach(previous,actor):
		artwork_ok=false
		push_error("D002 artwork missing or invalid; old side-view fallback is forbidden")
		previous.hide()
		view.free()
		return
	for child in node.get_children():
		if child.get_script()==Style: child.free()
	node.presentation=view
	previous.free()
	view.z_index=-1
	node.add_child(view)
	node.scale=Vector2.ONE
	var hud:=DuelHUD.new()
	# The HUD reads the new per-frame alpha bounds, not old atlas dimensions.
	hud.friendly=friendly
	hud.actor_id=id
	hud.caption="狼" if not friendly else ""
	hud.z_as_relative=false
	hud.z_index=2000
	node.add_child(hud)

func _reset_roster() -> void:
	super._reset_roster()
	for actor in actors: _default_face(actor.node,actor.friendly)

func reset_default() -> void:
	if phase!=Phase.DEPLOY: return
	setup_specs.assign([
		{"id":"monk","key":"guard_monk","friendly":true,"cell":Vector2i(-3,0),"initial_hp_ratio":1.0},
		{"id":"wolf","key":"wolf","friendly":false,"cell":Vector2i(3,0),"initial_hp_ratio":1.0}])
	start_specs.clear()
	_reset_roster()
	_notice("请选择棍僧或山狼，再点完整菱格布置 · 两方各一名")

func add_units(_friendly: bool, _key: String, _count := 1) -> bool:
	_notice("本小样固定棍僧、山狼各一名")
	return false

func remove_selected() -> bool: return false
func clear_trial() -> void: pass
func healing_preset() -> void: pass
func set_initial_health(_id: String, _ratio: float) -> bool: return false
func set_monk_sample(_enabled: bool) -> void: pass
func withdraw() -> void: pass

func start_battle() -> bool:
	if not artwork_ok or setup_specs.size()!=2: return false
	var monk: Dictionary=_spec("monk")
	var wolf: Dictionary=_spec("wolf")
	if monk.is_empty() or wolf.is_empty() or monk.key!="guard_monk" or wolf.key!="wolf": return false
	if not monk.friendly or wolf.friendly or monk.initial_hp_ratio!=1.0 or wolf.initial_hp_ratio!=1.0: return false
	if not super.start_battle(): return false
	for actor in actors: _default_face(actor.node,actor.friendly)
	_notice("双方真实自动对打 · 每格0.50秒 · 暂停时同样锁阵")
	return true

func return_to_setup() -> void:
	super.return_to_setup()
	_notice("已恢复开战前布置 · 可重新摆放双方")

func report() -> Dictionary:
	var result: Dictionary=super.report()
	result.config="diamond-duel-v1"
	result["coordinates"]="integer axial cell centers; initial_cell retains inherited +1 report convention"
	result["legal_cell_count"]=Diamond.cells().size()
	return result

func _create_ui() -> void:
	board_overlay=Node2D.new()
	add_child(board_overlay)
	ui=DuelUI.new()
	add_child(ui)
	ui.setup(self)
	for field in ["title_label","status_label","info_label","enemies_label","start_button","retry_button","pause_button","speed_button","withdraw_button"]: set(field,ui.get(field))

func _draw() -> void: pass
func _draw_overlay() -> void: pass
