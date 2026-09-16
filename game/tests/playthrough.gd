extends SceneTree

var game
var records: Array = []

func _initialize() -> void:
	call_deferred("run")

func step(seconds: float) -> void:
	for i in range(ceili(seconds/.1)):
		if game.mode != "play":
			return
		game.simulate(.1)

func move_to(point: Vector2) -> void:
	game.request_floor(point)
	var limit: float = game.elapsed+30
	while game.mode == "play" and not game.player.path.is_empty() and game.elapsed < limit:
		step(.1)

func collect(source: String) -> void:
	move_to(game.catalog.objects[source].use)
	game.request_object(source)
	step(1)

func prepare(id: String) -> void:
	for attempt in range(8):
		if game.mode != "play" or game.states[id] != "idle":
			return
		move_to(game.catalog.objects[id].use)
		var limit: float = game.elapsed+45
		while game.mode == "play" and not game.visible_observers().is_empty() and game.elapsed < limit:
			step(.1)
		game.request_object(id)
		while game.mode == "play" and game.action_id != "":
			if game.suspicion > 47:
				game.cancel_command(false)
				break
			step(.1)
		if game.mode != "play" or game.states[id] != "idle":
			return
		move_to(Vector2(6,8.3))
		game.innocent_face()
		step(5)

func run() -> void:
	root.get_node("Profile").data.difficulty = "normal"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for episode in range(10):
		game.start_episode(episode,false)
		# No teleports, invulnerability overrides, direct arming or NPC changes.
		collect("stationery")
		if game.catalog.available("paperSupply",episode):
			collect("paperSupply")
		if game.catalog.available("remoteSupply",episode):
			collect("remoteSupply")
		for id in game.level.tasks:
			prepare(id)
		move_to(Vector2(6,8.3))
		while game.mode == "play":
			step(.1)
		var victory = game.completed_count() == game.level.tasks.size()
		records.append({"episode":episode+1,"title":game.level.title,"victory":victory,"elapsed_seconds":snappedf(game.elapsed,.1),"strikes":game.strikes,"score":game.score,"states":game.states.duplicate()})
		print("PLAYTHROUGH %02d: %s in %.1fs, strikes=%d" % [episode+1,"WIN" if victory else "LOSS",game.elapsed,game.strikes])
		await process_frame
	var won = 0
	for record in records:
		if record.victory:
			won += 1
	var args = OS.get_cmdline_user_args()
	var output = "user://playthrough_results.json"
	if "--report" in args:
		output = args[args.find("--report")+1]
	var f = FileAccess.open(output,FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"kind":"native headless command-level simulation; not GUI/human playtesting","difficulty":"normal","step_seconds":0.1,"detection_disabled":false,"teleports":false,"wins":won,"episodes":records},"  "))
		f.close()
	root.remove_child(game)
	game.queue_free()
	await process_frame
	quit(0 if won == 10 else 1)
