extends SceneTree
## Projection and full simulation parity. Logical event injection is not OS input.
const Config = preload("res://scripts/data/board_trial_config.gd")
const GroundProjection = preload("res://scripts/presentation/board_depth_projection.gd")
const SUPPORT := [Vector2i(2,4),Vector2i(5,4),Vector2i(4,3),Vector2i(4,5),Vector2i(3,4),Vector2i(4,4)]
var failures := 0
var checks := 0
var cases := []
var output_path := "/tmp/board-perspective-20261017-depth.json"

class MotionFixture extends "res://scripts/board_depth.gd":
	func _brain(_actor: Dictionary, _delta: float) -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func fresh(depth := true, profile := "bear"):
	var game=load("res://scenes/board_trial.tscn").instantiate() if depth else load("res://scripts/board_trial.gd").new()
	game.enemy_profile=profile
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	return game

func fixture():
	var game=MotionFixture.new()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	return game

func projection_and_input() -> void:
	var game=fresh()
	check(game.get_script().resource_path=="res://scripts/board_depth.gd","main board scene activates the new 2D depth controller")
	check(game is Node2D and game.stage is Node2D,"stage and controller remain native 2D")
	check(game.combat.z_index==1900,"projectiles draw above actor bodies and below HUD")
	check(is_equal_approx(game.BODY_SCALE,0.9) and game.actors.all(func(actor): return actor.node.scale.is_equal_approx(Vector2.ONE*game.BODY_SCALE*GroundProjection.depth_scale(Vector2(actor.cell)+Vector2(0.5,0.5))) and not actor.node.presentation.show_shadow and actor.node.z_index==int(actor.node.global_position.y)),"all actual actor sizes use continuous projective depth, dedicated shadows and actual foot sorting")
	var far_scale: float=GroundProjection.depth_scale(Vector2(6,0.5))
	var middle_scale: float=GroundProjection.depth_scale(Vector2(6,3.5))
	var near_scale: float=GroundProjection.depth_scale(Vector2(6,6.5))
	check(far_scale>0 and far_scale<middle_scale and middle_scale<near_scale and near_scale<=1.0,"far/middle/near projective body scales increase without changing actor proportions")
	for row in Config.ROWS:
		for col in Config.COLS:
			var cell:=Vector2i(col,row)
			var center: Vector2=GroundProjection.center(cell)
			check(GroundProjection.cell_at(center)==cell and game.display_cell_at(center)==cell,"projected cell center roundtrip "+str(cell))
			# Godot's screen Vector2 is float32; the independent 9,824-check geometry
			# run measures 1.06624031559477e-6 max roundtrip error at this calibration.
			# Integer picking and all just-outside/shared-edge tests stay exact.
			check(GroundProjection.inverse(center).distance_to(Vector2(cell)+Vector2(0.5,0.5))<0.000004,"projection inverse recovers fractional grid center within float32 pixel precision "+str(cell))
			for corner in [Vector2(0.02,0.02),Vector2(0.98,0.02),Vector2(0.98,0.98),Vector2(0.02,0.98)]:
				check(GroundProjection.cell_at(GroundProjection.point(Vector2(cell)+corner))==cell,"four near-edge samples retain same cell "+str(cell))
			var polygon: PackedVector2Array=GroundProjection.polygon(cell)
			check(polygon.size()==4 and Geometry2D.is_point_in_polygon(center,polygon),"inset ground polygon contains its exact click center "+str(cell))
			game.select("guard_monk")
			var before: Vector2i=game._record("guard_monk").cell
			var event:=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
			event.position=center
			event.pressed=true
			game._unhandled_input(event)
			event.pressed=false
			game._unhandled_input(event)
			check(game._record("guard_monk").cell==(cell if Config.deployable(cell) else before),"actual logical center click obeys projected cell and left-half deployment "+str(cell))
	for grid in [Vector2(-0.001,3),Vector2(12,3),Vector2(3,-0.001),Vector2(3,7),Vector2(-1,-1),Vector2(13,8)]:
		check(GroundProjection.cell_at(GroundProjection.point(grid))==Vector2i(-1,-1),"outside projected edges reject input "+str(grid))
	check(GroundProjection.cell_at(GroundProjection.point(Vector2(6,7))+Vector2(0,20))==Vector2i(-1,-1),"front board thickness cannot become a playable cell")
	check(GroundProjection.cell_at(GroundProjection.point(Vector2(0,3))+Vector2(-20,0))==Vector2i(-1,-1),"left exterior cannot become a playable cell in the frontal projection")
	check(GroundProjection.cell_at(GroundProjection.point(Vector2.ZERO))==Vector2i.ZERO,"top-left boundary remains inclusive")
	check(GroundProjection.cell_at(GroundProjection.point(Vector2(5.999,3)))==Vector2i(5,3) and GroundProjection.cell_at(GroundProjection.point(Vector2(6.001,3)))==Vector2i(6,3),"deployment seam is exactly the projected sixth column")
	for row in Config.ROWS:
		for col in range(1,Config.COLS):
			for side in [-1,1]:
				var grid:=Vector2(col+side*0.00001,row+0.5)
				check(GroundProjection.cell_at(GroundProjection.point(grid))==Vector2i(col-1 if side<0 else col,row),"both sides of every shared projected column edge "+str(grid))
	for row in range(1,Config.ROWS):
		for col in Config.COLS:
			for side in [-1,1]:
				var grid:=Vector2(col+0.5,row+side*0.00001)
				check(GroundProjection.cell_at(GroundProjection.point(grid))==Vector2i(col,row-1 if side<0 else row),"both sides of every shared projected row edge "+str(grid))
	for grid in [Vector2(-0.00001,0),Vector2(0,-0.00001),Vector2(12.00001,0),Vector2(12,-0.00001),Vector2(-0.00001,7),Vector2(0,7.00001),Vector2(12.00001,7),Vector2(12,7.00001)]:
		check(GroundProjection.cell_at(GroundProjection.point(grid))==Vector2i(-1,-1),"all four outer corners reject their just-outside points without clamping "+str(grid))
	cases.append({"kind":"projection_and_logical_clicks","cells":84,"all_shared_edges_both_sides":true,"four_corner_outside_rejection":true,"depth_scales":[far_scale,middle_scale,near_scale],"OS_input_verified":false})
	game.free()

func movement() -> void:
	for row in [0,3,6]:
		for direction in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
			movement_case(row,direction)

func movement_case(row: int, direction: Vector2i) -> void:
	var game=fixture()
	var actor: Dictionary=game._record("guard_monk")
	# Keep actual actors alive but outside the isolated movement lane. No AI runs
	# in this explicit fixture; the natural suite below retains all real brains.
	var other_index:=0
	for other in game.actors:
		if other.id==actor.id: continue
		game._set_cell(other,Vector2i(8+other_index%4,int(other_index/4)))
		other_index+=1
	var from:=Vector2i(1,clampi(row,1,5) if direction.y!=0 else row)
	var target: Vector2i=from+direction
	game._set_cell(actor,from)
	check(game.start_battle(),"movement fixture starts real simulation")
	check(game._move(actor,target),"movement fixture accepts an unoccupied adjacent cell")
	game.step(0.25)
	var continuous_grid:=Vector2(from).lerp(Vector2(target),0.5)+Vector2(0.5,0.5)
	var midpoint: Vector2=GroundProjection.point(continuous_grid)
	var halfway_scale: Vector2=Vector2.ONE*game.BODY_SCALE*GroundProjection.depth_scale(continuous_grid)
	check(actor.node.position.distance_to(midpoint)<0.000001 and is_equal_approx(actor.move.time,0.25),"0.25 second half-step interpolates logical ground before projection "+str(direction)+" row="+str(row))
	check(actor.node.scale.is_equal_approx(halfway_scale) and is_zero_approx(actor.node.rotation),"half-step body smoothly scales around an upright foot, not a discrete destination row "+str(direction)+" row="+str(row))
	if direction.y!=0:
		check(midpoint.distance_to(GroundProjection.center(from).lerp(GroundProjection.center(target),0.5))>0.001,"non-affine projective half-step is not a screen-endpoint midpoint "+str(direction))
	check(actor.cell==from and actor.node.z_index==int(midpoint.y),"mid-segment keeps logical origin and projected foot sorting "+str(direction))
	var before: Dictionary=game.report().duplicate(true)
	var paused_scale: Vector2=actor.node.scale
	game.paused=true
	game.step(2)
	check(game.report()==before and actor.node.position.distance_to(midpoint)<0.000001 and actor.node.scale==paused_scale,"pause freezes projected actor, continuous scale and all combat report fields")
	game.paused=false
	game.step(0.25)
	check(actor.cell==target and actor.move.is_empty() and actor.node.position.distance_to(GroundProjection.center(target))<0.000001,"exact 0.50 second projected landing "+str(direction))
	check(actor.node.scale.is_equal_approx(Vector2.ONE*game.BODY_SCALE*GroundProjection.depth_scale(Vector2(target)+Vector2(0.5,0.5))),"landing adopts exact target depth scale without changing half-second timing "+str(direction))
	var landing_time: float=game.elapsed
	var anchored: bool=actor.node.presentation.position==Vector2.ZERO and actor.node.presentation.foot_anchor==Vector2.ZERO
	var death_direction: Vector2i=direction if Config.valid(actor.cell+direction) else -direction
	var death_sorted: bool=death_during_motion(game,actor,death_direction)
	check(anchored and death_sorted,"local animation foot stays anchored and lethal contact mid-move freezes the correct foot depth "+str(direction))
	cases.append({"kind":"movement","row":row,"direction":[direction.x,direction.y],"half_seconds":0.25,"full_seconds":landing_time,"continuous_midpoint":[midpoint.x,midpoint.y],"half_scale":halfway_scale.x})
	game.free()

func death_during_motion(game, actor: Dictionary, direction: Vector2i) -> bool:
	var attacker: Dictionary=game._record("E5")
	game._set_cell(attacker,actor.cell+Vector2i(2,0))
	actor.node.health=1
	game._attack(attacker,actor,false)
	var limit: float=game.elapsed+3
	while game.combat.missiles.is_empty() and game.elapsed<limit: game.step(Config.STEP)
	var released: bool=game.combat.missiles.size()==1
	var destination: Vector2i=actor.cell+direction
	var moving: bool=game._move(actor,destination)
	while game._alive(actor) and game.elapsed<limit: game.step(Config.STEP)
	var foot: Vector2=actor.node.to_global(actor.node.presentation.foot_anchor)
	var order: int=actor.node.z_index
	var contact_scale: Vector2=actor.node.scale
	var mid_move: bool=foot.distance_to(game.display_center(actor.cell))>0.1 and foot.distance_to(game.display_center(destination))>0.1
	var sorted_on_contact: bool=actor.dead and order==int(foot.y) and contact_scale.is_equal_approx(Vector2.ONE*game.BODY_SCALE*GroundProjection.depth_scale(GroundProjection.inverse(foot)))
	game.step(0.5)
	var frozen: bool=actor.node.global_position==foot and actor.node.z_index==order and actor.node.scale==contact_scale and actor.move.is_empty()
	cases.append({"kind":"lethal_contact_mid_move","direction":[direction.x,direction.y],"real_projectile":released,"moving":moving,"mid_segment":mid_move,"dead":actor.dead,"foot":[foot.x,foot.y],"z_index":order,"sorted_on_contact":sorted_on_contact,"frozen_after_half_second":frozen})
	return released and moving and mid_move and sorted_on_contact and frozen

func projectile(key: String, mirrored: bool, row: int) -> void:
	var game=fixture()
	check(game.start_battle(),"projectile fixture starts real simulation")
	var source: Dictionary=game._record(key)
	var healing: bool=key=="herbal_spirit_child"
	var recipient: Dictionary=game._record("tangseng" if healing else "E5")
	game._set_cell(source,Vector2i(4 if mirrored else 1,row))
	game._set_cell(recipient,Vector2i(1 if mirrored else 4,row))
	if healing: recipient.node.health=recipient.hp_max-40
	game._attack(source,recipient,healing)
	var release_limit:=2.0
	while game.combat.missiles.is_empty() and game.elapsed<release_limit:
		game.step(Config.STEP)
	check(game.combat.missiles.size()==1,"one real projectile released "+key+" mirrored="+str(mirrored))
	if game.combat.missiles.is_empty():
		game.free()
		return
	var missile: Dictionary=game.combat.missiles[0]
	var expected_from: Vector2=game.combat.to_local(source.node.to_global(source.node.presentation.emission_position()))
	check(missile.from.distance_to(expected_from)<0.000001 and missile.position.distance_to(expected_from)<0.000001,"actual projected socket is the initial projectile point "+key)
	check(is_zero_approx(missile.time),"projectile flight begins at the existing release event")
	game.step(0.125)
	var expected_aim: Vector2=game.combat.to_local(recipient.node.to_global(Vector2(0,-35)))
	check(game.visual_target_point(recipient.node).distance_to(expected_aim)<0.000001,"target display point follows the recipient's actual depth-scaled local anchor "+key)
	check(missile.position.distance_to(expected_from.lerp(expected_aim,0.5))<0.000001,"half-flight reaches correct screen-space interpolation "+key)
	check(game.combat.counts.heals==0 and game.combat.counts.hits==0,"no early damage or heal before 0.25 seconds "+key)
	var next_cell: Vector2i=recipient.cell+(Vector2i.UP if row==6 else Vector2i.DOWN)
	game._set_cell(recipient,next_cell)
	game.step(Config.STEP)
	expected_aim=game.combat.to_local(recipient.node.to_global(Vector2(0,-35)))
	check(missile.position.distance_to(expected_from.lerp(expected_aim,missile.time/0.25))<0.000001,"projectile tracks the actual newly projected target point "+key)
	while not game.combat.missiles.is_empty() and game.elapsed<release_limit:
		game.step(Config.STEP)
	check(game.combat.counts.projectiles==1 and game.combat.counts.heals+game.combat.counts.hits==1,"single serial releases and applies exactly once "+key)
	check(not game.combat.marks.is_empty() and game.combat.marks[0].position.distance_to(expected_aim)<0.000001,"contact mark lands on projected target "+key)
	cases.append({"kind":"projectile","source":key,"row":row,"mirrored":mirrored,"flight_seconds":0.25,"single_application":true,"depth_scaled_origin_and_contact":true})
	game.free()

func audit_foot_sorting(game, frozen_dead: Dictionary, issues: Dictionary) -> void:
	for actor in game.actors:
		var foot: Vector2=actor.node.to_global(actor.node.presentation.foot_anchor)
		if actor.node.z_index!=int(foot.y) and not issues.has("sort:"+actor.id):
			issues["sort:"+actor.id]={"time":game.elapsed,"id":actor.id,"dead":actor.dead,"foot":[foot.x,foot.y],"z_index":actor.node.z_index}
		var expected_scale: Vector2=Vector2.ONE*game.BODY_SCALE*GroundProjection.depth_scale(GroundProjection.inverse(foot))
		if not actor.node.scale.is_equal_approx(expected_scale) and not issues.has("scale:"+actor.id):
			issues["scale:"+actor.id]={"time":game.elapsed,"id":actor.id,"dead":actor.dead,"foot":[foot.x,foot.y],"scale":actor.node.scale.x,"expected":expected_scale.x}
		if actor.dead:
			if not frozen_dead.has(actor.id): frozen_dead[actor.id]={"foot":foot,"z_index":actor.node.z_index,"scale":actor.node.scale}
			elif (foot!=frozen_dead[actor.id].foot or actor.node.z_index!=frozen_dead[actor.id].z_index or actor.node.scale!=frozen_dead[actor.id].scale) and not issues.has("freeze:"+actor.id):
				issues["freeze:"+actor.id]={"time":game.elapsed,"id":actor.id,"foot":[foot.x,foot.y],"z_index":actor.node.z_index}

func natural(depth: bool, profile: String, formation: String) -> Dictionary:
	var game=fresh(depth,profile)
	if formation=="R":
		game.deployment.clear()
		for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=SUPPORT[index]-Vector2i.ONE
		game._reset_roster()
	else:
		game.load_formation(formation)
	check(game.start_battle(),"natural battle starts "+profile+" "+formation+" depth="+str(depth))
	var frozen_dead: Dictionary={}
	var sorting_issues: Dictionary={}
	while game.phase==game.Phase.BATTLE and game.elapsed<90:
		game.step(1.0/60.0)
		if depth: audit_foot_sorting(game,frozen_dead,sorting_issues)
	check(game.phase==game.Phase.RESULT and game.result_count==1 and sorting_issues.is_empty(),"natural full battle ends once with safe alive/dead foot sorting "+profile+" "+formation+" depth="+str(depth))
	if depth:
		cases.append({"kind":"depth_foot_sorting","profile":profile,"formation":formation,"all_sampled_steps_sorted":sorting_issues.is_empty(),"dead_actors_checked":frozen_dead.size(),"issues":sorting_issues})
	var result: Dictionary=game.report().duplicate(true)
	game.free()
	return result

func legacy_and_audio() -> void:
	var legacy=fresh(false)
	check(legacy.get_script().resource_path=="res://scripts/board_trial.gd","legacy scene retains the original board controller")
	check(legacy.actors.all(func(actor): return actor.node.position==Config.center(actor.cell) and actor.node.scale==Vector2.ONE*0.72 and actor.node.presentation.show_shadow),"legacy actors retain rectangular centers, size and original shadows")
	legacy.free()
	var audio=load("res://scenes/audio_trial.tscn").instantiate()
	root.add_child(audio)
	audio.set_process(false)
	audio.audio_feedback.enabled=false
	for row in Config.ROWS:
		for col in Config.COLS:
			var cell:=Vector2i(col,row)
			check(audio.display_center(cell)==Config.center(cell) and audio.display_cell_at(Config.center(cell))==cell,"audio trial keeps legacy display mapping "+str(cell))
	check(audio.actors.all(func(actor): return actor.node.position==Config.center(actor.cell) and actor.node.scale==Vector2.ONE*0.72),"audio trial's actual actors retain its original size and positions")
	audio.free()
	cases.append({"kind":"legacy_and_audio","cells":84,"old_actor_scale":0.72})

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path=argument.trim_prefix("--output=")
	projection_and_input()
	movement()
	for key in ["tangseng","wild_hunter","sparrow_spirit","herbal_spirit_child","foxfire_imp"]:
		for row in [0,3,6]:
			for mirrored in [false,true]: projectile(key,mirrored,row)
	legacy_and_audio()
	for profile in Config.ENEMY_PROFILES:
		for formation in ["A","B","C","R"]:
			var old_report: Dictionary=natural(false,profile,formation)
			var depth_report: Dictionary=natural(true,profile,formation)
			var matched: bool=old_report==depth_report
			check(matched,"complete report including all attack times matches legacy "+profile+" "+formation)
			cases.append({"kind":"natural_full_report","profile":profile,"formation":formation,"exact_report_equal":matched,"report":depth_report,"legacy_report":old_report})
			print("BOARD_DEPTH_PARITY ",profile," ",formation," exact=",matched)
	var output:=FileAccess.open(output_path,FileAccess.WRITE)
	check(output!=null,"depth evidence file opens outside the repository")
	if output!=null:
		output.store_string(JSON.stringify({"scope":"2D depth presentation and simulation parity","checks":checks,"failures":failures,"cases":cases,"natural_runs":24,"OS_input_or_visual_review":false},"\t"))
	print("BOARD_DEPTH checks=",checks," natural_runs=24 failures=",failures)
	quit(1 if failures else 0)
