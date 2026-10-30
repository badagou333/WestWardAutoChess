extends SceneTree
## May run from source, or by absolute script path with --main-pack <final.pck>.
## Godot consumes engine flags before OS.get_cmdline_args(), so exported runs
## MUST explicitly pass --expect-packed as a user argument. Run them with an
## empty external --path to prevent a missing packed resource falling back to
## this repository's source files.
const GroundProjection = preload("res://scripts/presentation/board_depth_projection.gd")
const STAGE_PATH := "res://art/boards/perspective_stage_v1/scene-clean.png"
const STAGE_SOURCE_SHA := "0a600d28de16c27fb6c92003c1e29a8c4a33c3bd819ab887c8d505adf1142302"
var failures := 0
var checks := 0
var cases: Array[Dictionary] = []
var stage_evidence: Dictionary = {}
var packaged := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	packaged="--expect-packed" in OS.get_cmdline_user_args()
	print("BOARD_PACK_BOOT_MODE expect_packed=",packaged," resource_root=",ProjectSettings.globalize_path("res://"))
	if packaged:
		check(not FileAccess.file_exists(STAGE_PATH),"isolated main-pack mount cannot read original PNG bytes from host source fallback")
		check(not FileAccess.file_exists("res://tests/board_trial_pack_boot.gd"),"isolated main-pack mount excludes host test source; run absolute host script only")
	for name in ["board_trial","audio_trial"]:
		var scene_path: String="res://scenes/"+name+".tscn"
		check(ResourceLoader.exists(scene_path),"actual entry exists without fallback "+name)
		var scene=load(scene_path)
		check(scene is PackedScene,"actual entry resolves to PackedScene "+name)
		if not scene is PackedScene: continue
		var game = scene.instantiate()
		root.add_child(game)
		game.set_process(false)
		game.audio_feedback.enabled = false
		if name=="board_trial":
			check(game.get_script().resource_path=="res://scripts/board_depth.gd","pack main board instantiates the actual depth controller")
			var stage=game.get("stage")
			check(is_instance_valid(stage) and stage.get_script().resource_path=="res://scripts/presentation/board_depth_stage.gd" and stage.game==game and stage.get_parent()==game and stage.visible and stage.z_index<0,"pack boots the actual attached depth stage, not inherited legacy constants")
			check(is_instance_valid(stage) and stage.BACKDROP!=null and stage.BACKDROP.resource_path==STAGE_PATH and stage.BACKDROP.get_size()==Vector2(1672,941),"pack actually loads exact clean-stage texture, never old woodland/platform fallback")
			if is_instance_valid(stage) and stage.BACKDROP!=null:
				var image: Image=stage.BACKDROP.get_image()
				check(image!=null and not image.is_empty() and image.get_size()==Vector2i(1672,941),"actual new stage decodes full-size image data")
				if image!=null and not image.is_empty():
					if image.is_compressed(): check(image.decompress()==OK,"actual new stage compressed pixels decode before exact hashing")
					image.convert(Image.FORMAT_RGBA8)
					var context:=HashingContext.new()
					context.start(HashingContext.HASH_SHA256)
					context.update(image.get_data())
					var pixel_sha: String=context.finish().hex_encode()
					stage_evidence={"path":stage.BACKDROP.resource_path,"size":[image.get_width(),image.get_height()],"decoded_rgba8_sha256":pixel_sha,"raw_source_expected_sha256":STAGE_SOURCE_SHA}
					var expected_pixels: String=""
					for argument in OS.get_cmdline_user_args():
						if argument.begins_with("--expected-stage-pixels-sha="): expected_pixels=argument.trim_prefix("--expected-stage-pixels-sha=")
					if packaged: check(not expected_pixels.is_empty(),"main-pack texture pixels require an explicit source-run SHA baseline")
					if not expected_pixels.is_empty(): check(pixel_sha==expected_pixels,"main-pack decoded stage pixels exactly match supplied source baseline")
					if FileAccess.file_exists(STAGE_PATH):
						stage_evidence["raw_source_sha256"]=FileAccess.get_sha256(STAGE_PATH)
						check(stage_evidence.raw_source_sha256==STAGE_SOURCE_SHA,"clean-stage original PNG SHA exactly matches 05 handoff")
					else: check(packaged,"source run must retain original 05 PNG for its handoff SHA check")
			check(game.ui.card_portraits.all(func(item): return item.texture!=null and item.cropped.get_size()==item.region.size),"pack actually loads all six cropped current production portraits")
			check(game.ui.enemy_portraits.size()==4 and game.ui.enemy_portraits.all(func(item): return item.texture!=null) and game.ui.enemy_buttons.size()==7,"default pack loads four enemy portraits and seven specific inspection buttons")
			check(game.actors.all(func(actor): return actor.node.presentation.facing==(1 if actor.friendly else -1)),"pack starts with confirmed default army directions")
			check(is_equal_approx(game.BODY_SCALE,0.9) and game.actors.all(func(actor): return actor.node.scale.is_equal_approx(Vector2.ONE*game.BODY_SCALE*GroundProjection.depth_scale(Vector2(actor.cell)+Vector2(0.5,0.5))) and actor.node.position==GroundProjection.center(actor.cell) and actor.node.position==game.display_center(actor.cell) and not actor.node.presentation.show_shadow),"pack uses one projected foot/depth scale and dedicated shadows, not fixed 0.9 at every row")
			check(game.Config.COLS==12 and game.Config.ROWS==7 and game.actors.size()==13 and game.enemy_profile=="bear","pack boots the default six-friendly/seven-enemy bear roster")
			check(game.Config.VERSION=="board-v5-bear" and game.RANGED_RULE=="ranged-step-target-20261009" and is_equal_approx(game.Config.MOVE_SECONDS_PER_CELL,0.5),"pack contains current profile-aware config and shared movement duration")
			check(game.Melee.RULE=="melee-stepwise-20261009" and game.Stepwise!=null,"pack includes current melee rules and the actual stepwise planning module")
			check(game.actors.all(func(actor): return actor.walk==game.Config.MOVE_SECONDS_PER_CELL and actor.node.move_interval==game.Config.MOVE_SECONDS_PER_CELL),"pack uses one movement duration for every friendly and enemy actor")
			check(game._record("tangseng").node.presentation.body!=null,"pack contains production core texture")
			var initial: Dictionary=game.report()
			check(initial.config==game.Config.version_for(game.enemy_profile) and initial.enemy_profile=="bear" and initial.enemy_parameters.size()==7,"pack report identifies actual default profile and seven parameter rows")
			var specs: Array=game.Config.enemy_specs(game.enemy_profile)
			for index in specs.size():
				var spec: Array=specs[index]
				var expected: Dictionary=game.Config.enemy_stats(spec[0],game.enemy_profile)
				var actor: Dictionary=game._record("E%d" % (index+1))
				var parameter: Dictionary=initial.enemy_parameters[index]
				check(parameter.id==actor.id and parameter.key==actor.key and actor.key==spec[0] and parameter.initial_cell==[spec[1].x,spec[1].y] and actor.cell==spec[1]-Vector2i.ONE,"pack parameter identity/initial grid agrees with live actor "+actor.id)
				check(parameter.hp==expected.hp and parameter.damage==expected.damage and parameter.interval==expected.interval and parameter.range==expected.range and parameter.walk==0.5,"pack parameter table uses exact board stats "+actor.id)
				check(actor.hp_max==expected.hp and actor.damage==expected.damage and actor.interval==expected.interval and actor.reach==expected.range and actor.node.max_health==expected.hp and actor.node.health==expected.hp and actor.node.damage==expected.damage and actor.node.attack_interval==expected.interval and actor.node.attack_range_cells==expected.range,"pack live enemy/node stats agree with the actual board parameter table "+actor.id)
			var monk_view=game._record("guard_monk").node.presentation
			check(monk_view.get_script().resource_path=="res://scripts/presentation/board_directional_view.gd" and monk_view.has_method("draw_sample") and monk_view.direction_pack.frames.size()==16 and monk_view.direction_pack.textures.size()==16,"default main pack really enables the sixteen-frame directional monk adapter")
			var monk_sample: Dictionary=monk_view.draw_sample()
			check(not monk_sample.is_empty() and monk_sample.texture!=null and monk_sample.region.has_area() and monk_sample.frame==monk_view.direction_frame() and is_equal_approx(monk_view.impact_delay(),0.235),"actual main monk draw sample uses validated texture/crop/current directional frame and unchanged contact clock")
			check(game.actors.all(func(actor): return actor.node.presentation.has_method("draw_sample") and actor.node.presentation.direction_pack.frames.size()==16 and actor.node.presentation.direction_pack.textures.all(func(texture): return texture!=null)),"main pack genuinely loads all ten character packages instead of old sample/fallback artwork")
			check(game.start_battle(),"default bear pack starts the real A deployment")
			while game.phase==game.Phase.BATTLE and game.elapsed<60: game.step(1.0/60)
			var settled: Dictionary=game.report()
			check(game.phase==game.Phase.RESULT and game.result_count==1 and settled.config==game.Config.version_for("bear") and settled.enemy_profile=="bear","default bear pack reaches one actual Result without requiring a historical A outcome")
			check((game._alive(game._record("tangseng")) and game.actors.filter(func(actor): return not actor.friendly).all(func(actor): return not game._alive(actor))) if game.victory else not game._alive(game._record("tangseng")),"default pack result obeys actual victory/failure conditions")
			print("BOARD_PACK_A profile=",game.enemy_profile," victory=",game.victory," seconds=",game.elapsed," TangHP=",settled.tangseng_hp)
			cases.append({"entry":name,"complete":true,"report":settled})
		elif name=="audio_trial":
			check(game.get_script().resource_path=="res://scripts/audio_trial.gd" and game.actors.size()==2 and game.setup_specs.size()==2,"independent audio trial keeps its own two-unit controller and configuration")
			check(game.setup_specs[0].friendly and game.setup_specs[0].key=="guard_monk" and not game.setup_specs[1].friendly and game.setup_specs[1].key=="wolf","audio trial still defaults to real guard versus wolf without mandatory Tang")
			check(game.actors.all(func(actor): return actor.node.position==game.Config.center(actor.cell) and actor.node.scale.is_equal_approx(Vector2.ONE*0.72) and not actor.node.presentation.has_method("draw_sample")),"audio trial retains exact rectangular feet, original 0.72 scale and viewers without perspective leakage")
			check(game.start_battle(),"independent audio trial starts its real default 1v1")
			while game.phase==game.Phase.BATTLE and game.elapsed<60: game.step(1.0/60)
			check(game.phase==game.Phase.RESULT and game.result_count==1,"independent audio trial reaches one actual elimination result")
			cases.append({"entry":name,"complete":true,"report":game.report()})
		print("BOARD_PACK_BOOT ",name)
		game.free()
	if packaged:
		for unwanted in ["HANDOFF.md","integration.json","review/calibration-12x7.png","review/hud-fit-1920x1080.png"]:
			check(not FileAccess.file_exists("res://art/boards/perspective_stage_v1/"+unwanted),"main pack excludes stage handoff/review material "+unwanted)
		check(not FileAccess.file_exists("res://art/reviews/foxfire-3d-board-v1/project.godot"),"independent 3D project remains outside main PCK")
	else:
		var isolated:=ConfigFile.new()
		check(isolated.load("res://art/reviews/foxfire-3d-board-v1/project.godot")==OK and isolated.get_value("application","run/main_scene","")=="res://main.tscn","source still retains its separately launched 3D project identity")
		check(FileAccess.file_exists("res://art/reviews/foxfire-3d-board-v1/launch.command") and FileAccess.file_exists("res://art/reviews/foxfire-3d-board-v1/.gdignore"),"independent 3D launcher and import isolation remain intact (not booted by main pack test)")
	var output_path: String="/tmp/board-perspective-pack-boot-20261017.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path=argument.trim_prefix("--output=")
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	check(file!=null,"pack boot evidence opens at requested new path")
	if file: file.store_string(JSON.stringify({"scope":"two retained main-project entries; 3D identity/isolation only, not 3D runtime acceptance","packaged":packaged,"pack_mode_is_explicit_user_argument":packaged,"resource_root":ProjectSettings.globalize_path("res://"),"host_source_fallback_gate_checked":packaged,"checks":checks,"failures":failures,"cases":cases,"stage":stage_evidence},"\t"))
	print("BOARD_PACK_BOOT failures=",failures)
	quit(1 if failures else 0)
