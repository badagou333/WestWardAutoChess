extends SceneTree
const Presentation = preload("res://scripts/presentation/character_presentation.gd")
var failures := 0
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var game = load("res://scenes/escort_route.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	for role in ["guard_monk","wild_hunter","herbal_spirit_child","sparrow_spirit","foxfire_imp","bear_lord","mountain_wolf","gray_rat","boar","tangseng"]:
		var view = Presentation.new()
		view.setup_visual(role,"nine_sols_v1")
		view.foot_anchor = Vector2.ZERO
		check(view.body.get_size()==Vector2(1280,256),role+" atlas dimensions")
		check(not view.use_motion_frames and view.motion_body==null,role+" cannot mix old motion skin")
		var atlas: Image = view.body.get_image()
		for i in range(5):
			var frame := atlas.get_region(Rect2i(i*256,0,256,256))
			var box := frame.get_used_rect()
			check(box.size.x>0 and box.position.x>0 and box.position.y>0 and box.end.x<256 and box.end.y<256,role+" transparent frame margins")
		for pose in ["idle","move","basic_attack","hit","retreat"]:
			view.reset_visual(); view.set_pose(pose); view.tick(.03)
			check(view.frame_index>=0 and view.frame_index<5,role+" valid pose frame")
		view.reset_visual(); view.play_attack()
		view.face(Vector2(100,0)); var right: Vector2 = view.emission_position()
		view.face(Vector2(-100,0)); var left: Vector2 = view.emission_position()
		check(right.x>0 and left.x<0 and is_equal_approx(right.y,left.y),role+" mirrored launch point")
		view.free()
	game.coins=10
	game._on_shop_pressed(1)
	var hunter = game.heroes[0]
	hunter.active_in_battle=true
	hunter.position=Vector2(600,500)
	hunter.battle_cell=Vector2i(4,5)
	game._spawn_enemy("rat",Vector2i(4,8))
	var rat=game.enemies[0]
	check(hunter.attack_range_cells==3 and rat.attack_range_cells==3,"Trial archer/slinger ranges")
	var cues: Array[String] = []
	game.audio_feedback.cue_played.connect(func(cue): cues.append(cue))
	for source in [hunter,rat]:
		source.presentation.reset_visual()
		var target = rat if source==hunter else game.escort
		var before: float = target.health
		game.combat.request(source,target)
		source.tick_visual(source.presentation.impact_delay()-.001)
		game.combat.tick(0)
		check(game.combat.missiles.is_empty() and target.health==before,"No early projectile/hit")
		source.tick_visual(.002); game.combat.tick(0)
		check(game.combat.missiles.size()==1 and target.health==before,"Release creates flying projectile without early damage")
		if not game.combat.missiles.is_empty():
			check(game.combat.missiles[0].projectile_kind==("arrow" if source==hunter else "stone"),"Correct physical projectile")
		game.combat.tick(.25); game.combat.tick(.25)
		check(is_equal_approx(target.health,before-source.damage),"Projectile damage exactly once at arrival")
	check(not cues.has("wild_hunter_attack") and not cues.has("rat_attack"),"No old melee release audio")
	game.free()
	print("NINE_SOLS_ASSETS failures=",failures)
	quit(1 if failures else 0)
