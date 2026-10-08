extends SceneTree
## May run from source, or by absolute script path with --main-pack <final.pck>.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	for name in ["board_trial","escort_route","free_escort","main","monk_animation_trial"]:
		var game = load("res://scenes/"+name+".tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		game.audio_feedback.enabled = false
		if name=="board_trial":
			check(game.BACKGROUND.get_size()==Vector2(1672,941),"pack contains full courtyard background")
			check(game.BACKGROUND_RECT==Rect2(0,-12,1920,1128),"pack includes v2-only background mapping")
			check(game.ui.card_portraits.all(func(item): return item.texture!=null and item.cropped.get_size()==item.region.size),"pack actually loads all six cropped current production portraits")
			check(game.ui.enemy_portraits.all(func(item): return item.texture!=null),"pack actually loads three enemy type portraits")
			check(game.actors.all(func(actor): return actor.node.presentation.facing==(1 if actor.friendly else -1)),"pack starts with confirmed default army directions")
			check(game.BOARD_RECT==Rect2(220,190,1320,714),"pack keeps exact logical board geometry")
			check(game.Config.COLS==12 and game.Config.ROWS==7 and game.actors.size()==12,"pack includes independent grid/config/fixed actors")
			check(game.Config.VERSION=="board-v2-uniform-move" and is_equal_approx(game.Config.MOVE_SECONDS_PER_CELL,0.5),"pack contains the uniform movement config revision")
			check(game.actors.all(func(actor): return actor.walk==game.Config.MOVE_SECONDS_PER_CELL and actor.node.move_interval==game.Config.MOVE_SECONDS_PER_CELL),"pack uses one movement duration for every friendly and enemy actor")
			check(game._record("tangseng").node.presentation.body!=null,"pack contains production core texture")
			game.start_battle()
			while game.phase==game.Phase.BATTLE and game.elapsed<60: game.step(1.0/60)
			check(game.victory and game.report().metrics.damage.tangseng>0,"pack actually completes A with weak core ranged damage")
			print("BOARD_PACK_A seconds=",game.elapsed," TangHP=",game.report().tangseng_hp)
		else:
			game._on_shop_pressed(0)
			check(game.heroes.size()==1 and game.coins==2,"legacy economy boots unchanged "+name)
			check(game.heroes[0].presentation.motion_sample_enabled==(name=="monk_animation_trial"),"only existing explicit monk entry adopts candidate "+name)
		print("BOARD_PACK_BOOT ",name)
		game.free()
	print("BOARD_PACK_BOOT failures=",failures)
	quit(1 if failures else 0)
