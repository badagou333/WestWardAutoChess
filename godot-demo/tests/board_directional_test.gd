extends SceneTree
## Directional drawing contracts and real board events; not a visual acceptance test.
const View=preload("res://scripts/presentation/board_directional_view.gd")
const Config=preload("res://scripts/data/board_trial_config.gd")
const GroundProjection=preload("res://scripts/presentation/board_depth_projection.gd")
const KEYS:=["tangseng","guard_monk","wild_hunter","sparrow_spirit","herbal_spirit_child","foxfire_imp","mountain_wolf","boar","gray_rat","bear_lord"]
const PLAYBACK:=["pose","pose_time","animation_clock","attack_serial","attack_direction","facing","visual_alpha","dead","move_start","move_end","move_left","position","hit_pulse","hit_cooldown","impact_stop","landing","sample_walk_time","events","motion_sample_enabled"]
var failures:=0
var checks:=0
var tested_roles: Array[String]=[]
var cases: Array=[]

class MotionFixture extends "res://scripts/board_depth.gd":
	func _brain(_actor: Dictionary,_delta: float) -> void: pass

func _initialize() -> void: call_deferred("run")

func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(label)

func fresh(legacy:=false):
	var game=load("res://scenes/board_trial_legacy.tscn").instantiate() if legacy else MotionFixture.new()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	return game

func available_packages() -> void:
	for key in KEYS:
		var pack: Dictionary=View.load_pack(key)
		check(FileAccess.file_exists(View.BASE+key+"/manifest.json") and not pack.is_empty(),"every delivered role must have its validated direction package, no silent fallback: "+key)
		if pack.is_empty(): continue
		tested_roles.append(key)
		check(pack.frames.size()==16 and pack.textures.size()==16 and pack.source_factors.size()==16,"all sixteen crops/textures/scales exist: "+key)
		var per_atlas: Dictionary={}
		for i in 16:
			var frame: Dictionary=pack.frames[i]
			var atlas: String=str(frame.get("atlas",pack.atlas))
			var factor: float=pack.source_factors[i]
			check(not per_atlas.has(atlas) or is_equal_approx(float(per_atlas[atlas]),factor),"one source-resolution factor per atlas: %s %d"%[key,i])
			per_atlas[atlas]=factor
			check(pack.bounds[i].has_area() and pack.textures[i]!=null,"nonempty alpha crop %s %d"%[key,i])
			var polygon: PackedVector2Array=pack.polygons[i]
			check(polygon.is_empty() or (polygon.size()==pack.uvs[i].size() and Geometry2D.triangulate_polygon(polygon).size()==(polygon.size()-2)*3),"optional clip polygon and UVs triangulate %s %d"%[key,i])
		cases.append({"kind":"uniform_scale_profile","role":key,"scale":pack.scale,
			"front_local_height":pack.bounds[0].size.y*float(pack.scale)*pack.source_factors[0],
			"back_local_height":pack.bounds[8].size.y*float(pack.scale)*pack.source_factors[8],
			"height_includes_weapon":true,"atlas_source_factors":per_atlas})
	check(tested_roles.size()==KEYS.size(),"all ten delivered direction packages are available")
	check(View.load_pack("missing_directional_test_role").is_empty(),"missing package stays absent, not a fabricated back view")

func scene_wiring() -> void:
	var game=fresh()
	var old=fresh(true)
	game._update_ui()
	check(game.ui.animation_toggle.disabled and game.ui.animation_toggle.text=="正背面已启用","new board does not offer a fake monk old/new display comparison")
	for actor in game.actors:
		var view=actor.node.presentation
		var expected:=tested_roles.has(view.role)
		check(view.has_method("draw_sample")==expected,"only delivered packages opt into main board: "+actor.id)
		if expected:
			check(view.direction_actor==actor and view.position==Vector2.ZERO and view.foot_anchor==Vector2.ZERO,"direction view follows actual actor foot: "+actor.id)
			var expected_scale: float=game.BODY_SCALE*GroundProjection.depth_scale(Vector2(actor.cell)+Vector2(0.5,0.5))
			check(actor.node.scale.is_equal_approx(Vector2.ONE*expected_scale) and actor.node.position.is_equal_approx(GroundProjection.center(actor.cell)),"direction adapter stays upright at projected foot with continuous depth scale: "+actor.id)
			check(view.manifest==actor.visual_manifest,"combat still reads original action manifest: "+actor.id)
			var other=old._record(actor.id).node.presentation
			for field in PLAYBACK:
				check(view.get(field)==other.get(field),"adapter installation preserves %s %s"%[actor.id,field])
	check(old.actors.all(func(actor): return not actor.node.presentation.has_method("draw_sample")),"legacy scene retains original viewers")
	game.free()
	old.free()

func direction_contracts() -> void:
	var game=fresh()
	for actor in game.actors:
		var view=actor.node.presentation
		if not view.has_method("draw_sample"): continue
		view.face(Vector2(100,60))
		check(view.direction_frame()==0 and view.direction_sign==1,"front/right idle: "+actor.id)
		view.face(Vector2(-100,-60))
		check(view.direction_frame()==8 and view.direction_sign==-1,"back/left idle: "+actor.id)
		view.face(Vector2.ZERO)
		game._default_face(actor.node,actor.friendly)
		check(view.direction_frame()==8 and view.direction_sign==-1,"zero/default do not turn a stopped character: "+actor.id)
		view.face(Vector2(100,0))
		check(view.direction_frame()==8 and view.direction_sign==1,"horizontal direction retains back bank: "+actor.id)
		view.face(Vector2(100,1))
		check(view.direction_back,"near-horizontal deadzone prevents bank chatter: "+actor.id)
		for back in [false,true]:
			view.face(Vector2(100,-60 if back else 60))
			var offset:=8 if back else 0
			actor.move={"from":Vector2i(0,0),"to":Vector2i(1,0),"time":0.0,"duration":0.5}
			view.pose="idle" # Old .42 s visual may have ended, real movement has not.
			check(view.direction_frame()==offset+1,"first moving support pose: "+actor.id)
			actor.move.time=0.25
			check(view.direction_frame()==offset+2,"second moving support pose: "+actor.id)
			actor.move.time=0.499
			check(view.direction_frame()==offset+2,"no early idle in real half-second segment: "+actor.id)
			actor.move={}
			check(view.direction_frame()==offset,"landing returns idle without changing direction: "+actor.id)
			view.play_attack()
			check(view.direction_frame()==offset+3,"attack uses same-direction windup: "+actor.id)
			view.pose_time=view.impact_delay()
			check(view.direction_frame()==offset+4,"drawn strike coincides with existing impact clock: "+actor.id)
			var first: Dictionary=view.draw_sample()
			check(view.emission_position().distance_to(Vector2(first.emission))<0.000001,"projectile socket uses exact current draw sample: "+actor.id)
			view.face(Vector2(-100,-60 if back else 60))
			var mirrored: Dictionary=view.draw_sample()
			check(is_equal_approx(first.emission.x,-mirrored.emission.x) and is_equal_approx(first.emission.y,mirrored.emission.y),"left-facing mirror affects socket X only: "+actor.id)
			check(first.texture==mirrored.texture and first.region==mirrored.region and first.frame==mirrored.frame,"mirror does not choose unrelated crop: "+actor.id)
			view.set_pose("hit")
			check(view.direction_frame()==offset+5,"hit retains directional bank: "+actor.id)
			view.play_retreat()
			check(view.direction_frame()==offset+6,"retreat begins collapse: "+actor.id)
			view.pose_time=0.2
			check(view.direction_frame()==offset+7,"retreat reaches grounded final pose: "+actor.id)
			view.face(Vector2(100,60 if back else -60))
			game._default_face(actor.node,actor.friendly)
			check(view.direction_frame()==offset+7 and view.direction_sign==-1,"death freezes bank and horizontal facing: "+actor.id)
			view.reset_visual()
		cases.append({"role":view.role,"actor":actor.id,"front_back_actions":true,"mirror_socket":true,"death_frozen":true})
	game.free()

func real_movement_and_pause() -> void:
	for key in ["guard_monk","wild_hunter","foxfire_imp"]:
		var game=fresh()
		var actor: Dictionary=game._record(key)
		var view=actor.node.presentation
		game._set_cell(actor,Vector2i(0,2))
		check(game.start_battle(),"movement fixture starts "+key)
		check(game._move(actor,Vector2i(0,1)),"real upward segment accepts "+key)
		game.step(0.10)
		check(view.direction_frame()==9,"real upward first support pose "+key)
		var early_grid:=Vector2(0.5,2.5).lerp(Vector2(0.5,1.5),0.2)
		check(actor.node.position.distance_to(GroundProjection.point(early_grid))<0.0002 and actor.node.scale.is_equal_approx(Vector2.ONE*game.BODY_SCALE*GroundProjection.depth_scale(early_grid)),"early real upward motion projects continuous logical point and scales around its foot "+key)
		game.step(0.35)
		check(view.direction_frame()==10 and not actor.move.is_empty(),"real upward late segment remains walking "+key)
		var late_grid:=Vector2(0.5,2.5).lerp(Vector2(0.5,1.5),0.9)
		check(actor.node.position.distance_to(GroundProjection.point(late_grid))<0.0002 and actor.node.scale.is_equal_approx(Vector2.ONE*game.BODY_SCALE*GroundProjection.depth_scale(late_grid)),"late motion remains nonlinearly projected without pose or scale snap "+key)
		var socket: Vector2=view.emission_position()
		check(view.to_global(socket).distance_to(actor.node.position+socket*actor.node.scale)<0.0002,"world socket follows the same scaled upright actor transform "+key)
		var pose_time: float=view.pose_time
		var frame: int=view.direction_frame()
		var report: Dictionary=game.report().duplicate(true)
		game.paused=true
		game.step(3)
		check(view.direction_frame()==frame and view.pose_time==pose_time and game.report()==report,"pause freezes complete action and simulation "+key)
		game.paused=false
		game.step(0.05)
		check(actor.move.is_empty() and actor.cell==Vector2i(0,1) and view.direction_frame()==8 and actor.node.position.is_equal_approx(GroundProjection.center(actor.cell)),"real 0.50-second projected landing retains back idle "+key)
		game.free()

func run() -> void:
	available_packages()
	scene_wiring()
	direction_contracts()
	real_movement_and_pause()
	var output_path: String="/tmp/board-perspective-directional-20261017.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path=argument.trim_prefix("--output=")
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	check(file!=null,"directional test report opens")
	var report:={"scope":"board-only front/back display, no visual acceptance","checks":checks,"failures":failures,"roles":tested_roles,"cases":cases}
	if file: file.store_string(JSON.stringify(report,"\t"))
	print("BOARD_DIRECTIONAL ",checks," checks / ",failures," failures; roles=",tested_roles)
	quit(1 if failures else 0)
