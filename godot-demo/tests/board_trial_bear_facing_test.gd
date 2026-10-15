extends SceneTree
## D004: frame-local geometry/runtime checks, not graphical rendering approval.
## Absolute host script also works with --main-pack (no inherited test modules).
const Config = preload("res://scripts/data/board_trial_config.gd")
const SharedView = preload("res://scripts/presentation/character_presentation.gd")
const LegacyEnemy = preload("res://scripts/enemy.gd")
const SUPPORT := [Vector2i(2,4),Vector2i(5,4),Vector2i(4,3),Vector2i(4,5),Vector2i(3,4),Vector2i(4,4)]
const VIEW_KEYS := ["pose","pose_time","animation_clock","attack_direction","facing","foot_anchor","move_left","landing","hit_pulse","motion_frame","frame_index","position","motion_sample_enabled","sample_track"]
var failures := 0
var matrices := []
var activities := []
var natural_reports := []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)

func equal(a,b) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]: return absf(float(a)-float(b))<0.000000001
	if typeof(a)!=typeof(b): return false
	if a is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equal(a[key],b[key]): return false
		return true
	if a is Array:
		if a.size()!=b.size(): return false
		for index in a.size():
			if not equal(a[index],b[index]): return false
		return true
	return a==b

func fresh():
	var game=load("res://scenes/board_trial_legacy.tscn").instantiate()
	check(game.get_script().resource_path=="res://scripts/board_trial.gd","historical bear geometry explicitly uses the rectangular 0.72 legacy controller")
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	return game

func legacy_view(view):
	var baseline=SharedView.new()
	baseline.setup_visual(view.role,"nine_sols_v1")
	for key in VIEW_KEYS: baseline.set(key,view.get(key))
	return baseline

func compare(view, corrected: bool, label: String) -> void:
	var baseline=legacy_view(view)
	var previous: Transform2D=baseline.visual_transform()
	var expected: Transform2D=previous
	if corrected: expected.x*=-1
	var saved := {}
	for key in VIEW_KEYS: saved[key]=view.get(key)
	var actual: Transform2D=view.visual_transform()
	check(actual.is_equal_approx(expected),label+" changes only selected source X basis")
	check(actual.origin==previous.origin and actual.y==previous.y,label+" preserves foot origin/Y basis")
	check(view.emission_position()==baseline.emission_position(),label+" keeps logical socket without another source flip")
	for key in VIEW_KEYS: check(view.get(key)==saved[key],label+" does not mutate playback "+key)
	baseline.free()

func defaults(game, label: String) -> void:
	var bear: Dictionary=game._record("E7")
	var view=bear.node.presentation
	check(view.get_script().resource_path=="res://scripts/presentation/board_trial_bear_view.gd" and view.RULE=="bear-frame0-source-left-d004",label+" uses actual local bear adapter")
	check(view.frame_index==0 and view.motion_frame<0 and view.facing==-1 and signf(view.visual_transform().x.x)==1,label+" left-source idle is physically left with logical enemy facing -1")
	check(view.foot_anchor==Vector2.ZERO and view.position==Vector2.ZERO and bear.node.position==Config.center(bear.cell),label+" preserves actual board foot and 0.72 scale")
	check(bear.node.scale==Vector2.ONE*0.72 and view.manifest.source_facing=="right",label+" does not rewrite shared metadata/scale")
	check(not game.ui.enemy_portraits[3].mirrored,label+" enemy portrait retains native left-source pixels")
	game.select("E7")
	check(not game.ui.selected_portrait.mirrored and game.ui.selected_hp.text.contains("280 / 280"),label+" selected actual bear portrait uses same left-source rule")
	for actor in game.actors:
		if actor.id=="E7": continue
		var other=actor.node.presentation
		compare(other,other.role=="herbal_spirit_child" and other.frame_index==0 and other.motion_frame<0,label+" unchanged "+actor.id)

func geometry() -> void:
	var game=fresh()
	defaults(game,"opening")
	var view=game._record("E7").node.presentation
	var atlas: Image=view.body.get_image()
	var idle: Image=game.ui.enemy_portraits[3].texture.get_image()
	check(atlas.get_region(Rect2i(0,0,256,256)).get_data()==idle.get_data(),"actual portrait idle pixels equal the verified left-facing atlas0; same defect proven")
	var times := [["idle",0.0],["idle",0.37],["move",0.25],["basic_attack",0.01],["basic_attack",0.20],["basic_attack",0.40],["basic_attack",0.79],["hit",0.09],["retreat",0.16]]
	for facing in [-1.0,1.0]:
		for entry in times:
			view.facing=facing
			view.attack_direction=Vector2(facing,0)
			view.set_pose(entry[0])
			view.pose_time=entry[1]
			view.animation_clock=0.43
			view.move_left=0.34 if entry[0]=="move" else 0.0
			view.hit_pulse=0.04
			view.landing=0.02
			view.update_frame()
			var corrected: bool=view.frame_index==0 and view.motion_frame<0
			compare(view,corrected,entry[0]+" "+str(entry[1])+" facing="+str(facing))
			if corrected: check(-signf(view.visual_transform().x.x)==facing,"left-source atlas0 follows actual requested logical side")
			matrices.append({"pose":entry[0],"time":entry[1],"facing":facing,"frame":view.frame_index,"corrected":corrected})
	check(matrices.size()==18 and matrices.any(func(row): return row.pose=="basic_attack" and row.corrected) and matrices.any(func(row): return row.frame==2),"all eighteen actual frame selections include attack0 and unchanged attack2")
	game.load_formation("A")
	defaults(game,"formation reset")
	game.free()
	var legacy=LegacyEnemy.new()
	legacy.setup("bear_lord")
	legacy.presentation.facing=-1
	check(legacy.presentation.get_script().resource_path=="res://scripts/presentation/character_presentation.gd" and legacy.presentation.frame_index==0 and signf(legacy.presentation.visual_transform().x.x)==-1,"actual legacy enemy still uses untouched shared presentation/source transform")
	legacy.free()

func isolate(game, ids: Array) -> void:
	for actor in game.actors:
		if actor.id in ids: continue
		actor.dead=true
		actor.node.take_damage(actor.hp_max)
		actor.node.visible=false
		actor.cell=Vector2i(-1,-1)
		actor.target=""
		actor.move={}

func movement(facing: float) -> void:
	var game=fresh()
	check(game.start_battle(),"actual bear movement fixture starts")
	isolate(game,["E7","guard_monk","tangseng"])
	var bear: Dictionary=game._record("E7")
	var guard: Dictionary=game._record("guard_monk")
	var from := Vector2i(5,3)
	var to := from+Vector2i(int(facing),0)
	game._set_cell(bear,from)
	game._set_cell(guard,from+Vector2i(3*int(facing),0))
	game._set_cell(game._record("tangseng"),Vector2i(0,6))
	bear.target=guard.id
	guard.target=bear.id
	bear.cooldown=100
	guard.cooldown=100
	game._brain(bear,Config.STEP)
	check(bear.move.get("to")==to and bear.node.presentation.frame_index==1 and bear.node.presentation.facing==facing,"actual walk1 starts toward real target without frame0 flip")
	for tick in 60:
		game._tick(Config.STEP)
		var owned := {}
		for actor in game.actors:
			if not game._active(actor): continue
			var cells: Array=[actor.cell]
			if not actor.move.is_empty(): cells.append(actor.move.to)
			for cell in cells:
				check(not owned.has(cell),"bear visual fix does not change live source/destination ownership")
				owned[cell]=actor.id
		compare(bear.node.presentation,bear.node.presentation.frame_index==0,"actual walking "+str(facing))
		if tick==29:
			check(bear.cell==from and is_equal_approx(bear.move.time,0.25) and bear.node.position==Config.center(from).lerp(Config.center(to),0.5),"actual half-step/root remains identical")
	check(bear.cell==to and bear.step_completed==1 and bear.node.position==Config.center(to),"actual full shared 0.50 step lands without visual foot drift")
	activities.append({"kind":"isolated_real_half_full_step","facing":facing,"half_seconds":0.25,"completed_seconds":0.5,"frame1_unchanged":true})
	game.free()

func action(facing: float) -> void:
	var game=fresh()
	check(game.start_battle(),"actual bear action fixture starts")
	isolate(game,["E7","guard_monk","tangseng"])
	var bear: Dictionary=game._record("E7")
	var guard: Dictionary=game._record("guard_monk")
	game._set_cell(bear,Vector2i(5,3))
	game._set_cell(guard,Vector2i(5+int(facing),3))
	game._set_cell(game._record("tangseng"),Vector2i(0,6))
	bear.target=guard.id
	guard.target=bear.id
	bear.cooldown=0.25
	guard.cooldown=100
	while game.elapsed<1.9:
		game._tick(Config.STEP)
		compare(bear.node.presentation,bear.node.presentation.frame_index==0,"real attack/wait "+str(facing))
		check(bear.move.is_empty() and bear.node.position==Config.center(bear.cell),"actual bear range1/CD wait preserves root foot")
	var times: Array=game.metrics.attack_times.get("E7",[])
	check(times.size()==2 and is_equal_approx(times[0],0.25) and is_equal_approx(times[1]-times[0],1.20),"actual bear attacks retain two original cadence events")
	check(game._hp(guard)==270 and game.metrics.damage.get("E7",0)==40 and bear.damage==20 and bear.hp_max==280,"actual bear damage/HP unchanged, not just rendered frame")
	check(bear.node.presentation.facing==facing,"actual attack target still turns logical facing")
	game.paused=true
	var before: Dictionary=game.report().duplicate(true)
	var pose_time: float=bear.node.presentation.pose_time
	game.step(3)
	check(game.report()==before and bear.node.presentation.pose_time==pose_time,"pause freezes real bear attack clocks and damage")
	game.paused=false
	bear.node.take_damage(280)
	game._tick(Config.STEP)
	check(game.phase==game.Phase.RESULT and game.victory and bear.dead and bear.move.is_empty() and bear.target.is_empty(),"actual bear death still releases combat and gives one true victory")
	game.selected="E7"
	game._process(1.0)
	await process_frame
	await process_frame
	check(not is_instance_valid(bear.node),"actual enemy death fade frees corrected node")
	game.ui.refresh()
	check(game.ui.selected_hp.text.contains("0 / 280") and not game.ui.selected_portrait.mirrored,"freed bear detail retains correct cached native portrait")
	game.retry()
	defaults(game,"death retry "+str(facing))
	activities.append({"kind":"isolated_original_damage_cadence_death_pause_retry","facing":facing,"attack_times":times,"actual_damage":40,"recipient_hp":270})
	game.free()

func natural(formation: String, reference: Dictionary) -> void:
	var game=fresh()
	if formation=="R":
		game.deployment.clear()
		for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=SUPPORT[index]-Vector2i.ONE
		game._reset_roster()
	else: game.load_formation(formation)
	check(game.start_battle(),"natural current bear "+formation+" starts all real AI")
	while game.phase==game.Phase.BATTLE and game.elapsed<60: game.step(1.0/60)
	var report: Dictionary=game.report().duplicate(true)
	check(game.phase==game.Phase.RESULT and game.result_count==1 and equal(report,reference),"entire original bear "+formation+" report/damage/CD/result preserved")
	natural_reports.append({"formation":formation,"original_full_report_equal":equal(report,reference),"report":report})
	game.free()

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var path: String=args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://tests/board-trial-runtime/board-balance-20261009-natural.json")
	var reference=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	check(reference is Dictionary and reference.get("failures",-1)==0,"actual previous complete balance evidence loads")
	if not reference is Dictionary:
		quit(1)
		return
	var reports := {}
	for entry in reference.cases:
		if entry.profile=="bear": reports[entry.formation]=entry.report
	geometry()
	movement(-1)
	movement(1)
	await action(-1)
	await action(1)
	for formation in ["A","R"]: natural(formation,reports[formation])
	check(matrices.size()==18 and activities.size()==4 and natural_reports.size()==2,"all D004 geometry/activity/natural cases actually completed")
	var destination: String=args[1] if args.size()>1 else "/tmp/board-bear-facing-20261009-source.json"
	var file:=FileAccess.open(destination,FileAccess.WRITE)
	check(file!=null,"D004 compact evidence opens")
	if file!=null: file.store_string(JSON.stringify({"scope":"D-20261009-004","rule":"bear-frame0-source-left-d004","source_pixel_fact":"atlas0 faces left; identical idle portrait pixels","matrix_cases":matrices,"activity_cases":activities,"natural":natural_reports,"graphical_pixels_verified":false,"failures":failures},"\t"))
	print("BOARD_BEAR_FACING matrices=",matrices.size()," activities=",activities.size()," natural=",natural_reports.size()," failures=",failures)
	quit(1 if failures else 0)
