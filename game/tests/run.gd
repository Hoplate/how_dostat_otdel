extends SceneTree

var results: Array = []
var failures = 0
var game
var profile

func _initialize() -> void:
	call_deferred("run")

func check(name: String, condition: bool, detail: String = "") -> void:
	results.append({"name":name,"passed":condition,"detail":detail})
	if not condition:
		failures += 1
		print("FAIL: ",name," ",detail)

func ticks(seconds: float) -> void:
	for i in range(ceili(seconds/.05)):
		game.simulate(.05)

func place_player(point: Vector2) -> void:
	game.cancel_command(false)
	game.player.ground = point
	game.player.sync_position()

func quiet_observers() -> void:
	for i in range(game.npcs.size()):
		game.npcs[i].ground = Vector2(20+i,4)
		game.npcs[i].facing = Vector2(0,-1)
		game.npcs[i].wait_left = 100
		game.npcs[i].path.clear()
		game.npcs[i].reaction_left = 0

func run() -> void:
	profile = root.get_node("Profile")
	var scene = load("res://scenes/main.tscn")
	check("Main scene loads",scene is PackedScene)
	if not scene is PackedScene:
		finish_tests()
		return
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	check("Native engine",Engine.get_version_info().major == 4)
	check("Four coherent character textures",ResourceLoader.exists("res://assets/characters/dima.webp") and ResourceLoader.exists("res://assets/characters/lena.webp") and ResourceLoader.exists("res://assets/characters/marina.webp") and ResourceLoader.exists("res://assets/characters/pasha.webp"))
	for episode in range(10):
		game.start_episode(episode,false)
		var paths_ok = true
		var detail = ""
		var checked = 0
		for id in game.catalog.objects:
			if not game.catalog.available(id,episode):
				continue
			var point: Vector2 = game.catalog.objects[id].use
			var path = game.nav.find_path(Vector2(6,8.3),point)
			var valid = not path.is_empty() and game.nav.is_clear(point) and path[-1].distance_to(point) < .25
			var previous = Vector2(6,8.3)
			for step in path:
				valid = valid and game.nav.segment_clear(previous,step)
				previous = step
			if not valid:
				paths_ok = false
				detail += id+"; "
			checked += 1
		check("Episode %02d: all %d use-points reachable, no wall/corner clipping" % [episode+1,checked],paths_ok,detail)
		var requirements_ok = true
		for id in game.level.tasks:
			requirements_ok = requirements_ok and game.catalog.available(id,episode) and game.catalog.pranks.has(id)
			var need: String = game.catalog.pranks[id].need
			if need != "":
				var found = false
				for source in game.catalog.objects.values():
					found = found or (need in source.items and game.catalog.available(source.id,episode))
				requirements_ok = requirements_ok and found
		check("Episode %02d: every objective and required item is available" % (episode+1),requirements_ok)
	game.start_episode(5,false)
	check("Walls block visibility",not game.nav.line_of_sight(Vector2(11,4),Vector2(13,4)))
	check("Doorway permits visibility",game.nav.line_of_sight(Vector2(6,6.3),Vector2(6,8.3)))
	check("Furniture blocks walking",not game.nav.is_clear(game.catalog.objects.coffee.pos))
	check("Outside map is blocked",not game.nav.is_clear(Vector2(-2,4)))
	quiet_observers()
	place_player(game.catalog.objects.stationery.use)
	game.request_object("stationery")
	ticks(.8)
	check("One click collects both stationery tools",game.inventory.size() == 2 and "marker" in game.inventory and "stickers" in game.inventory)
	place_player(game.catalog.objects.paperSupply.use)
	game.request_object("paperSupply")
	ticks(.8)
	place_player(game.catalog.objects.remoteSupply.use)
	game.request_object("remoteSupply")
	ticks(.8)
	check("Inventory has exactly four persistent tools",game.inventory.size() == 4)
	game.request_object("remoteSupply")
	check("Already collected source does not create duplicates",game.inventory.size() == 4 and game.action_id == "")
	game.start_episode(0,false)
	quiet_observers()
	place_player(game.catalog.objects.mouse.use)
	game.request_object("mouse")
	check("Missing item prevents prank",game.action_id == "" and game.states.mouse == "idle")
	place_player(game.catalog.objects.calendar.use)
	game.request_object("calendar")
	ticks(.4)
	game.cancel_command()
	ticks(2)
	check("RMB cancellation never arms interrupted prank",game.action_id == "" and game.states.calendar == "idle")
	game.request_floor(Vector2(6,8.3))
	check("Floor click creates path",not game.player.path.is_empty())
	game.cancel_command()
	check("Cancellation clears movement and pending interaction",game.player.path.is_empty() and game.pending_id == "")
	place_player(game.catalog.objects.calendar.use)
	game.request_object("calendar")
	ticks(2)
	check("Preparation only arms; does not score",game.states.calendar == "armed" and game.score == 0)
	game.trigger_reaction("calendar",game.npcs[0])
	var first_score = game.score
	game.trigger_reaction("calendar",game.npcs[0])
	check("Reaction scores exactly once",game.states.calendar == "done" and first_score > 0 and game.score == first_score)
	game.states.mouse = "armed"
	game.trigger_reaction("mouse",game.npcs[0])
	check("Close reactions build a combo",game.combo == 2)
	game.elapsed += 25
	game.states.mug = "armed"
	game.trigger_reaction("mug",game.npcs[1])
	check("Combo expires after its window",game.combo == 1)
	game.start_episode(5,false)
	quiet_observers()
	place_player(game.catalog.objects.coat.use)
	game.request_object("coat")
	ticks(.8)
	check("Context action enters cover",game.player.hidden and game.hiding_id == "coat")
	game.on_command("sneak",null)
	check("Sneaking is a persistent toggle",game.sneaking)
	game.request_floor(Vector2(8.6,6.2))
	check("Floor click exits cover",not game.player.hidden and game.hiding_id == "")
	game.start_episode(0,false)
	quiet_observers()
	place_player(game.catalog.objects.calendar.use)
	game.npcs[0].ground = game.player.ground+Vector2(0,1.3)
	game.npcs[0].facing = Vector2(0,-1)
	game.npcs[0].sync_position()
	game.immunity_left = 0
	game.request_object("calendar")
	ticks(.5)
	check("Witnesses raise suspicion while preparing a prank",game.suspicion > 0)
	game.cancel_command(false)
	quiet_observers()
	place_player(Vector2(6,8.3))
	game.suspicion = 45
	game.innocent_face()
	check("Innocent face lowers suspicion and starts cooldown",is_equal_approx(game.suspicion,21) and game.innocent_left == 18)
	game.innocent_face()
	check("Ability cannot be spammed",is_equal_approx(game.suspicion,21))
	game.innocent_left = 0
	game.states.calendar = "armed"
	place_player(game.catalog.objects.calendar.use)
	game.innocent_face()
	check("Evidence prevents innocent-face exploit",game.innocent_left == 0)
	game.on_command("pause",null)
	var clock = game.elapsed
	ticks(2)
	check("Pause freezes simulation time",is_equal_approx(clock,game.elapsed))
	game.on_command("resume",null)
	ticks(.2)
	check("Resume restarts simulation",game.elapsed > clock)
	game.inventory = ["marker","stickers"]
	game.elapsed = 48.25
	game.suspicion = 33
	game.score = 120
	game.save_session()
	game.continue_session()
	check("In-progress save restores state and opens paused",game.paused and is_equal_approx(game.elapsed,48.25) and is_equal_approx(game.suspicion,33) and game.score == 120 and game.states.calendar == "armed" and game.inventory.size() == 2)
	check("Resume does not silently restart an interrupted command",game.action_id == "" and game.pending_id == "")
	check("Reserved key binding is rejected",not profile.rebind("interact",KEY_ESCAPE))
	check("Duplicate key binding is rejected",not profile.rebind("interact",KEY_W))
	check("Physical key can be remapped",profile.rebind("interact",KEY_R))
	check("Physical remap is applied to InputMap",InputMap.action_get_events("interact")[0].physical_keycode == KEY_R)
	profile.data.keys = {}
	profile.apply_keys()
	game.start_episode(5,false)
	game.elapsed = 99.98
	game.simulate(.05)
	check("Meeting event fires on schedule",game.meeting_fired and "chair" in game.npcs[0].priorities)
	game.start_episode(7,false)
	game.states.board = "armed"
	game.states.bossReport = "armed"
	game.elapsed = 34.98
	game.simulate(.05)
	check("Off-screen supervisor inspection resolves its objectives",game.states.board == "done" and game.states.bossReport == "done")
	game.start_episode(0,false)
	for id in game.states:
		game.states[id] = "armed"
		game.trigger_reaction(id,game.npcs[0])
	game.simulate(.05)
	check("All reactions finish episode and unlock the next",game.mode == "result" and int(profile.data.unlocked) >= 1 and profile.data.session.is_empty())
	game.start_episode(0,false)
	game.strikes = 3
	game.simulate(.05)
	check("Three strikes end the shift",game.mode == "result" and game.completed_count() == 0)
	# These are integration/unit checks, not a claim of human playthrough or art approval.
	game.mode = "menu"
	root.remove_child(game)
	game.queue_free()
	await process_frame
	finish_tests()

func finish_tests() -> void:
	var args = OS.get_cmdline_user_args()
	var out = "user://test_results.json"
	if "--report" in args:
		out = args[args.find("--report")+1]
	var report = {"engine":Engine.get_version_info().string,"kind":"headless Godot unit and integration checks","checks":results.size(),"failures":failures,"results":results}
	var f = FileAccess.open(out,FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report,"  "))
		f.close()
	print("TEST_RESULT: ",results.size()-failures,"/",results.size()," passed; ",failures," failed")
	quit(0 if failures == 0 else 1)
