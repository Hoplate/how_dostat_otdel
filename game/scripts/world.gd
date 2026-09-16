class_name OfficeWorld
extends Node3D

var catalog: OfficeCatalog
var nav: OfficeNavigation
var camera: Camera3D
var content: Node3D
var focus = Vector3(11,0,8.5)
var zoom_target = 23.5
var object_nodes: Dictionary = {}
var markers: Dictionary = {}
var tags: Dictionary = {}
var materials: Dictionary = {}
var path_mesh := ImmediateMesh.new()
var cone_mesh := ImmediateMesh.new()
var path_node: MeshInstance3D
var cone_node: MeshInstance3D
var current_episode = 0

func _init() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom_target
	camera.h_offset = 3.5
	camera.near = .1
	camera.far = 150
	add_child(camera)
	camera.current = true
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("141c22")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e1e2da")
	environment.environment.ambient_light_energy = .28
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(environment)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-25,0)
	sun.light_color = Color("ffe6bf")
	sun.light_energy = .78
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	sun.shadow_blur = 2.0
	add_child(sun)
	path_node = MeshInstance3D.new()
	path_node.mesh = path_mesh
	path_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(path_node)
	cone_node = MeshInstance3D.new()
	cone_node.mesh = cone_mesh
	cone_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cone_node)

func build(data: OfficeCatalog, navigation: OfficeNavigation, episode: int) -> void:
	catalog = data
	nav = navigation
	current_episode = episode
	if is_instance_valid(content):
		remove_child(content)
		content.free()
	content = Node3D.new()
	add_child(content)
	object_nodes.clear()
	markers.clear()
	tags.clear()
	box(content,Vector3(13,-.46,9),Vector3(26.8,.65,18.8),"3a4247")
	box(content,Vector3(13,-.16,9),Vector3(26.3,.18,18.3),"d1c5ae")
	for room in catalog.rooms:
		make_room(room,catalog.is_open(room.id,episode))
	for rect in nav.walls:
		var height = 2.8 if rect.position.y < .1 and rect.size.x > 10 else .58
		if rect.size.y > 5 and rect.position.x > 1 and rect.position.x < 25:
			height = 1.1
		box(content,Vector3(rect.get_center().x,height/2,rect.get_center().y),Vector3(rect.size.x,height,rect.size.y),"ccc7b7")
		if height < 2:
			box(content,Vector3(rect.get_center().x,height+.04,rect.get_center().y),Vector3(rect.size.x+.05,.08,rect.size.y+.05),"e7decb")
	# Windows, radiators and noticeboards provide a readable cutaway office, not a flat map.
	for x in [2.5,6.0,9.5,14.8,21.8,24.2]:
		box(content,Vector3(x,1.95,.19),Vector3(1.9,1.2,.10),"eeeadd")
		box(content,Vector3(x,1.95,.26),Vector3(1.7,1.0,.07),"a0bdca")
		box(content,Vector3(x,1.95,.30),Vector3(.04,1.05,.05),"efeadd")
		box(content,Vector3(x,.60,.23),Vector3(1.6,.65,.12),"d9d4c5")
	for id in catalog.objects:
		if catalog.available(id,episode):
			make_object(catalog.objects[id])
	set_camera_now()

func make_room(room: Dictionary, opened: bool) -> void:
	var rect: Rect2 = room.rect
	var color = Color(room.color) if opened else Color("535d60")
	var under = box(content,Vector3(rect.get_center().x,-.035,rect.get_center().y),Vector3(rect.size.x,.05,rect.size.y),"6e766a" if opened else "465352")
	var floor_mesh = ImmediateMesh.new()
	floor_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material("ffffff"))
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(room.id)
	var tile = .7 if room.id in ["wc","kitchen"] else 1.0
	var x = rect.position.x
	while x < rect.end.x-.01:
		var z = rect.position.y
		while z < rect.end.y-.01:
			var width = minf(tile,rect.end.x-x)
			var depth = minf(1.3 if room.id not in ["wc","kitchen"] else tile,rect.end.y-z)
			var c = color.lightened(rng.randf_range(-.035,.035))
			floor_mesh.surface_set_color(c)
			var points = [Vector3(x+.008,0,z+.008),Vector3(x+width-.008,0,z+.008),Vector3(x+width-.008,0,z+depth-.008),Vector3(x+.008,0,z+depth-.008)]
			for index in [0,2,1,0,3,2]:
				floor_mesh.surface_set_normal(Vector3.UP)
				floor_mesh.surface_add_vertex(points[index])
			z += depth
		x += tile
	floor_mesh.surface_end()
	var node = MeshInstance3D.new()
	node.mesh = floor_mesh
	var floor_mat = material("ffffff").duplicate()
	floor_mat.vertex_color_use_as_albedo = true
	node.material_override = floor_mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content.add_child(node)
	var label = label3d(room.title if opened else "ЗАКРЫТО",34,Color("dbe2dc") if opened else Color("899396"))
	label.position = Vector3(rect.get_center().x,.08,rect.end.y-.48)
	label.rotation_degrees.x = -90
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	content.add_child(label)
	if not opened:
		var notice = label3d("ЭПИЗОД %02d" % (int(room.unlock)+1),38,Color("929b9b"))
		notice.position = Vector3(rect.get_center().x,.8,rect.get_center().y)
		content.add_child(notice)

func material(hex: String, unshaded: bool = false) -> StandardMaterial3D:
	var key = hex+str(unshaded)
	if materials.has(key):
		return materials[key]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = .83
	if mat.albedo_color.a < 1:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[key] = mat
	return mat

func box(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.material_override = material(color)
	parent.add_child(n)
	return n

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: String) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	n.mesh = mesh
	n.position = pos
	n.material_override = material(color)
	parent.add_child(n)
	return n

func label3d(text: String, size: int = 40, color: Color = Color.WHITE) -> Label3D:
	var n = Label3D.new()
	n.text = text
	n.font_size = size
	n.pixel_size = .007
	n.modulate = color
	n.outline_size = 5
	n.outline_modulate = Color("34403d")
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return n

func table(n: Node3D, size: Vector2, color: String = "bda47b") -> void:
	box(n,Vector3(0,.86,0),Vector3(size.x,.14,size.y),color)
	for x in [-size.x/2+.12,size.x/2-.12]:
		for z in [-size.y/2+.12,size.y/2-.12]:
			box(n,Vector3(x,.4,z),Vector3(.08,.8,.08),"394445")

func monitor(n: Node3D, at: Vector3, big: bool = false) -> void:
	var width = 1.15 if big else .85
	box(n,at+Vector3(0,.08,0),Vector3(.35,.04,.22),"303b3d")
	box(n,at+Vector3(0,.25,-.06),Vector3(.06,.34,.07),"303b3d")
	box(n,at+Vector3(0,.49,-.08),Vector3(width,.58,.09),"283439")
	box(n,at+Vector3(0,.5,-.024),Vector3(width-.09,.47,.025),"6f9f9d")
	for i in range(3):
		box(n,at+Vector3(-width/3,.39+i*.10,-.007),Vector3(width*.45,.028,.012),"b9d5c6")
	box(n,at+Vector3(-.08,.08,.29),Vector3(.58,.035,.18),"465251")
	box(n,at+Vector3(.43,.08,.27),Vector3(.13,.05,.19),"364344")

func make_object(obj: Dictionary) -> void:
	var n = Node3D.new()
	n.position = Vector3(obj.pos.x,0,obj.pos.y)
	content.add_child(n)
	object_nodes[obj.id] = n
	var height = 1.0
	match obj.kind:
		"desk","bossdesk":
			table(n,obj.size,"a88d67" if obj.kind == "bossdesk" else "c9ad83")
			monitor(n,Vector3(0,.91,-.06),obj.id == "screen")
			box(n,Vector3(-obj.size.x/2+.4,.4,-.05),Vector3(.55,.7,.8),"9b9d90")
			for y in [.3,.55]:
				box(n,Vector3(-obj.size.x/2+.4,y,.37),Vector3(.22,.035,.035),"5f6963")
			cylinder(n,Vector3(.85,1.08,.22),.10,.26,"b86750")
			box(n,Vector3(-.75,.96,.22),Vector3(.35,.02,.28),"e8e4d6")
			height = 1.65
		"supplies","paper","calendar","folders","remote":
			table(n,obj.size)
			if obj.kind == "supplies":
				for i in range(3):
					box(n,Vector3(-.35,.97+i*.04,0),Vector3(.42,.04,.30),"edcc75")
				cylinder(n,Vector3(.30,1.05,0),.11,.26,"4a6e74")
				for i in range(3):
					box(n,Vector3(.25+i*.045,1.25,0),Vector3(.02,.4,.025),"cb7158")
			elif obj.kind == "folders":
				for i in range(6):
					box(n,Vector3(-.52+i*.20,1.24,0),Vector3(.15,.59,.38),["636e78","a87865","d2bd90"][i%3])
					box(n,Vector3(-.52+i*.20,1.23,.20),Vector3(.09,.16,.01),"e6deca")
			elif obj.kind == "paper":
				for i in range(4):
					box(n,Vector3(0,.99+i*.055,0),Vector3(.85,.045,.65),"e6e0d1")
			elif obj.kind == "calendar":
				var page = box(n,Vector3(0,1.18,0),Vector3(.63,.45,.055),"f0dfac")
				page.rotation_degrees.x = -18
				var text = label3d("ПТ",36,Color("594d3f"))
				text.position = Vector3(0,1.22,.10)
				n.add_child(text)
			else:
				box(n,Vector3(0,.98,0),Vector3(.21,.07,.43),"354047")
				for i in range(3):
					cylinder(n,Vector3(0,1.025,-.1+i*.08),.028,.012,"d3ad66")
			height = 1.5
		"wardrobe","archive":
			box(n,Vector3(0,1.1,0),Vector3(obj.size.x,2.2,obj.size.y),"6a7975")
			for x in [-obj.size.x*.25,obj.size.x*.25]:
				box(n,Vector3(x,1.15,obj.size.y/2+.02),Vector3(obj.size.x*.47,2.05,.06),"788984")
				box(n,Vector3(x*.35,1.12,obj.size.y/2+.09),Vector3(.04,.35,.05),"d4cbb6")
			height = 2.25
		"coffee":
			box(n,Vector3(0,.48,0),Vector3(1.2,.96,1.2),"9f947c")
			box(n,Vector3(0,1.6,0),Vector3(1.08,1.3,.94),"303939")
			box(n,Vector3(0,1.76,.49),Vector3(.65,.30,.05),"91bbac")
			box(n,Vector3(0,1.22,.50),Vector3(.80,.34,.05),"161e20")
			for x in [-.18,.18]:
				cylinder(n,Vector3(x,1.09,.60),.09,.15,"ede1c7")
				box(n,Vector3(x,1.40,.56),Vector3(.06,.12,.11),"b2b6ab")
			height = 2.3
		"fridge":
			box(n,Vector3(0,1.42,0),Vector3(1.28,2.84,1.15),"c6c6b5")
			box(n,Vector3(0,1.76,.59),Vector3(1.20,.04,.04),"7f8a81")
			box(n,Vector3(.44,2.17,.63),Vector3(.055,.54,.07),"596a65")
			box(n,Vector3(.44,1.3,.63),Vector3(.055,.54,.07),"596a65")
			for i in range(3):
				var note = box(n,Vector3(-.25+i*.22,2.33-i*.31,.62),Vector3(.25,.24,.018),["efd78d","adbacb","d8a290"][i])
				note.rotation_degrees.z = (i-1)*10
			height = 2.9
		"sofa":
			box(n,Vector3(0,.47,0),Vector3(2.65,.56,1.22),"728a87")
			box(n,Vector3(0,.99,-.48),Vector3(2.65,1.1,.32),"637e7a")
			for x in [-1.18,1.18]:
				box(n,Vector3(x,.76,0),Vector3(.29,.8,1.28),"5c7471")
			for x in [-.52,.52]:
				box(n,Vector3(x,.79,.1),Vector3(.99,.20,.80),"829991")
			height = 1.5
		"printer":
			box(n,Vector3(0,.5,0),Vector3(1.7,1.0,1.3),"84938c")
			box(n,Vector3(0,1.32,0),Vector3(1.62,.66,1.22),"d6d7ca")
			box(n,Vector3(0,1.71,-.13),Vector3(1.32,.13,.84),"b6c1b7")
			box(n,Vector3(0,1.34,.63),Vector3(1.15,.13,.04),"334640")
			box(n,Vector3(.45,1.6,.45),Vector3(.28,.04,.21),"759daa")
			box(n,Vector3(0,1.19,.8),Vector3(.69,.025,.40),"f2e9d6")
			height = 1.8
		"cooler":
			box(n,Vector3(0,.72,0),Vector3(.68,1.44,.63),"d0d9ce")
			cylinder(n,Vector3(0,1.75,0),.27,.60,"7aacae")
			box(n,Vector3(0,1.03,.34),Vector3(.49,.42,.04),"466663")
			for x in [-.12,.12]:
				cylinder(n,Vector3(x,.94,.40),.04,.10,"a97961" if x < 0 else "7d9ebd")
			height = 2.1
		"plant":
			cylinder(n,Vector3(0,.35,0),.37,.7,"846853")
			cylinder(n,Vector3(0,1.1,0),.04,1.25,"657057")
			for i in range(9):
				var leaf = MeshInstance3D.new()
				var sphere = SphereMesh.new()
				sphere.radius = .20
				sphere.height = 1.0
				leaf.mesh = sphere
				leaf.material_override = material("5e815e" if i%2 else "7b965e")
				leaf.position = Vector3(sin(i*2.4)*.36,1.05+i*.09,cos(i*2.4)*.3)
				leaf.rotation = Vector3(.5,sin(i)*2,.65)
				leaf.scale.z = .42
				n.add_child(leaf)
			height = 2.3
		"microwave","towels":
			box(n,Vector3(0,.48,0),Vector3(obj.size.x,.96,obj.size.y),"999b85")
			box(n,Vector3(0,.99,0),Vector3(obj.size.x+.06,.10,obj.size.y+.06),"dad8c4")
			if obj.kind == "microwave":
				box(n,Vector3(0,1.34,0),Vector3(1.2,.60,.8),"b9c2b9")
				box(n,Vector3(-.13,1.34,.42),Vector3(.76,.42,.03),"324542")
				var knob = cylinder(n,Vector3(.43,1.36,.43),.07,.045,"bdae8e")
				knob.rotation_degrees.x = 90
			else:
				for i in range(3):
					cylinder(n,Vector3(-.4+i*.4,1.18,.03),.12,.27,["d6bd8a","9eb4b2","d09e88"][i])
			height = 1.65
		"whiteboard","board":
			for x in [-obj.size.x*.36,obj.size.x*.36]:
				box(n,Vector3(x,.8,0),Vector3(.07,1.6,.10),"485d56")
			box(n,Vector3(0,1.6,0),Vector3(obj.size.x,1.15,.12),"a89f88")
			box(n,Vector3(0,1.6,.08),Vector3(obj.size.x-.12,1.02,.025),"e3dfca")
			var note = label3d("ПЛАН НА ДЕНЬ\n1. КОФЕ   2. РЕЗУЛЬТАТ" if obj.kind == "whiteboard" else "ПЕРЕРЫВ\nНА ПЕРЕРЫВ",22,Color("4c6157"))
			note.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			note.pixel_size = .0045
			note.outline_size = 0
			note.position = Vector3(0,1.65,.11)
			n.add_child(note)
			height = 2.22
		"projector":
			table(n,obj.size,"a09178")
			box(n,Vector3(0,1.13,0),Vector3(.8,.35,.55),"c8c9bb")
			var lens = cylinder(n,Vector3(.18,1.12,.29),.1,.04,"90b8bc")
			lens.rotation_degrees.x = 90
			for x in [-.8,.8]:
				box(n,Vector3(x,.98,0),Vector3(.33,.035,.50),"e3d9c0")
			height = 1.5
		"chair":
			cylinder(n,Vector3(0,.35,0),.06,.7,"536057")
			box(n,Vector3(0,.72,0),Vector3(.88,.16,.85),"6a8381")
			box(n,Vector3(0,1.18,-.35),Vector3(.88,.80,.13),"5f7877")
			for i in range(5):
				var leg = box(n,Vector3(sin(i*TAU/5)*.19,.11,cos(i*TAU/5)*.19),Vector3(.06,.08,.48),"515c54")
				leg.rotation.y = i*TAU/5
			height = 1.65
		"gift":
			box(n,Vector3(0,.42,0),Vector3(.87,.84,.85),"bc8173")
			box(n,Vector3(0,.86,0),Vector3(.94,.1,.92),"d6a18b")
			box(n,Vector3(0,.88,0),Vector3(.16,.10,.94),"e6c983")
			box(n,Vector3(0,.42,.44),Vector3(.16,.86,.03),"e6c983")
			height = 1.1
		"speaker":
			box(n,Vector3(0,.63,0),Vector3(.78,1.26,.78),"38433f")
			for y in [.38,.91]:
				var disc = cylinder(n,Vector3(0,y,.4),.23,.05,"657371")
				disc.rotation_degrees.x = 90
			height = 1.35
		"sign":
			var sign = box(n,Vector3(0,.56,0),Vector3(.5,1.05,.08),"d7b763")
			sign.rotation_degrees.x = -16
			height = 1.1
		"stall":
			box(n,Vector3(0,1.0,.6),Vector3(2.0,2.0,.12),"abc0b4")
			for x in [-.94,.94]:
				box(n,Vector3(x,1.0,0),Vector3(.12,2.0,1.5),"bbc9ba")
			box(n,Vector3(0,.53,.12),Vector3(.60,.6,.90),"eee9d8")
			box(n,Vector3(0,.98,.58),Vector3(.6,.54,.20),"eee9d8")
			height = 2.1
	obj["height"] = height
	# Picking is independent of navigation and uses the same object specification.
	var area = Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.set_meta("object_id",obj.id)
	var shape = CollisionShape3D.new()
	var bounds = BoxShape3D.new()
	bounds.size = Vector3(obj.size.x+.18,height+.20,obj.size.y+.18)
	shape.shape = bounds
	shape.position.y = height/2
	area.add_child(shape)
	n.add_child(area)
	var marker = MeshInstance3D.new()
	marker.mesh = ring_mesh(.48,.045)
	marker.material_override = material("eeb858",true)
	marker.position = Vector3(obj.use.x,.045,obj.use.y)
	marker.visible = false
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content.add_child(marker)
	markers[obj.id] = marker
	var tag = label3d("",44,Color("efb75e"))
	tag.position = Vector3(0,height+.3,0)
	tag.visible = false
	n.add_child(tag)
	tags[obj.id] = tag

func ring_mesh(radius: float, width: float) -> ImmediateMesh:
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(40):
		var a = i*TAU/40
		var b = (i+1)*TAU/40
		var p = [Vector3(cos(a)*radius,0,sin(a)*radius),Vector3(cos(b)*radius,0,sin(b)*radius),Vector3(cos(b)*(radius-width),0,sin(b)*(radius-width)),Vector3(cos(a)*(radius-width),0,sin(a)*(radius-width))]
		for index in [0,1,2,0,2,3]:
			mesh.surface_add_vertex(p[index])
	mesh.surface_end()
	return mesh

func pick(screen: Vector2) -> String:
	var start = camera.project_ray_origin(screen)
	var direction = camera.project_ray_normal(screen)
	var query = PhysicsRayQueryParameters3D.create(start,start+direction*150,2)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return ""
	return str(hit.collider.get_meta("object_id",""))

func floor_point(screen: Vector2):
	var hit = Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
	if hit == null:
		return null
	return Vector2(hit.x,hit.z)

func update_camera(delta: float) -> void:
	camera.size = lerpf(camera.size,zoom_target,1-exp(-delta*12))
	set_camera_now(false)

func set_camera_now(reset_zoom: bool = true) -> void:
	if reset_zoom:
		camera.size = zoom_target
	camera.position = focus+Vector3(8,27,26)
	camera.look_at(focus,Vector3.UP)

func recenter(point: Vector2) -> void:
	focus = Vector3(point.x,0,point.y)

func pan(motion: Vector2) -> void:
	focus.x = clampf(focus.x-motion.x*camera.size/900.0,-2,28)
	focus.z = clampf(focus.z-motion.y*camera.size/640.0,-2,20)

func focus_object(id: String) -> void:
	if catalog.objects.has(id):
		var point: Vector2 = catalog.objects[id].pos
		focus = Vector3(point.x,0,point.y)

func update_markers(states: Dictionary, tasks: Array, hover: String, pending: String, inspect: bool) -> void:
	for id in markers:
		var obj = catalog.objects[id]
		var state = states.get(id,"idle")
		var active = id in tasks or not obj.items.is_empty() or obj.hide
		markers[id].visible = active and (inspect or id == hover or id == pending or state == "armed")
		var color = "7aba9c" if state == "done" else ("eeb858" if id in tasks else ("8fbdd0" if not obj.items.is_empty() else "a6aaa0"))
		markers[id].material_override = material(color,true)
		var tag: Label3D = tags[id]
		tag.visible = id in tasks and (state != "idle" or inspect or id == hover)
		tag.text = "✓" if state == "done" else ("!" if state == "armed" else "•")
		tag.modulate = Color(color)

func draw_intentions(player: OfficeActor, npcs: Array, inspect: bool) -> void:
	path_mesh.clear_surfaces()
	cone_mesh.clear_surfaces()
	if not player.path.is_empty():
		path_mesh.surface_begin(Mesh.PRIMITIVE_LINES,material("eeb858",true))
		var previous = player.ground
		for point in player.path:
			path_mesh.surface_add_vertex(Vector3(previous.x,.055,previous.y))
			path_mesh.surface_add_vertex(Vector3(point.x,.055,point.y))
			previous = point
		path_mesh.surface_end()
	if not inspect:
		return
	cone_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material("d67a6130",true))
	for npc in npcs:
		var angle = npc.facing.angle()
		var radius = 6.0 if npc.actor_id == "pasha" else 5.0
		var points: Array[Vector2] = []
		for i in range(17):
			var direction = Vector2.from_angle(angle+deg_to_rad(-48+96*i/16.0))
			var length = .4
			while length < radius and nav.line_of_sight(npc.ground,npc.ground+direction*length):
				length += .25
			points.append(npc.ground+direction*minf(length,radius))
		for i in range(16):
			for p in [npc.ground,points[i],points[i+1]]:
				cone_mesh.surface_add_vertex(Vector3(p.x,.032,p.y))
	cone_mesh.surface_end()
