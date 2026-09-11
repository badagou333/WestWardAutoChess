extends SceneTree

const Actor = preload("res://art/reviews/six-role-battle/actor.gd")
const ROLE_KEYS := ["guard_monk", "wild_hunter", "bear_lord"]

class Backdrop extends Node2D:
	var rows := 3
	var title_before := "BEFORE / single poses"
	var title_after := "AFTER / added frames"
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 80 + rows * 240), Color("17232d"))
		draw_line(Vector2(480, 48), Vector2(480, 60 + rows * 240), Color("39515d"))
		draw_string(ThemeDB.fallback_font, Vector2(120, 35), title_before, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("bbc8d1"))
		draw_string(ThemeDB.fallback_font, Vector2(565, 35), title_after, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("82dcc4"))
		for row in rows:
			var y := 277 + row * 240
			draw_line(Vector2(40, y), Vector2(920, y), Color("253d49"))

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var fox_only := OS.get_cmdline_user_args().has("--foxfire")
	var monk_recovery := OS.get_cmdline_user_args().has("--monk-recovery")
	var roles: Array = ["foxfire_imp"] if fox_only else ROLE_KEYS
	if monk_recovery: roles = ["guard_monk"]
	root.content_scale_size = Vector2i(960, 80 + roles.size() * 240)
	root.size = root.content_scale_size
	var backdrop := Backdrop.new(); backdrop.rows = roles.size()
	if monk_recovery:
		backdrop.title_before = "BEFORE / motion v1 / 0.5x"
		backdrop.title_after = "AFTER / recovery v2 / 0.5x"
	root.add_child(backdrop)
	var actors := []
	for row in roles.size():
		for column in 2:
			var actor := Actor.new()
			if monk_recovery and column == 0: actor.motion_revision = 1
			actor.setup_role(roles[row], "", [100, 1, 1])
			actor.use_motion_frames = column == 1 or monk_recovery
			actor.show_status = false; actor.show_anchor = false
			actor.scale = Vector2(1.35, 1.35)
			actor.position = Vector2(220 + column * 440, 215 + row * 240)
			root.add_child(actor); actors.append(actor)
	var output := "res://art/reviews/six-role-battle/.capture/comparison"
	if fox_only: output += "-foxfire"
	if monk_recovery: output += "-monk-recovery"
	DirAccess.make_dir_recursive_absolute(output)
	# Both columns use the identical actor implementation and timing, differing only in atlas toggle.
	for index in 96:
		if index == 6 and not fox_only and not monk_recovery:
			for actor in actors: actor.move_to(actor.position + Vector2(44, 0))
		if index in [30, 62]:
			for actor in actors:
				actor.face(actor.position + Vector2(200, 0)); actor.play_attack()
		for tick in 5:
			for actor in actors: actor.tick(1.0 / 240 if monk_recovery else 1.0 / 120)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + "/%03d.png" % index)
	print("FRAME_COMPARISON_OK: 96 actual engine frames, same timings in both columns")
	quit()
