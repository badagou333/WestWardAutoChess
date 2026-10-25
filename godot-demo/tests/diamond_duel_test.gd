extends SceneTree
## D-20261018-002 author checks. Headless input is not native mouse/visual QA.
## All natural fights use the actual independent scene and unmodified AI.
const Grid = preload("res://scripts/data/diamond_duel_board.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
const Units = preload("res://scripts/data/demo_units.gd")
const SCENE := "res://scenes/diamond_duel.tscn"
const ART := "res://art/runtime/diamond_duel_v1/"
const REJECTED_FRAMES := ["monk_ne_move_b","wolf_se_move_b","wolf_ne_move_b"]
const DIRS := [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]
var failures := 0
var checks := 0
var cases: Array=[]
var naturals: Array=[]
var assets: Array=[]
var source_evidence: Dictionary={}
var output := "/tmp/diamond-duel-source.json"
var source := ""
var expect_packed := false

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func same(a, b) -> bool:
	if typeof(a) in [TYPE_FLOAT,TYPE_INT] and typeof(b) in [TYPE_FLOAT,TYPE_INT]:
		return absf(float(a)-float(b))<0.00000001
	if typeof(a)!=typeof(b): return false
	if a is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not same(a[i],b[i]): return false
		return true
	return a==b

func pair(point) -> Array:
	return [point.x,point.y]

func bytes_sha(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func fresh():
	var game=load(SCENE).instantiate()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	check(game.get_script().resource_path=="res://scripts/diamond_duel.gd","instantiates actual independent production scene, not an AI duplicate")
	return game

func snap(game) -> Dictionary:
	return {"specs":game.setup_specs.duplicate(true),"deployment":game.deployment.duplicate(true),"selected":game.selected,"phase":game.phase,"report":game.report().duplicate(true)}

func actor(game, id: String) -> Dictionary:
	return game._record(id)

func deploy_pair(game, monk_cell: Vector2i, wolf_cell: Vector2i) -> bool:
	# Rearrange through an actual empty cell: never depend on a particular
	# default or weaken the cross-army occupied-placement rejection.
	for cell in Grid.cells():
		if cell in [monk_cell,wolf_cell,actor(game,"monk").cell,actor(game,"wolf").cell]: continue
		return game.place("wolf",cell) and game.place("monk",monk_cell) and game.place("wolf",wolf_cell)
	return false

func expected_center(cell: Vector2i) -> Vector2:
	return Vector2(960+96*(cell.x-cell.y),588+48*(cell.x+cell.y))

func expected_valid(cell: Vector2i) -> bool:
	var p:=expected_center(cell)
	return p.x-96>=288 and p.x+96<=1632 and p.y-48>=300 and p.y+48<=876

func geometry() -> void:
	var expected: Array[Vector2i]=[]
	for y in range(-10,11):
		for x in range(-10,11):
			var cell:=Vector2i(x,y)
			var valid:=expected_valid(cell)
			check(Grid.valid(cell)==valid,"legal mask is four complete diamond vertices, not old rectangle "+str(cell))
			check(Grid.center(cell).is_equal_approx(expected_center(cell)),"center follows independent 2:1 affine formula "+str(cell))
			if valid: expected.append(cell)
	var actual: Array=Grid.cells()
	check(actual.size()==expected.size() and actual.all(func(cell): return cell in expected),"enumeration contains every and only complete cells")
	check(actual.has(Vector2i(-1,-1)),"negative lattice coordinate (-1,-1) is a real cell, not legacy invalid sentinel")
	var seen: Dictionary={actual[0]:true}
	var queue: Array=[actual[0]]
	var cursor:=0
	while cursor<queue.size():
		var c: Vector2i=queue[cursor]
		cursor+=1
		for direction in DIRS:
			var next: Vector2i=c+direction
			if next in expected and not seen.has(next):
				seen[next]=true
				queue.append(next)
	check(seen.size()==expected.size(),"complete-cell legal mask is connected under four logical neighbors")
	var edges:=0
	var rim:=0
	for cell in expected:
		var p:=expected_center(cell)
		check(Grid.cell_at(p)==cell,"every complete center picks itself "+str(cell))
		check(Grid.inverse(p).is_equal_approx(Vector2(cell)),"inverse and center agree "+str(cell))
		var polygon: PackedVector2Array=Grid.polygon(cell)
		var offsets: Array=[Vector2(0,-48),Vector2(96,0),Vector2(0,48),Vector2(-96,0)]
		check(polygon.size()==4,"draw polygon has exactly four vertices")
		for index in mini(4,polygon.size()):
			check(polygon[index].is_equal_approx(p+offsets[index]),"drawn polygon is exact 192 by 96, not arbitrary AI grid")
		for direction in DIRS:
			var next: Vector2i=cell+direction
			var midpoint: Vector2=(p+expected_center(next))*.5
			var normal: Vector2=(expected_center(next)-p).normalized()
			check(Grid.cell_at(midpoint-normal*.02)==cell,"shared/rim edge inside belongs to its complete cell")
			var picked: Vector2i=Grid.cell_at(midpoint+normal*.02)
			if next in expected:
				edges+=1
				check(picked==next,"shared edge opposite side belongs to logical four-neighbor")
			else:
				rim+=1
				check(not Grid.valid(picked),"residual half-cell never clamps to nearest full cell")
		for fraction in [0.125,0.5,0.875]:
			var grid_point:=Vector2(cell)+Vector2(fraction-.5,.125)
			check(Grid.inverse(Grid.point(grid_point)).is_equal_approx(grid_point),"continuous point inverse survives movement substeps")
	for point in [Vector2(287.98,588),Vector2(1632.02,588),Vector2(960,299.98),Vector2(960,876.02),Vector2(288,300),Vector2(1632,300),Vector2(288,876),Vector2(1632,876),Vector2(-500,0),Vector2(INF,0)]:
		check(not Grid.valid(Grid.cell_at(point)),"outer stone frame/corners/outside refuse placement "+str(point))
	cases.append({"case":"complete_diamond_mask_inverse_shared_edges_and_residual_rim","legal_cells":expected.size(),"directed_shared_edges":edges,"directed_rim_edges":rim,"connected":seen.size()==expected.size()})

func asset_checks(game) -> void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(ART+"manifest.json"))
	check(manifest is Dictionary,"runtime adaptation manifest loads from independent resource directory")
	if not manifest is Dictionary: return
	var frames: Array=manifest.get("frames",[])
	check(frames.size()==17,"runtime includes only seventeen recommended independent frames")
	var ids: Dictionary={}
	for frame in frames:
		var id:=str(frame.get("id",""))
		check(not ids.has(id) and id not in REJECTED_FRAMES,"known failed B frames and duplicates are excluded "+id)
		ids[id]=true
		var filename:=str(frame.get("image",""))
		var path:=filename if filename.begins_with("res://") else ART+filename
		check(path.begins_with(ART) and ResourceLoader.exists(path),"frame resolves inside this runtime pack, never old directional bank "+id)
		if not ResourceLoader.exists(path): continue
		var texture: Texture2D=load(path)
		check(texture!=null,"actual independent transparent frame loads "+id)
		if texture==null: continue
		var image:=texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		var raw_sha:=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		var rgba_sha:=bytes_sha(image.get_data())
		var expected_size: Array=frame.get("image_size",[])
		if expected_size.size()==2: check(texture.get_size()==Vector2(expected_size[0],expected_size[1]),"individual PNG keeps original extracted dimensions "+id)
		check(is_equal_approx(float(frame.get("uniform_scale_to_design",0)),.34),"one common fixed .34 art scale "+id)
		var body_size: Array=frame.get("body_size_design",[])
		check(body_size.size()==2 and float(body_size[0])>=80 and float(body_size[0])<=120 and float(body_size[1])>=90 and float(body_size[1])<=130,"body stays legible at approved single-tile scale, not giant or floor-sticker "+id)
		if not raw_sha.is_empty(): check(raw_sha==str(frame.get("sha256","")),"source frame bytes equal approved isolated PNG "+id)
		var reference: Dictionary={}
		for row in source_evidence.get("assets",[]):
			if row.id==id: reference=row
		if not source.is_empty(): check(not reference.is_empty() and reference.rgba_sha==rgba_sha,"actual pack decoded RGBA equals completed source frame "+id)
		if expect_packed: check(raw_sha.is_empty(),"packed frame comes through imported resource, no project PNG fallback "+id)
		assets.append({"id":id,"path":path,"raw_sha":raw_sha,"rgba_sha":rgba_sha,"size":pair(texture.get_size()),"support_complete":frame.get("support_complete",false),"all_feet_ground_complete":frame.get("all_feet_ground_complete",false)})
		if id.ends_with("idle"):
			check(bool(frame.get("all_feet_ground_complete",false)),"idle grounding uses actual complete visible feet "+id)
			for foot in frame.get("feet",[]):
				for p in foot.get("visible_envelope_design",[]):
					check(absf(float(p[0]))/96+absf(float(p[1]))/48<=.90001,"full idle foot envelope stays in assigned single diamond "+id)
		for foot in frame.get("feet",[]):
			if str(foot.get("support","")) in ["uncertain","swing"] or str(foot.get("visibility","")) in ["partial","occluded"]:
				check(foot.get("ground_projection_design")==null,"unknown/airborne/hidden sole is not replaced by fabricated ground coordinate "+id)
	for node_actor in game.actors:
		var view=node_actor.node.presentation
		check(node_actor.node.scale.is_equal_approx(Vector2.ONE),"actor never adds old .72 or .9 body scale")
		check(view.has_method("current_frame") and view.has_method("draw_sample"),"actual actor owns new independent frame adapter")
		if not view.has_method("current_frame") or not view.has_method("draw_sample"): continue
		for direction in [Vector2(96,48),Vector2(-96,48),Vector2(96,-48),Vector2(-96,-48)]:
			view.face(direction)
			view.set_pose("idle")
			var frame: Dictionary=view.current_frame()
			var sample: Dictionary=view.draw_sample()
			check(str(frame.get("id","")) in ids,"every facing uses a recommended frame, never old side-view fallback")
			check(str(frame.get("id","")).contains("_ne_" if direction.y<0 else "_se_"),"target screen up/down chooses actual back/front frame")
			var transform: Transform2D=sample.get("transform",Transform2D.IDENTITY)
			check(is_equal_approx(transform.x.length(),.34) and is_equal_approx(transform.y.length(),.34),"fixed .34 is applied once and not compounded "+str(direction))
			var destination: Rect2=sample.get("destination",Rect2())
			var anchor: Array=frame.get("anchor_crop",[])
			if anchor.size()==2:
				check((transform*(destination.position+Vector2(anchor[0],anchor[1]))).length()<.001,"mirror operates around common crop foot anchor")
			check(signf(transform.x.x)==signf(direction.x),"mirroring flips exactly once toward target")
		view.reset_visual()
		# Actual playback states retain the inherited attack clock; the adapter
		# selects only the approved preparation/contact pictures, never an atlas.
		for back in [false,true]:
			for facing in [-1.0,1.0]:
				view.face(Vector2(96*facing,-48 if back else 48))
				view.play_attack()
				var inherited_delay: float=view.Motion.release(view.motion)
				check(is_equal_approx(view.impact_delay(),inherited_delay),"new attack artwork cannot redefine the original hit clock")
				view.pose_time=maxf(0,inherited_delay-.00001)
				check(str(view.current_frame().id).ends_with("attack_prepare"),"attack remains in approved windup just before real release")
				view.pose_time=inherited_delay
				check(str(view.current_frame().id).ends_with("attack_contact"),"contact picture begins exactly on inherited damage clock")
				view.pose_time=view.Motion.duration(view.motion)
				view.update_frame()
				check(view.pose=="idle" and str(view.current_frame().id).ends_with("idle"),"actual recovery completes without a second animation timer")
		view.play_retreat()
		var dead_direction: Array=[view.direction_sign,view.direction_back]
		view.face(Vector2(-96,48))
		check(dead_direction==[view.direction_sign,view.direction_back],"dead artwork freezes its actual direction, no corpse target tracking")
		view.tick(float(view.manifest.actions.retreat.hold_seconds)+float(view.manifest.actions.retreat.fade_seconds)+.1)
		check(view.visual_alpha==0,"finite death presentation uses inherited fade instead of fabricated death frames")
		view.reset_visual()
	cases.append({"case":"seventeen_runtime_frames_fixed_scale_four_directions_and_honest_feet","frames":frames.size(),"native_visual_acceptance":false})

func configuration() -> void:
	var game=fresh()
	check(game.actors.size()==2 and actor(game,"monk").get("key")=="guard_monk" and actor(game,"wolf").get("key")=="wolf","exact one guard monk plus one mountain wolf, no implicit Tang")
	check(game.phase==game.Phase.DEPLOY,"independent sample boots in deployment")
	check(game.legal_cells().size()==Grid.cells().size(),"controller uses actual mask enumeration")
	asset_checks(game)
	var monk: Dictionary=actor(game,"monk")
	var wolf: Dictionary=actor(game,"wolf")
	var old: Vector2i=monk.cell
	var fixed: Dictionary=snap(game)
	check(not game.add_units(true,"guard_monk",1) and snap(game)==fixed,"sample rejects a second monk, even through inherited addition API")
	check(not game.add_units(false,"boar",1) and snap(game)==fixed,"sample cannot introduce any other enemy")
	var old_spec: Vector2i=game._spec("monk").cell
	game._spec("monk").cell=Vector2i(6,0)
	check(not game.start_battle() and game.phase==game.Phase.DEPLOY,"start validates complete-cell mask, not merely displayed placement")
	game._spec("monk").cell=old_spec
	game.select("monk")
	game._place_from_input(Vector2i(-2,0))
	check(monk.cell==Vector2i(-2,0) and game.selected.is_empty() and not game.pointer_drag,"successful selected drop releases ownership once")
	game.select("monk")
	var before: Dictionary=snap(game)
	check(not game.place("monk",wolf.cell) and snap(game)==before,"cross-army occupied destination rejects without moving either original")
	for invalid in [Vector2i(0,6),Vector2i(6,0),Vector2i(9,0),Grid.INVALID]:
		if Grid.valid(invalid): continue
		before=snap(game)
		game._place_from_input(invalid)
		check(snap(game)==before,"invalid/partial tile retains original placement and selection "+str(invalid))
	game.place("monk",old)
	check(game.actors.size()==2 and game.setup_specs.size()==2,"placement never adds/deletes sample roster")
	for item in game.actors:
		var stats: Dictionary=Units.HEROES.guard_monk if item.id=="monk" else Config.enemy_stats("wolf","bear")
		check(item.hp_max==stats.hp and item.damage==stats.damage and item.interval==stats.interval and item.reach==stats.range,"original combat catalog is retained "+item.id)
		check(item.walk==.5 and item.node.move_interval==.5,"screen geometry never changes .50-second logical steps")
	check(deploy_pair(game,Vector2i(-3,0),Vector2i(3,0)),"retry fixture explicitly deploys a distant real moving pair")
	check(game.start_battle(),"complete non-overlapping original pair starts real battle")
	check(not game._move(monk,Vector2i(6,0)),"actual movement entry refuses incomplete cell, not just click handler")
	var path: Array=game._path(monk,wolf.cell,1)
	check(not path.is_empty() and path.all(func(cell): return Grid.valid(cell)),"shared actual path query respects instance mask")
	game.toggle_pause()
	before=snap(game)
	check(not game.place("monk",Vector2i(0,0)) and snap(game)==before,"battle including pause remains configuration-locked")
	game.step(5)
	check(snap(game)==before,"pause freezes full report and exact setup")
	game.toggle_pause()
	game.step(.125)
	check(game.actors.any(func(item): return not item.move.is_empty()),"retry probe has real active half-second movement")
	game.retry()
	check(game.phase==game.Phase.BATTLE and game.elapsed==0 and not game.paused,"same-array retry resets and immediately restarts battle")
	check(game.actors.all(func(item): return item.move.is_empty() and item.target.is_empty() and item.cooldown==0 and item.step_serial==0 and item.step_wait.is_empty() and item.handoff.is_empty()),"retry clears real movement/next-step/handoff/target reservation state")
	check(game.step_requests.is_empty() and game.combat.strikes.is_empty() and game.combat.missiles.is_empty() and game.combat.marks.is_empty() and game.audio_feedback.seen.is_empty(),"retry clears pending attack/effects/audio serial state")
	game.return_to_setup()
	check(game.phase==game.Phase.DEPLOY and actor(game,"monk").cell==Vector2i(-3,0) and actor(game,"wolf").cell==Vector2i(3,0),"return goes back to editable exact start formation")
	cases.append({"case":"two_role_deployment_rejection_pause_lock_and_real_midwalk_retry","old_cell":pair(old)})
	game.free()

func mouse(game, point: Vector2, pressed: bool, button:=MOUSE_BUTTON_LEFT) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=button
	event.position=point
	event.global_position=point
	event.pressed=pressed
	if button==MOUSE_BUTTON_RIGHT: game._input(event)
	else: game._unhandled_input(event)

func logical_input() -> void:
	var game=fresh()
	var moved:=Vector2i(-2,1)
	game.ui.monk_button.pressed.emit()
	check(game.selected=="monk","actual monk portrait-card callback selects only its fixed instance")
	mouse(game,Grid.center(moved),true)
	mouse(game,Grid.center(moved),false)
	check(actor(game,"monk").cell==moved and game.selected.is_empty(),"controller logical click/release uses new inverse and clears selection")
	mouse(game,Grid.center(moved),true)
	check(game.selected=="monk" and game.pointer_drag,"placed character can begin real controller drag gesture")
	mouse(game,Vector2(280,588),false)
	check(actor(game,"monk").cell==moved and not game.pointer_drag,"drag released over outer frame ends gesture without relocating")
	game.ui.wolf_button.pressed.emit()
	check(game.selected=="wolf","actual wolf portrait-card callback selects its opposite-army instance")
	mouse(game,Vector2.ZERO,true,MOUSE_BUTTON_RIGHT)
	check(game.selected.is_empty(),"right mouse cancels current selection")
	game.select("monk")
	var escape:=InputEventKey.new()
	escape.pressed=true
	escape.keycode=KEY_ESCAPE
	game._unhandled_input(escape)
	check(game.selected.is_empty(),"Escape cancels without altering fixed roster")
	game.select("wolf")
	mouse(game,Grid.center(Vector2i(0,-2)),true)
	check(actor(game,"wolf").cell==Vector2i(0,-2) and game.selected.is_empty(),"enemy portrait selection deploys with identical inverse mapping")
	# A real STOP control lies over a valid board cell: prove GUI routing rather
	# than assuming off-board HUD coordinates cannot leak through.
	var layer:=CanvasLayer.new()
	layer.layer=100
	root.add_child(layer)
	var blocker:=Button.new()
	blocker.position=Grid.center(Vector2i(0,0))-Vector2(50,20)
	blocker.size=Vector2(100,40)
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	var pressed_count: Array=[0]
	blocker.pressed.connect(func(): pressed_count[0]+=1)
	layer.add_child(blocker)
	await process_frame
	game.select("monk")
	var original: Vector2i=actor(game,"monk").cell
	var point:=Grid.center(Vector2i(0,0))
	var motion:=InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	root.push_input(motion,true)
	await process_frame
	for pressed in [true,false]:
		var click:=InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		click.position=point
		click.global_position=point
		click.pressed=pressed
		root.push_input(click,true)
		await process_frame
	check(pressed_count[0]==1 and actor(game,"monk").cell==original,"Viewport delivers actual STOP control click over valid cell without board placement")
	layer.free()
	game.ui.start_button.pressed.emit()
	check(game.phase==game.Phase.BATTLE,"actual start control starts inherited combat")
	game.ui.pause_button.pressed.emit()
	check(game.paused,"actual pause control pauses without releasing deployment lock")
	var locked: Dictionary=game.deployment.duplicate(true)
	game.ui.monk_button.pressed.emit()
	mouse(game,Grid.center(Vector2i(0,0)),true)
	check(game.deployment==locked,"even callback-forced disabled card plus paused board click cannot change formation")
	game.ui.retry_button.pressed.emit()
	check(game.phase==game.Phase.BATTLE and game.elapsed==0 and not game.paused,"actual retry control starts same pair afresh")
	game.ui.return_button.pressed.emit()
	check(game.phase==game.Phase.DEPLOY,"actual return control explicitly stops and edits same start setup")
	cases.append({"case":"logical_mouse_drop_cancel_offboard_release_and_actual_stop_control_routing","OS_mouse":false,"viewport":pair(root.size)})
	game.free()

func event_row(game, event: Dictionary) -> Dictionary:
	var from: Dictionary=game._by_node(event.source)
	var target: Dictionary=game._by_node(event.target)
	return {"time":game.elapsed,"source":from.get("id",""),"target":target.get("id",""),"source_cell":pair(from.get("cell",Grid.INVALID)),"target_cell":pair(target.get("cell",Grid.INVALID)),"serial":int(event.get("serial",0)),"amount":float(event.get("amount",0)),"pose_time":float(event.view.pose_time),"impact_delay":float(event.view.impact_delay())}

func natural(label: String, start_a: Vector2i, start_b: Vector2i, pause_once:=false, fps:=120, speed:=1) -> Dictionary:
	var game=fresh()
	check(deploy_pair(game,start_a,start_b),"natural initial pair fits complete legal cells "+label)
	var requests: Array=[]
	var contacts: Array=[]
	var seen_requests: Dictionary={}
	var seen_contacts: Dictionary={}
	var directions: Dictionary={}
	var prior_cells: Dictionary={}
	var completed_steps:=0
	game.combat.resolved.connect(func(_target,_amount,_healing,event):
		var row:=event_row(game,event)
		var token:=str(row.source)+":"+str(row.serial)
		check(not seen_contacts.has(token),"natural damage is applied at most once per real attack serial "+label)
		seen_contacts[token]=true
		check(Config.distance(game._by_node(event.source).cell,game._by_node(event.target).cell)<=1,"real melee damage has an adjacent logical target "+label)
		check(row.pose_time+.000001>=row.impact_delay,"damage waits for original presentation impact clock "+label)
		contacts.append(row))
	check(game.start_battle(),"natural starts inherited AI "+label)
	game.speed=speed
	var did_pause:=false
	var occupancy_safe:=true
	var legal_safe:=true
	var visual_safe:=true
	var duration_safe:=true
	# Four base runs call once per original fixed tick; the pause/speed variant
	# uses real 30-FPS calls (still shorter than either inherited impact delay).
	while game.phase==game.Phase.BATTLE and game.elapsed<60:
		game.step(1.0/float(fps))
		for strike in game.combat.strikes:
			var row:=event_row(game,strike)
			var token:=str(row.source)+":"+str(row.serial)
			if not seen_requests.has(token):
				seen_requests[token]=true
				# Observation can be late within a frame-sized call. Use the
				# controller's actual request timestamp, not observation time.
				var times: Array=game.metrics.attack_times.get(row.source,[])
				row.time=times[-1] if not times.is_empty() else row.time
				row.erase("pose_time")
				requests.append(row)
				check(Config.distance(game._by_node(strike.source).cell,game._by_node(strike.target).cell)<=1,"AI requests melee only at true logical attack range "+label)
		var occupied: Dictionary={}
		for item in game.actors:
			if not game._active(item): continue
			legal_safe=legal_safe and Grid.valid(item.cell)
			occupancy_safe=occupancy_safe and not occupied.has(item.cell)
			occupied[item.cell]=item.id
			visual_safe=visual_safe and item.node.scale.is_equal_approx(Vector2.ONE)
			var position: Vector2=Grid.center(item.cell)
			if not item.move.is_empty():
				legal_safe=legal_safe and Grid.valid(item.move.to)
				var displacement: Vector2i=item.move.to-item.move.from
				directions[str(displacement)]=true
				position=Grid.point(Vector2(item.move.from).lerp(Vector2(item.move.to),minf(1,float(item.move.time)/float(item.move.duration))))
				duration_safe=duration_safe and is_equal_approx(float(item.move.duration),.5)
			visual_safe=visual_safe and item.node.position.distance_to(position)<.001
			if prior_cells.has(item.id) and prior_cells[item.id]!=item.cell:
				completed_steps+=1
				check(Config.distance(prior_cells[item.id],item.cell)==1,"each committed landing is one logical four-neighbor "+label)
			prior_cells[item.id]=item.cell
		# Source and destination are both reserved during interpolation.
		for item in game.actors:
			if not game._active(item) or item.move.is_empty(): continue
			occupancy_safe=occupancy_safe and (not occupied.has(item.move.to) or occupied[item.move.to]==item.id)
			occupied[item.move.to]=item.id
		if pause_once and not did_pause and game.elapsed>.2:
			game.toggle_pause()
			var before: Dictionary=game.report().duplicate(true)
			var state: Array=[]
			for item in game.actors: state.append([item.node.position,item.node.presentation.pose_time,item.node.presentation.frame_id])
			game.step(3)
			check(game.report()==before,"natural pause preserves full battle report "+label)
			for i in game.actors.size():
				var node=game.actors[i].node
				check(state[i]==[node.position,node.presentation.pose_time,node.presentation.frame_id],"natural pause freezes actual interpolated foot and frame "+label)
			game.toggle_pause()
			did_pause=true
	check(occupancy_safe and legal_safe,"entire natural fight never overlaps or leaves complete-cell mask "+label)
	check(visual_safe,"entire natural fight uses same logical interpolation and one fixed actor scale "+label)
	check(duration_safe,"every natural movement segment remains .50 seconds, independent of screen distance "+label)
	check(game.phase==game.Phase.RESULT and game.result_count==1,"natural real damage reaches exactly one Result, not synthetic timeout "+label)
	check(not requests.is_empty() and not contacts.is_empty(),"natural run truly requests attacks and applies damage "+label)
	check(game.combat.counts.hits==contacts.size(),"recorded real damage count equals inherited event resolver "+label)
	check(game.audio_feedback.audit.size()==contacts.size() and game.audio_feedback.rejected_keys.is_empty(),"each actual duel damage emits existing primary sound semantics with no forbidden result/death fallback")
	var audio: Array=[]
	for row in game.audio_feedback.audit:
		var source_id:=""
		for item in game.actors:
			if item.node.get_instance_id()==row.source_id: source_id=item.id
		audio.append({"source":source_id,"serial":row.serial,"source_key":row.source_key,"trigger":row.trigger,"key":row.key})
	var report: Dictionary=game.report().duplicate(true)
	var trace: Dictionary={"requests":requests,"contacts":contacts,"audio":audio}
	var row: Dictionary={"label":label,"initial_monk":pair(start_a),"initial_wolf":pair(start_b),"fps":fps,"speed":speed,"paused":did_pause,"report":report,"trace":trace,"completed_steps":completed_steps,"move_directions":directions.keys(),"safe_occupancy":occupancy_safe,"safe_legal_mask":legal_safe}
	if not source.is_empty():
		var reference: Dictionary={}
		for candidate in source_evidence.get("naturals",[]):
			if candidate.label==label: reference=candidate
		row["source_report_and_trace_equal"]=not reference.is_empty() and same(reference.report,report) and same(reference.trace,trace)
		check(row.source_report_and_trace_equal,"actual independent PCK full report and every critical event equals completed source "+label)
	game.retry()
	check(game.elapsed==0 and game.phase==game.Phase.BATTLE and actor(game,"monk").cell==start_a and actor(game,"wolf").cell==start_b,"post-result retry restores exact saved pair, not default positions "+label)
	check(game.combat.strikes.is_empty() and game.audio_feedback.seen.is_empty() and game.actors.all(func(item): return item.move.is_empty() and item.step_wait.is_empty() and item.handoff.is_empty()),"post-result retry clears all true pending movement/attack/audio "+label)
	game.free()
	return row

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		elif argument.begins_with("--source="): source=argument.trim_prefix("--source=")
		elif argument=="--expect-packed": expect_packed=true
	root.size=Vector2i(1920,1080)
	if not source.is_empty():
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(source)) if FileAccess.file_exists(source) else null
		check(parsed is Dictionary and parsed.get("failures",-1)==0,"completed external source evidence exists before pack comparison")
		if parsed is Dictionary: source_evidence=parsed
		else:
			quit(1)
			return
	if expect_packed:
		check(OS.has_feature("diamond_duel") and ProjectSettings.get_setting_with_override("application/run/main_scene")==SCENE,"dedicated pack starts this duel by default without a host scene argument")
		check(not FileAccess.file_exists("res://scripts/diamond_duel.gd"),"pack run has no loose production source fallback")
		check(not FileAccess.file_exists("res://art/candidates/rect_iso_duel_v1/manifest.json"),"isolated source candidate never enters final PCK")
	geometry()
	configuration()
	await logical_input()
	for setup in [
		["SE_NW_far",Vector2i(-3,0),Vector2i(3,0)],
		["SW_NE_far",Vector2i(0,-3),Vector2i(0,3)],
		["NW_SE_near",Vector2i(1,0),Vector2i(-1,0)],
		["NE_SW_edge",Vector2i(1,4),Vector2i(1,-4)]]:
		naturals.append(natural(setup[0],setup[1],setup[2]))
	naturals.append(natural("SE_NW_far_paused_fast",Vector2i(-3,0),Vector2i(3,0),true,30,2))
	check(same(naturals[0].report,naturals[4].report) and same(naturals[0].trace,naturals[4].trace),"paused/2x natural pair preserves complete report and original request/contact/audio sequence")
	var result: Dictionary={"scope":"D-20261018-002 author independent diamond duel","checks":checks,"failures":failures,"case_count":cases.size(),"natural_count":naturals.size(),"source_evidence":source,"expect_packed":expect_packed,"logical_input_not_OS_mouse":true,"device_listening":false,"cases":cases,"assets":assets,"naturals":naturals}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	check(file!=null,"caller-selected evidence output opens")
	result["checks"]=checks
	result["failures"]=failures
	if file!=null: file.store_string(JSON.stringify(result,"\t"))
	print("DIAMOND_DUEL checks=",checks," cases=",cases.size()," natural_runs=",naturals.size()," failures=",failures)
	quit(1 if failures else 0)
