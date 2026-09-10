extends SceneTree

const Actor = preload("res://art/reviews/six-role-battle/actor.gd")
const ROLE_KEYS := ["guard_monk", "wild_hunter", "bear_lord"]

class Backdrop extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 800), Color("17232d"))
		draw_line(Vector2(480, 48), Vector2(480, 780), Color("39515d"))
		draw_string(ThemeDB.fallback_font, Vector2(170, 35), "BEFORE / single poses", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("bbc8d1"))
		draw_string(ThemeDB.fallback_font, Vector2(610, 35), "AFTER / added frames", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("82dcc4"))
		for y in [277, 517, 757]:
			draw_line(Vector2(40, y), Vector2(920, y), Color("253d49"))

func _init() -> void:
	call_deferred("run")

func run() -> void:
	root.content_scale_size = Vector2i(960, 800)
	root.size = Vector2i(960, 800)
	var backdrop := Backdrop.new(); root.add_child(backdrop)
	var actors := []
	for row in 3:
		for column in 2:
			var actor := Actor.new()
			actor.setup_role(ROLE_KEYS[row], "", [100, 1, 1])
			actor.use_motion_frames = column == 1
			actor.show_status = false; actor.show_anchor = false
			actor.scale = Vector2(1.35, 1.35)
			actor.position = Vector2(220 + column * 440, 215 + row * 240)
			root.add_child(actor); actors.append(actor)
	var output := "res://art/reviews/six-role-battle/.capture/comparison"
	DirAccess.make_dir_recursive_absolute(output)
	# Both columns use the identical actor implementation and timing, differing only in atlas toggle.
	for index in 96:
		if index == 6:
			for actor in actors: actor.move_to(actor.position + Vector2(44, 0))
		if index in [30, 62]:
			for actor in actors:
				actor.face(actor.position + Vector2(200, 0)); actor.play_attack()
		for tick in 5:
			for actor in actors: actor.tick(1.0 / 120)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + "/%03d.png" % index)
	print("FRAME_COMPARISON_OK: 96 actual engine frames, same timings in both columns")
	quit()
