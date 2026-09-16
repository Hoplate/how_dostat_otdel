class_name OfficeActor
extends Node3D

var actor_id = "dima"
var ground = Vector2.ZERO
var facing = Vector2(0,-1)
var path = PackedVector2Array()
var route: Array = []
var route_index = 0
var destination = ""
var priorities: Array = []
var wait_left = 0.0
var reaction_left = 0.0
var search_left = 0.0
var repath_left = 0.0
var last_seen = Vector2.ZERO
var hidden = false
var moved = false
var height = 2.15
var phase = 0.0
var body: Sprite3D
var nameplate: Label3D
var speech: Label3D
var foot_shadow: MeshInstance3D

func setup(id: String, where: Vector2) -> void:
	actor_id = id
	ground = where
	height = OfficeCatalog.HEIGHTS[id]
	body = Sprite3D.new()
	body.texture = load("res://assets/characters/%s.webp" % id)
	body.pixel_size = height/body.texture.get_height()
	body.position.y = height/2.0
	body.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	body.alpha_scissor_threshold = 0.18
	body.no_depth_test = false
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	var mesh = CylinderMesh.new()
	mesh.top_radius = .43 if id == "pasha" else .32
	mesh.bottom_radius = mesh.top_radius
	mesh.height = .015
	mesh.radial_segments = 24
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.04,0.03,0.025,.23)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foot_shadow = MeshInstance3D.new()
	foot_shadow.mesh = mesh
	foot_shadow.material_override = mat
	foot_shadow.position.y = .018
	foot_shadow.scale.z = .64
	foot_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foot_shadow)
	nameplate = make_label(OfficeCatalog.NAMES[id],36)
	nameplate.position.y = height+.22
	nameplate.modulate = Color(OfficeCatalog.COLORS[id])
	add_child(nameplate)
	speech = make_label("",37)
	speech.position.y = height+.72
	speech.width = 460
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.visible = false
	add_child(speech)
	sync_position()

func make_label(text: String, size: int) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 9
	label.outline_modulate = Color(0.07,0.08,0.09,.95)
	label.pixel_size = .006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	return label

func sync_position() -> void:
	position = Vector3(ground.x,0,ground.y)

func walk(delta: float, speed: float) -> void:
	moved = false
	var budget = delta*speed
	while budget > 0 and not path.is_empty():
		var offset = path[0]-ground
		var length = offset.length()
		if length <= .025:
			ground = path[0]
			path.remove_at(0)
			continue
		facing = offset/length
		var step = minf(budget,length)
		ground += facing*step
		budget -= step
		moved = true
		if step >= length:
			path.remove_at(0)
	sync_position()

func animate(delta: float) -> void:
	phase += delta
	var bob = sin(phase*11.0)*.045 if moved else sin(phase*2.3)*.012
	body.position.y = height/2.0+bob
	body.rotation.z = sin(phase*11.0)*.025 if moved else 0.0
	if reaction_left > 0:
		body.rotation.z = sin(phase*15.0)*.055
		body.position.y += absf(sin(phase*6.0))*.10
	if absf(facing.x) > .12:
		body.flip_h = facing.x < 0
	body.modulate.a = .28 if hidden else 1.0
	foot_shadow.visible = not hidden
	nameplate.text = OfficeCatalog.NAMES[actor_id]+(" · скрыт" if hidden else (" !" if search_left > 0 else ""))
	speech.visible = reaction_left > 0

func can_see(point: Vector2, nav: OfficeNavigation, range_limit: float = 5.0) -> bool:
	var offset = point-ground
	var distance = offset.length()
	if distance > range_limit or not nav.line_of_sight(ground,point):
		return false
	if distance < .75:
		return true
	return facing.dot(offset.normalized()) > cos(deg_to_rad(48))

func say(text: String, seconds: float = 4.5) -> void:
	speech.text = text
	reaction_left = seconds
	path.clear()

func snapshot() -> Dictionary:
	return {"ground":[ground.x,ground.y],"facing":[facing.x,facing.y],"route_index":route_index,"destination":destination,"wait":wait_left,"reaction":reaction_left,"speech":speech.text,"priorities":priorities.duplicate(),"hidden":hidden}

func restore(state: Dictionary, nav: OfficeNavigation) -> void:
	var xy = state.get("ground",[ground.x,ground.y])
	if xy is Array and xy.size() == 2:
		var p = Vector2(float(xy[0]),float(xy[1]))
		if nav.is_clear(p):
			ground = p
	var direction = state.get("facing",[0,-1])
	if direction is Array and direction.size() == 2:
		facing = Vector2(float(direction[0]),float(direction[1])).normalized()
	route_index = maxi(0,int(state.get("route_index",0)))
	destination = str(state.get("destination",""))
	wait_left = clampf(float(state.get("wait",0)),0,30)
	reaction_left = clampf(float(state.get("reaction",0)),0,10)
	speech.text = str(state.get("speech",""))
	priorities = state.get("priorities",[]).duplicate() if state.get("priorities",[]) is Array else []
	hidden = bool(state.get("hidden",false))
	path.clear()
	sync_position()
