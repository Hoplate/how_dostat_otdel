extends Node3D

var catalog: OfficeCatalog
var nav: OfficeNavigation
var world: OfficeWorld
var ui: OfficeUI
var player: OfficeActor
var npcs: Array[OfficeActor] = []
var audio: AudioStreamPlayer
var sounds: Dictionary = {}
var episode = 0
var level: Dictionary = {}
var difficulty: Dictionary = {}
var difficulty_id = "normal"
var mode = "menu"
var paused = false
var elapsed = 0.0
var states: Dictionary = {}
var inventory: Array = []
var pending_id = ""
var action_id = ""
var action_elapsed = 0.0
var action_duration = 0.0
var hover_id = ""
var hiding_id = ""
var sneaking = false
var inspect_mode = false
var suspicion = 0.0
var strikes = 0
var score = 0
var combo = 1
var best_combo = 1
var last_reaction = -100.0
var innocent_left = 0.0
var immunity_left = 0.0
var next_inspection = 35.0
var meeting_fired = false
var save_clock = 0.0
var visual_clock = 0.0
var capture_clock = -1.0
var capture_path = ""
var settings_from_menu = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	catalog = OfficeCatalog.new()
	nav = OfficeNavigation.new()
	world = OfficeWorld.new()
	add_child(world)
	ui = OfficeUI.new()
	add_child(ui)
	ui.command.connect(on_command)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	for pair in [["ready",700.0],["reaction",490.0],["caught",170.0],["item",950.0]]:
		sounds[pair[0]] = make_sound(pair[1])
	start_episode(0,false)
	mode = "menu"
	ui.show_menu(self)
	var args = OS.get_cmdline_user_args()
	if "--smoke-test" in args:
		start_episode(0,false)
	if "--capture" in args:
		var index = args.find("--capture")
		capture_path = args[index+1] if index+1 < args.size() else "user://gameplay.png"
		start_episode(5,false)
		world.zoom_target = 26.0
		world.focus = Vector3(13,0,9.0)
		world.set_camera_now()
		capture_clock = 2.0

func start_episode(index: int, brief: bool = true) -> void:
	episode = clampi(index,0,catalog.episodes.size()-1)
	level = catalog.episodes[episode]
	difficulty_id = str(Profile.data.difficulty)
	difficulty = OfficeCatalog.DIFFICULTY[difficulty_id]
	if is_instance_valid(player):
		remove_child(player)
		player.free()
	for npc in npcs:
		remove_child(npc)
		npc.free()
	npcs.clear()
	nav.build(catalog,episode)
	world.build(catalog,nav,episode)
	states.clear()
	for id in level.tasks:
		states[id] = "idle"
	inventory.clear()
	pending_id = ""
	action_id = ""
	hover_id = ""
	hiding_id = ""
	action_elapsed = 0
	action_duration = 0
	elapsed = 0
	suspicion = 0
	strikes = 0
	score = 0
	combo = 1
	best_combo = 1
	last_reaction = -100
	innocent_left = 0
	immunity_left = 2
	next_inspection = 35
	meeting_fired = false
	sneaking = false
	inspect_mode = false
	save_clock = 0
	player = OfficeActor.new()
	add_child(player)
	player.setup("dima",Vector2(6.0,8.3))
	for i in range(3):
		var id: String = ["lena","marina","pasha"][i]
		var npc = OfficeActor.new()
		add_child(npc)
		var initial: String = OfficeCatalog.ROUTES[id][0]
		npc.setup(id,catalog.objects[initial].use)
		for target in OfficeCatalog.ROUTES[id]:
			if catalog.available(target,episode):
				npc.route.append(target)
		npc.route_index = 1
		npc.destination = ""
		npc.wait_left = 4.0+i*1.3
		npc.facing = (catalog.objects[initial].pos-npc.ground).normalized()
		npcs.append(npc)
	mode = "play"
	paused = brief
	world.focus = Vector3(9.5,0,5.4) if episode < 2 else Vector3(13,0,9.0)
	world.zoom_target = 17.5 if episode < 2 else 26.0
	world.set_camera_now()
	ui.set_episode(self)
	if brief:
		ui.show_brief(self)

func _physics_process(delta: float) -> void:
	if mode != "play" or paused:
		return
	var raw = Input.get_vector("move_left","move_right","move_up","move_down")
	var right = Vector2(world.camera.global_basis.x.x,world.camera.global_basis.x.z).normalized()
	var back = Vector2(world.camera.global_basis.z.x,world.camera.global_basis.z.z).normalized()
	var movement = right*raw.x+back*raw.y
	if movement.length_squared() > .001:
		cancel_command(false)
		leave_hiding()
		var speed = 1.4 if sneaking else 2.75
		var before = player.ground
		player.ground = nav.slide(player.ground,movement*speed*delta)
		player.facing = movement
		player.moved = before.distance_to(player.ground) > .001
		player.sync_position()
	simulate(delta,movement.length_squared() > .001)

func _process(delta: float) -> void:
	if not is_instance_valid(world) or not is_instance_valid(ui):
		return
	world.update_camera(delta)
	ui.tick(delta)
	visual_clock += delta
	if visual_clock >= .1 and is_instance_valid(player):
		visual_clock = 0
		if mode == "play" and not paused:
			hover_id = world.pick(get_viewport().get_mouse_position())
		world.update_markers(states,level.tasks,hover_id,pending_id,inspect_mode)
		world.draw_intentions(player,npcs,inspect_mode and mode == "play")
		ui.refresh(self)
	if capture_clock >= 0:
		capture_clock -= delta
		if capture_clock < 0:
			await RenderingServer.frame_post_draw
			var image = get_viewport().get_texture().get_image()
			var result = image.save_png(capture_path)
			print("CAPTURE_RESULT=",result," PATH=",capture_path)
			get_tree().quit(0 if result == OK else 1)

func simulate(delta: float, manual_movement: bool = false) -> void:
	if mode != "play" or paused:
		return
	elapsed += delta
	innocent_left = maxf(0,innocent_left-delta)
	immunity_left = maxf(0,immunity_left-delta)
	player.reaction_left = maxf(0,player.reaction_left-delta)
	if not manual_movement:
		player.walk(delta,1.4 if sneaking else 2.75)
	if action_id != "":
		action_elapsed += delta
		if action_elapsed >= action_duration:
			complete_action()
	elif pending_id != "" and player.path.is_empty():
		var target = pending_id
		pending_id = ""
		if catalog.objects[target].use.distance_to(player.ground) < 1.05:
			begin_action(target)
		else:
			ui.toast("Не получилось подойти к объекту. Выберите другую точку.")
	for npc in npcs:
		step_npc(npc,delta)
	update_detection(delta)
	if level.get("meetingAt",0) > 0 and not meeting_fired and elapsed >= float(level.meetingAt):
		meeting_fired = true
		ui.toast("Совещание начинается. Коллеги идут в переговорную.")
		npcs[0].priorities.push_front("chair")
		npcs[1].priorities.push_front("whiteboard")
		npcs[2].priorities.push_front("projector")
	if level.get("boss",false) and elapsed >= next_inspection:
		next_inspection += 35
		for id in ["board","bossReport"]:
			if states.get(id,"") == "armed":
				trigger_reaction(id,null)
	if elapsed-last_reaction > 24:
		combo = 1
	player.animate(delta)
	for npc in npcs:
		npc.animate(delta)
	if completed_count() == level.tasks.size():
		finish(true)
	elif time_left() <= 0 or strikes >= 3:
		finish(false)
	if mode == "play":
		save_clock += delta
		if save_clock >= 5:
			save_clock = 0
			save_session()

func step_npc(npc: OfficeActor, delta: float) -> void:
	if npc.reaction_left > 0:
		npc.reaction_left = maxf(0,npc.reaction_left-delta)
		npc.moved = false
		return
	var speed = (1.0 if npc.actor_id == "pasha" else 1.14)*float(level.speed)*float(difficulty.speed)
	if npc.search_left > 0:
		npc.search_left = maxf(0,npc.search_left-delta)
		npc.repath_left -= delta
		if npc.repath_left <= 0:
			npc.path = nav.find_path(npc.ground,npc.last_seen)
			npc.repath_left = .85
		npc.walk(delta,speed*1.18)
		if npc.search_left <= 0:
			npc.path.clear()
			npc.destination = ""
			npc.wait_left = 1
		return
	if npc.wait_left > 0:
		npc.wait_left = maxf(0,npc.wait_left-delta)
		npc.moved = false
		return
	if not npc.path.is_empty():
		npc.walk(delta,speed)
		if not npc.path.is_empty():
			return
	if npc.destination != "" and catalog.objects.has(npc.destination):
		var object = catalog.objects[npc.destination]
		if npc.ground.distance_to(object.use) > .9:
			npc.path = nav.find_path(npc.ground,object.use)
			if not npc.path.is_empty():
				return
		else:
			npc.facing = (object.pos-npc.ground).normalized()
			var id = npc.destination
			npc.destination = ""
			npc.wait_left = 3.2 if npc.actor_id != "pasha" else 4.0
			if states.get(id,"") == "armed":
				var prank = catalog.pranks[id]
				if npc.actor_id == prank.npc or npc.actor_id in prank.also:
					trigger_reaction(id,npc)
			return
	var target = ""
	while not npc.priorities.is_empty():
		var priority = str(npc.priorities.pop_front())
		if catalog.available(priority,episode):
			target = priority
			break
	if target == "":
		target = str(npc.route[npc.route_index%npc.route.size()])
		npc.route_index += 1
	npc.destination = target
	npc.path = nav.find_path(npc.ground,catalog.objects[target].use)
	if npc.path.is_empty():
		npc.wait_left = 1
		npc.destination = ""

func visible_observers() -> Array[OfficeActor]:
	var result: Array[OfficeActor] = []
	if player.hidden:
		return result
	for npc in npcs:
		if npc.reaction_left <= 0 and npc.can_see(player.ground,nav,6.0 if npc.actor_id == "pasha" else 5.0):
			result.append(npc)
	return result

func update_detection(delta: float) -> void:
	if immunity_left > 0:
		return
	var observers = visible_observers()
	var doing_prank = action_id in level.tasks
	var in_restricted = level.get("boss",false) and catalog.room_at(player.ground) == "boss" and not player.hidden
	var increase = 0.0
	if doing_prank and not observers.is_empty():
		increase = (29+maxi(0,observers.size()-1)*9)*float(difficulty.detection)
	if in_restricted:
		increase += 3.8*float(difficulty.detection)
	for npc in observers:
		if suspicion >= 60:
			npc.search_left = 4
			npc.last_seen = player.ground
			increase += (10 if sneaking else 17)*float(difficulty.detection)
			if npc.ground.distance_to(player.ground) < 1.0:
				increase += 35
	if increase > 0:
		suspicion = minf(100,suspicion+increase*delta)
	else:
		suspicion = maxf(0,suspicion-(7 if player.hidden else 3.4)*delta)
	if suspicion >= 100:
		catch_player()

func catch_player() -> void:
	strikes += 1
	cancel_command(false)
	leave_hiding()
	player.ground = Vector2(6,8.3)
	player.sync_position()
	suspicion = 30
	immunity_left = 5
	for npc in npcs:
		npc.search_left = 0
		npc.path.clear()
		npc.destination = ""
		npc.wait_left = 2
	ui.toast("Дима, мы всё видели. Замечание %d из 3." % strikes)
	play_sound("caught")

func request_floor(point: Vector2) -> void:
	var room = catalog.room_at(point)
	if room == "" or not catalog.is_open(room,episode):
		ui.toast("Эта часть офиса пока закрыта.")
		return
	cancel_command(false)
	leave_hiding()
	var route = nav.find_path(player.ground,point)
	if route.is_empty():
		ui.toast("Сюда нет прохода.")
		return
	player.path = route

func request_object(id: String) -> void:
	if not catalog.available(id,episode):
		return
	var obj = catalog.objects[id]
	if obj.hide and player.hidden:
		leave_hiding()
		return
	if not is_interactive(id):
		ui.toast("%s. Сегодня у Димы другие планы." % obj.title)
		return
	if id in level.tasks:
		if states[id] != "idle":
			ui.toast("Ждём реакцию коллеги." if states[id] == "armed" else "Эта пакость уже засчитана.")
			return
		var need: String = catalog.pranks[id].need
		if need != "" and need not in inventory:
			ui.toast("Нужен %s. Его источник подсвечен." % OfficeCatalog.ITEMS[need])
			for source in catalog.objects.values():
				if need in source.items:
					hover_id = source.id
					world.focus_object(source.id)
			return
	cancel_command(false)
	leave_hiding()
	if obj.use.distance_to(player.ground) < 1.05:
		begin_action(id)
		return
	var route = nav.find_path(player.ground,obj.use)
	if route.is_empty():
		ui.toast("Не найден путь к объекту.")
		return
	player.path = route
	pending_id = id

func begin_action(id: String) -> void:
	var obj = catalog.objects[id]
	if obj.use.distance_to(player.ground) >= 1.05:
		return
	if obj.hide:
		if not visible_observers().is_empty():
			ui.toast("Сейчас на Диму смотрят. Незаметно спрятаться не выйдет.")
			return
		action_duration = .65
	elif not obj.items.is_empty():
		var missing = false
		for item in obj.items:
			missing = missing or item not in inventory
		if not missing:
			ui.toast("Всё нужное отсюда уже в карманах.")
			return
		action_duration = .7
	elif id in level.tasks and states[id] == "idle":
		var prank = catalog.pranks[id]
		if prank.need != "" and prank.need not in inventory:
			return
		action_duration = float(prank.duration)
	else:
		return
	action_id = id
	action_elapsed = 0
	player.facing = (obj.pos-player.ground).normalized()
	player.path.clear()

func complete_action() -> void:
	var id = action_id
	action_id = ""
	action_elapsed = 0
	var obj = catalog.objects[id]
	if obj.hide:
		if not visible_observers().is_empty():
			ui.toast("Коллега заметил движение у укрытия. Попробуйте позже.")
			return
		player.hidden = true
		hiding_id = id
		ui.toast("Дима спрятался. E или клик по полу — выйти.")
	elif not obj.items.is_empty():
		var received: Array[String] = []
		for item in obj.items:
			if item not in inventory and inventory.size() < 4:
				inventory.append(item)
				received.append(OfficeCatalog.ITEMS[item])
		ui.toast("В карманах: "+", ".join(received)+". Подходящий инструмент используется автоматически.")
		play_sound("item")
	else:
		states[id] = "armed"
		ui.toast("Подготовлено: %s. Отойдите и дождитесь реакции." % catalog.pranks[id].title)
		play_sound("ready")

func cancel_command(show_notice: bool = true) -> void:
	var was_active = action_id != "" or pending_id != "" or not player.path.is_empty()
	player.path.clear()
	pending_id = ""
	action_id = ""
	action_elapsed = 0
	action_duration = 0
	if show_notice and was_active:
		ui.toast("Команда отменена.")

func leave_hiding() -> void:
	player.hidden = false
	hiding_id = ""

func trigger_reaction(id: String, npc: OfficeActor) -> void:
	if states.get(id,"") != "armed":
		return
	states[id] = "done"
	combo = mini(7,combo+1) if elapsed-last_reaction <= 24 else 1
	best_combo = maxi(best_combo,combo)
	last_reaction = elapsed
	var prank = catalog.pranks[id]
	score += int(prank.points)*combo
	var speaker = "boss" if npc == null else npc.actor_id
	if npc != null:
		npc.say(prank.quote,4.6)
	ui.toast(OfficeCatalog.NAMES[speaker]+": «"+prank.quote+"»")
	play_sound("reaction")
	if catalog.cascade.has(id):
		var link = catalog.cascade[id]
		if str(link[1]) in level.tasks:
			for person in npcs:
				if person.actor_id == str(link[0]):
					person.priorities.push_front(str(link[1]))
			if str(link[0]) == "boss":
				next_inspection = minf(next_inspection,elapsed+6)

func innocent_face() -> void:
	if innocent_left > 0:
		return
	if action_id != "" or player.hidden:
		ui.toast("Сначала закончите действие и выйдите из укрытия.")
		return
	for id in states:
		if states[id] == "armed" and catalog.objects[id].use.distance_to(player.ground) < 2.2:
			ui.toast("Рядом слишком очевидные следы. Лучше отойти.")
			return
	cancel_command(false)
	suspicion = maxf(0,suspicion-24)
	innocent_left = 18
	player.say("Я вообще мимо проходил.",2.2)
	play_sound("item")

func nearest_interactable() -> String:
	var best = ""
	var distance = 1.65
	for id in catalog.objects:
		if not catalog.available(id,episode) or not is_interactive(id):
			continue
		var use_at: Vector2 = catalog.objects[id].use
		var d = player.ground.distance_to(use_at)
		if d < distance and nav.line_of_sight(player.ground,use_at):
			distance = d
			best = id
	return best

func is_interactive(id: String) -> bool:
	var obj = catalog.objects[id]
	return obj.hide or not obj.items.is_empty() or id in level.tasks

func verb(id: String) -> String:
	var obj = catalog.objects[id]
	if obj.hide:
		return "Спрятаться"
	if not obj.items.is_empty():
		return "Забрать предметы"
	if id in level.tasks:
		return catalog.pranks[id].action
	return "Осмотреть"

func object_hint(id: String) -> String:
	var obj = catalog.objects[id]
	if obj.hide:
		return "ЛКМ / E: подойти и спрятаться. Нельзя прятаться на глазах у коллег."
	if not obj.items.is_empty():
		var names: Array[String] = []
		for item in obj.items:
			names.append(OfficeCatalog.ITEMS[item])
		return "ЛКМ: забрать за один раз — "+", ".join(names)+"."
	if id not in level.tasks:
		return "В этом эпизоде объект не входит в план Димы."
	var state = states[id]
	if state == "armed":
		var target = OfficeCatalog.NAMES[catalog.pranks[id].npc]
		return "Подготовлено. Ждём: "+target+(" · проверка через %d с" % ceili(next_inspection-elapsed) if catalog.pranks[id].npc == "boss" else "")
	if state == "done":
		return "Реакция засчитана. Пора готовить следующую пакость."
	var prank = catalog.pranks[id]
	var need = "Без предметов" if prank.need == "" else ("В кармане: " if prank.need in inventory else "Нужен: ")+OfficeCatalog.ITEMS[prank.need]
	return "%s · %.1f с · ЛКМ: подойти и сделать · ПКМ: отменить" % [need,float(prank.duration)]

func completed_count() -> int:
	var result = 0
	for state in states.values():
		if state == "done":
			result += 1
	return result

func time_left() -> float:
	return maxf(0,float(level.get("seconds",420))*float(difficulty.get("time",1))-elapsed)

func finish(victory: bool) -> void:
	if mode != "play":
		return
	mode = "result"
	paused = false
	cancel_command(false)
	Profile.data.session = {}
	if victory:
		Profile.data.unlocked = maxi(int(Profile.data.unlocked),mini(9,episode+1))
		var key = str(episode)
		var previous = int(Profile.data.best.get(key,{}).get("score",0))
		if score >= previous:
			Profile.data.best[key] = {"score":score,"combo":best_combo,"strikes":strikes}
	Profile.save()
	ui.show_result(self,victory)

func save_session() -> void:
	if mode != "play":
		return
	var coworkers: Dictionary = {}
	for npc in npcs:
		coworkers[npc.actor_id] = npc.snapshot()
	Profile.data.session = {"episode":episode,"difficulty":difficulty_id,"elapsed":elapsed,"states":states.duplicate(),"inventory":inventory.duplicate(),"player":player.snapshot(),"npcs":coworkers,"suspicion":suspicion,"strikes":strikes,"score":score,"combo":combo,"best_combo":best_combo,"last_reaction":last_reaction,"innocent_left":innocent_left,"next_inspection":next_inspection,"meeting_fired":meeting_fired,"sneaking":sneaking,"hiding_id":hiding_id}
	Profile.save()
	if Profile.last_error != "":
		ui.toast(Profile.last_error)

func continue_session() -> void:
	var state: Dictionary = Profile.data.session.duplicate(true)
	if state.is_empty():
		start_episode(int(Profile.data.unlocked))
		return
	start_episode(clampi(int(state.get("episode",0)),0,9),false)
	difficulty_id = str(state.get("difficulty","normal"))
	if not OfficeCatalog.DIFFICULTY.has(difficulty_id):
		difficulty_id = "normal"
	difficulty = OfficeCatalog.DIFFICULTY[difficulty_id]
	elapsed = clampf(float(state.get("elapsed",0)),0,float(level.seconds)*float(difficulty.time))
	var saved_states = state.get("states",{})
	if saved_states is Dictionary:
		for id in states:
			if saved_states.get(id,"") in ["idle","armed","done"]:
				states[id] = saved_states[id]
	var items = state.get("inventory",[])
	if items is Array:
		for item in items:
			if OfficeCatalog.ITEMS.has(item) and item not in inventory:
				inventory.append(item)
	if state.get("player",{}) is Dictionary:
		player.restore(state.get("player",{}),nav)
	for npc in npcs:
		var people = state.get("npcs",{})
		if people is Dictionary and people.get(npc.actor_id,{}) is Dictionary:
			npc.restore(people.get(npc.actor_id,{}),nav)
	suspicion = clampf(float(state.get("suspicion",0)),0,99)
	strikes = clampi(int(state.get("strikes",0)),0,2)
	score = maxi(0,int(state.get("score",0)))
	combo = clampi(int(state.get("combo",1)),1,7)
	best_combo = clampi(int(state.get("best_combo",1)),1,7)
	last_reaction = float(state.get("last_reaction",-100))
	innocent_left = clampf(float(state.get("innocent_left",0)),0,18)
	next_inspection = maxf(elapsed+1,float(state.get("next_inspection",35)))
	meeting_fired = bool(state.get("meeting_fired",false))
	sneaking = bool(state.get("sneaking",false))
	hiding_id = str(state.get("hiding_id",""))
	immunity_left = 2
	paused = true
	ui.show_pause(self)
	ui.toast("Смена восстановлена. Незавершённая подготовка отменена — новые действия запускаете только вы.")

func on_command(action: String, value: Variant) -> void:
	match action:
		"start":
			start_episode(int(value))
		"continue":
			continue_session()
		"pause":
			if mode == "play":
				paused = true
				save_session()
				ui.show_pause(self)
		"resume":
			paused = false
			ui.close_overlay()
		"settings":
			settings_from_menu = mode == "menu"
			if mode == "play":
				paused = true
				save_session()
			ui.show_settings(self)
		"close_settings":
			Profile.save()
			if settings_from_menu:
				ui.close_overlay()
			else:
				ui.show_pause(self)
		"reset_keys":
			Profile.data.keys = {}
			Profile.apply_keys()
			Profile.save()
			ui.show_settings(self)
		"menu":
			if mode == "play":
				save_session()
			mode = "menu"
			paused = false
			ui.show_menu(self)
		"restart":
			start_episode(episode)
		"quit":
			save_session()
			Profile.save()
			get_tree().quit()
		"focus":
			world.focus_object(str(value))
			hover_id = str(value)
		"sneak":
			if mode == "play" and not paused:
				sneaking = not sneaking
		"innocent":
			if mode == "play" and not paused:
				innocent_face()
		"inspect":
			inspect_mode = not inspect_mode

func _input(event: InputEvent) -> void:
	# A right click always cancels, including when the pointer is over the HUD.
	if mode == "play" and not paused and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_command()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(ui) or ui.binding_action != "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode in [KEY_ESCAPE,KEY_SPACE]:
			if ui.modal_kind == "settings":
				on_command("close_settings",null)
			elif mode == "play":
				on_command("resume" if paused else "pause",null)
			get_viewport().set_input_as_handled()
			return
	if mode != "play" or paused:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_command()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			world.zoom_target = clampf(world.zoom_target-1.25,10,30)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			world.zoom_target = clampf(world.zoom_target+1.25,10,30)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var id = world.pick(event.position)
			if id != "":
				request_object(id)
			else:
				var point = world.floor_point(event.position)
				if point != null:
					request_floor(point)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		world.pan(event.relative)
	if event.is_action_pressed("interact"):
		if player.hidden:
			leave_hiding()
		else:
			var id = nearest_interactable()
			if id != "":
				request_object(id)
	elif event.is_action_pressed("sneak"):
		sneaking = not sneaking
	elif event.is_action_pressed("innocent"):
		innocent_face()
	elif event.is_action_pressed("inspect"):
		inspect_mode = not inspect_mode
	elif event.is_action_pressed("recenter"):
		world.recenter(player.ground)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "play" and is_instance_valid(ui):
		paused = true
		save_session()
		ui.show_pause(self)
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(player):
			save_session()
		get_tree().quit()

func make_sound(frequency: float) -> AudioStreamWAV:
	var data = PackedByteArray()
	var rate = 22050
	var length = int(rate*.18)
	data.resize(length*2)
	for i in range(length):
		var time = float(i)/rate
		var envelope = sin(PI*float(i)/length)
		var value = sin(TAU*frequency*time)*envelope*.15
		data.encode_s16(i*2,int(value*32767))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

func play_sound(id: String) -> void:
	if not Profile.test_mode:
		audio.stream = sounds[id]
		audio.play()
