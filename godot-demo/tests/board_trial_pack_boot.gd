extends SceneTree
## May run from source, or by absolute script path with --main-pack <final.pck>.
const GroundProjection = preload("res://scripts/presentation/board_depth_projection.gd")
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
			check(game.get_script().resource_path=="res://scripts/board_depth.gd","pack main board instantiates the actual depth controller")
			var stage=game.get("stage")
			check(is_instance_valid(stage) and stage.get_script().resource_path=="res://scripts/presentation/board_depth_stage.gd" and stage.game==game and stage.get_parent()==game and stage.visible and stage.z_index<0,"pack boots the actual attached depth stage, not inherited legacy constants")
			check(is_instance_valid(stage) and stage.BACKDROP!=null and stage.STONE!=null and stage.BACKDROP.get_width()>0 and stage.STONE.get_width()>0,"pack actually loads both new depth-stage textures")
			check(game.ui.card_portraits.all(func(item): return item.texture!=null and item.cropped.get_size()==item.region.size),"pack actually loads all six cropped current production portraits")
			check(game.ui.enemy_portraits.size()==4 and game.ui.enemy_portraits.all(func(item): return item.texture!=null) and game.ui.enemy_buttons.size()==7,"default pack loads four enemy portraits and seven specific inspection buttons")
			check(game.actors.all(func(actor): return actor.node.presentation.facing==(1 if actor.friendly else -1)),"pack starts with confirmed default army directions")
			check(is_equal_approx(game.BODY_SCALE,0.9) and game.actors.all(func(actor): return actor.node.scale==Vector2.ONE*game.BODY_SCALE and actor.node.position==GroundProjection.center(actor.cell) and actor.node.position==game.display_center(actor.cell) and not actor.node.presentation.show_shadow),"pack uses the actual projected foot positions, 0.9 body size and dedicated ground shadows")
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
			check(game.monk_sample_enabled and monk_view.motion_sample_enabled and monk_view.sample_body!=null and monk_view.sample_track!=null,"default pack really loads the enabled board monk sample")
			check(game.start_battle(),"default bear pack starts the real A deployment")
			while game.phase==game.Phase.BATTLE and game.elapsed<60: game.step(1.0/60)
			var settled: Dictionary=game.report()
			check(game.phase==game.Phase.RESULT and game.result_count==1 and settled.config==game.Config.version_for("bear") and settled.enemy_profile=="bear","default bear pack reaches one actual Result without requiring a historical A outcome")
			check((game._alive(game._record("tangseng")) and game.actors.filter(func(actor): return not actor.friendly).all(func(actor): return not game._alive(actor))) if game.victory else not game._alive(game._record("tangseng")),"default pack result obeys actual victory/failure conditions")
			print("BOARD_PACK_A profile=",game.enemy_profile," victory=",game.victory," seconds=",game.elapsed," TangHP=",settled.tangseng_hp)
		else:
			game._on_shop_pressed(0)
			check(game.heroes.size()==1 and game.coins==2,"legacy economy boots unchanged "+name)
			check(game.heroes[0].presentation.motion_sample_enabled==(name=="monk_animation_trial"),"only existing explicit monk entry adopts candidate "+name)
		print("BOARD_PACK_BOOT ",name)
		game.free()
	print("BOARD_PACK_BOOT failures=",failures)
	quit(1 if failures else 0)
