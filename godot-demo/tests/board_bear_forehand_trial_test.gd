extends SceneTree
## Contract tests cover both the released limited candidate and synthetic invalid tracks.
const Adapter = preload("res://scripts/presentation/board_bear_forehand_view.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
var checks := 0
var failures := 0

class Fixture extends "res://scripts/board_bear_forehand_trial.gd":
	func _brain(_actor: Dictionary, _delta: float) -> void: pass

class MissingFixture extends "res://scripts/board_bear_forehand_trial.gd":
	func _load_bear_track() -> Dictionary: return {}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func texture(color: Color, size := Vector2i(32,32), opaque := false) -> Texture2D:
	var image := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	image.fill(color if opaque else Color.TRANSPARENT)
	if not opaque: image.fill_rect(Rect2i(4,4,size.x-8,size.y-8),color)
	return ImageTexture.create_from_image(image)

func track(view) -> Dictionary:
	return {"schema":Adapter.TRIAL_SCHEMA,"source_sign":1,"source_back":false,"scale":1.0,
		"foot":[16,30],"feet":[[8,30],[24,30]],"emission":[28,14],"impact_index":1,
		"frames":[{"at":0.0,"texture":texture(Color.RED)},
			{"at":view.impact_delay(),"texture":texture(Color.GREEN)},
			{"at":0.55,"texture":texture(Color.BLUE)}]}

func run() -> void:
	var expect_packed := false
	var evidence_path := ""
	var compare_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg=="--expect-packed": expect_packed = true
		elif arg.begins_with("--evidence="): evidence_path = arg.trim_prefix("--evidence=")
		elif arg.begins_with("--compare="): compare_path = arg.trim_prefix("--compare=")
	if expect_packed:
		check(OS.has_feature("bear_forehand_trial") and ProjectSettings.get_setting_with_override("application/run/main_scene")=="res://scenes/board_bear_forehand_trial.tscn","dedicated PCK defaults to trial entry")
		check(not FileAccess.file_exists("res://scripts/board_bear_forehand_trial.gd") and not FileAccess.file_exists("res://tests/board_bear_forehand_trial_test.gd"),"packed test cannot silently read host source files")
		check(not FileAccess.file_exists("res://art/candidates/bear_lord_forehand_trial_v1/manifest.json"),"candidate directory is excluded from PCK")
		check(not FileAccess.file_exists("res://art/runtime/bear_forehand_trial_v1/attack_00.png"),"PCK has no source PNG fallback")
	var game = Fixture.new()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled = false
	var bear: Dictionary = game._record("E7")
	var victim: Dictionary = game._record(game.trial_target)
	var view = bear.node.presentation
	check(game.trial_target != "" and not victim.is_empty(),"controlled setup has an existing target")
	check(bear.cell == victim.cell+Vector2i.LEFT,"bear begins one cell to target's screen-left")
	check(victim.node.position.x > bear.node.position.x,"real projected target is to screen right")
	check(view.get_script()==Adapter,"only trial bear uses new adapter")
	check(game.trial_track_ready and view.trial_track.frames.size()==20,"released limited runtime frames are loaded")
	check(is_equal_approx(bear.damage,20.0) and is_equal_approx(bear.interval,1.20),"bear retains original damage and cooldown")
	var hashes: Array = []
	for i in view.trial_track.frames.size():
		var path := "res://art/runtime/bear_forehand_trial_v1/attack_%02d.png" % i
		check(ResourceLoader.exists(path) or FileAccess.file_exists(path),"actual candidate frame exists %d" % i)
		var img: Image = view.trial_track.frames[i].texture.get_image()
		if img.is_compressed(): check(img.decompress()==OK,"compressed runtime frame decompresses")
		img.convert(Image.FORMAT_RGBA8)
		var hasher := HashingContext.new()
		hasher.start(HashingContext.HASH_SHA256)
		hasher.update(img.get_data())
		hashes.append(hasher.finish().hex_encode())
	var runtime_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://art/runtime/bear_forehand_trial_v1/manifest.json"))
	var evidence := {"manifest":runtime_manifest,"rgba_sha256":hashes}
	if not evidence_path.is_empty():
		var file := FileAccess.open(evidence_path,FileAccess.WRITE)
		check(file!=null,"source evidence path is writable")
		if file: file.store_string(JSON.stringify(evidence)); file.close()
	if expect_packed: check(not compare_path.is_empty(),"packed run needs explicit source baseline")
	if not compare_path.is_empty():
		var comparison = JSON.parse_string(FileAccess.get_file_as_string(compare_path))
		check(comparison==evidence,"pack manifest and decoded pixels match source for all twenty frames")
	check("右前试验" in game.title_label.text and "试验版" in game.trial_warning.text,"trial label and limited scope remain visible")
	check(Vector2(view.trial_track.foot[0],view.trial_track.foot[1])==Vector2(177,213) and is_equal_approx(view.trial_track.scale,1.234),"runtime uses delivered foot and scale")
	check(view.trial_track.impact_index==11 and is_equal_approx(view.impact_delay(),0.389),"candidate index 11 uses inherited 0.389 second impact")
	var idle_sample: Dictionary = view.draw_sample()
	view.face(Vector2(100,60))
	view.play_attack()
	view.pose_time = view.impact_delay()
	var impact_sample: Dictionary = view.draw_sample()
	check(view.trial_frame()==11 and impact_sample.transform.get_scale().x>0,"real impact frame plays rightwards without mirroring")
	check(not idle_sample.has("trial_frame") and idle_sample.texture != impact_sample.texture,"idle-to-attack switches between old artwork and candidate")
	check(impact_sample.transform.origin.is_equal_approx(Vector2.ZERO),"candidate foot anchor remains actor origin")
	check(is_equal_approx(impact_sample.transform.get_scale().x*bear.node.scale.x,1.234*bear.node.scale.x),"display scale includes one candidate factor and board depth scale")
	view.reset_visual()
	check(Adapter.load_trial("res://art/runtime/bear_forehand_trial_v1/missing.json").is_empty(),"missing manifest cannot masquerade as successful load")
	check(not view.configure_trial({}),"empty manifest is rejected")
	var invalid := track(view)
	invalid.source_sign = -1
	check(not view.configure_trial(invalid),"wrong direction is rejected")
	invalid = track(view)
	invalid.frames[0].texture = texture(Color.WHITE,Vector2i(32,32),true)
	check(not view.configure_trial(invalid),"opaque source is rejected")
	invalid = track(view)
	invalid.frames[2].texture = texture(Color.WHITE,Vector2i(40,40))
	check(not view.configure_trial(invalid),"inconsistent frame canvas is rejected")
	invalid = track(view)
	invalid.frames[1].at = 0.1
	check(not view.configure_trial(invalid),"impact timing must match existing combat timing")
	var valid := track(view)
	valid.impact_index = JSON.parse_string("{\"index\":1}").index
	check(view.configure_trial(valid),"in-memory frame track is accepted")
	var directory := "/tmp/board-bear-forehand-contract-%d" % OS.get_process_id()
	check(DirAccess.make_dir_recursive_absolute(directory)==OK,"temporary manifest fixture directory created")
	var manifest := valid.duplicate(true)
	for i in manifest.frames.size():
		var name := "frame-%d.png" % i
		var img: Image = manifest.frames[i].texture.get_image()
		check(img.save_png(directory.path_join(name))==OK,"synthetic frame saved for real loader")
		manifest.frames[i].erase("texture")
		manifest.frames[i]["file"] = name
	var file := FileAccess.open(directory.path_join("manifest.json"),FileAccess.WRITE)
	check(file!=null,"temporary JSON manifest opens")
	if file:
		file.store_string(JSON.stringify(manifest))
		file.close()
	check(view.configure_trial(Adapter.load_trial(directory.path_join("manifest.json"))),"real JSON and PNG loader accepts valid fixture")
	for i in manifest.frames.size(): DirAccess.remove_absolute(directory.path_join("frame-%d.png" % i))
	DirAccess.remove_absolute(directory.path_join("manifest.json"))
	DirAccess.remove_absolute(directory)
	check(view.configure_trial(valid),"restore injected in-memory textures")
	view.face(Vector2(100,60))
	view.play_attack()
	check(view.trial_active() and view.trial_frame()==0,"right/front attack plays candidate first frame")
	check(view.draw_sample().texture==valid.frames[0].texture,"sample uses supplied texture")
	view.pose_time = view.impact_delay()
	check(view.trial_frame()==1 and view.draw_sample().texture==valid.frames[1].texture,"impact frame uses existing hit clock")
	view.face(Vector2(-100,60))
	check(not view.trial_active() and not view.draw_sample().has("trial_frame"),"left direction uses existing directional art")
	view.face(Vector2(100,-60))
	check(not view.trial_active() and not view.draw_sample().has("trial_frame"),"back direction uses existing directional art")
	view.set_pose("hit")
	view.face(Vector2(100,60))
	check(not view.trial_active(),"non-attack pose uses existing directional art")
	view.reset_visual()
	check(game.start_battle(),"controlled battle starts")
	var before: float = victim.node.health
	game._attack(bear,victim)
	check(view.trial_active(),"actual combat requests right/front attack")
	check(is_equal_approx(float(bear.cooldown),float(bear.interval)),"combat sets unchanged cooldown")
	game.step(0.375)
	check(is_equal_approx(victim.node.health,before) and game.combat.counts.hits==0,"no damage before impact")
	var prior: float = view.pose_time
	game.paused = true
	game.step(1.0)
	check(view.pose_time==prior and is_equal_approx(victim.node.health,before),"pause freezes clock and damage")
	game.paused = false
	game.step(0.025)
	check(is_equal_approx(victim.node.health,before-bear.damage) and game.combat.counts.hits==1,"one hit resolves at inherited impact time")
	check(view.trial_frame()==1,"candidate impact frame is visible at resolved hit")
	game.step(0.30)
	check(game.combat.counts.hits==1,"one attack cannot resolve damage twice")
	game.retry()
	bear = game._record("E7")
	victim = game._record(game.trial_target)
	view = bear.node.presentation
	check(game.trial_track_ready and view.trial_track.frames.size()==20,"retry restores released runtime track")
	check(game.start_battle(),"retry can restart battle")
	game.speed = 2
	before = victim.node.health
	game._attack(bear,victim)
	game.step(0.1875)
	check(is_equal_approx(victim.node.health,before),"2x has no damage before inherited impact")
	game.step(0.0125)
	check(is_equal_approx(victim.node.health,before-bear.damage) and view.trial_frame()==11 and game.combat.counts.hits==1,"2x preserves real impact frame and single hit")
	game.retry()
	bear = game._record("E7")
	victim = game._record(game.trial_target)
	view = bear.node.presentation
	check(game.start_battle(),"normal speed real-asset battle starts after retry")
	before = victim.node.health
	game._attack(bear,victim)
	game.step(0.375)
	var real_frame: int = view.trial_frame()
	game.paused = true
	game.step(1.0)
	check(view.trial_frame()==real_frame and is_equal_approx(victim.node.health,before),"pause freezes real candidate before the hit")
	game.paused = false
	game.step(0.025)
	check(is_equal_approx(victim.node.health,before-bear.damage) and view.trial_frame()==11 and game.combat.counts.hits==1,"normal speed real candidate aligns with single hit")
	game.free()
	var missing = MissingFixture.new()
	root.add_child(missing)
	missing.set_process(false)
	missing.audio_feedback.enabled = false
	var old_view = missing._record("E7").node.presentation
	old_view.face(Vector2(100,60))
	old_view.play_attack()
	check(not missing.trial_track_ready and not old_view.trial_active() and not old_view.draw_sample().has("trial_frame"),"missing runtime falls back to old directional art")
	check("素材未就绪" in missing.trial_warning.text,"missing resource is visible in trial warning")
	missing.free()
	var actual = load("res://scenes/board_bear_forehand_trial.tscn").instantiate()
	root.add_child(actual)
	actual.set_process(false)
	actual.audio_feedback.enabled = false
	check(actual.start_battle(),"actual independent scene starts")
	actual.step(0.20)
	var actual_bear: Dictionary = actual._record("E7")
	check(actual.metrics.first_engagement.get("E7",{}).get("target","")==actual.trial_target,"normal AI attacks the controlled target")
	check(actual_bear.node.presentation.direction_sign==1 and not actual_bear.node.presentation.direction_back,"normal AI exposes right/front action")
	actual.free()
	print("BEAR_FOREHAND_TRIAL ",checks," checks / ",failures," failures (limited runtime and synthetic fixtures; no visual acceptance)")
	quit(1 if failures else 0)
