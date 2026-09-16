class_name OfficeNavigation
extends RefCounted

const STEP = 0.4
const RADIUS = 0.28
var grid := AStarGrid2D.new()
var solids: Array[Rect2] = []
var occluders: Array[Rect2] = []
var walls: Array[Rect2] = []
var catalog: OfficeCatalog
var episode = 0

func build(data: OfficeCatalog, level: int) -> void:
	catalog = data
	episode = level
	solids.clear()
	occluders.clear()
	walls.clear()
	for rect in [Rect2(-.2,-.2,26.4,.4),Rect2(-.2,17.8,26.4,.4),Rect2(-.2,0,.4,18),Rect2(25.8,0,.4,18)]:
		add_wall(rect)
	for x in [12.0,18.0]:
		add_wall(Rect2(x-.1,0,.2,7))
	for x in [6.0,10.0,19.0]:
		add_wall(Rect2(x-.1,10,.2,8))
	for room in catalog.rooms:
		if room.side == "hall":
			continue
		var rr: Rect2 = room.rect
		var door: float = room.door
		var z = 7.0 if room.side == "top" else 10.0
		add_wall(Rect2(rr.position.x,z-.1,door-rr.position.x-1.2,.2))
		add_wall(Rect2(door+1.2,z-.1,rr.end.x-door-1.2,.2))
		if not catalog.is_open(room.id,episode):
			solids.append(rr)
	for id in catalog.objects:
		var obj = catalog.objects[id]
		if not catalog.available(id,episode):
			continue
		var rect = Rect2(obj.pos-obj.size/2.0,obj.size)
		solids.append(rect)
		if obj.kind in ["wardrobe","archive","fridge","coffee","stall"]:
			occluders.append(rect)
	grid.region = Rect2i(0,0,65,45)
	grid.cell_size = Vector2(STEP,STEP)
	grid.offset = Vector2(STEP/2,STEP/2)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for x in range(65):
		for y in range(45):
			var id = Vector2i(x,y)
			grid.set_point_solid(id,not is_clear(grid.get_point_position(id)))

func add_wall(rect: Rect2) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	walls.append(rect)
	solids.append(rect)
	occluders.append(rect)

func is_clear(point: Vector2) -> bool:
	if not Rect2(.3,.3,25.4,17.4).has_point(point):
		return false
	for rect in solids:
		if rect.grow(RADIUS).has_point(point):
			return false
	return true

func cell_for(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x/STEP),floori(point.y/STEP))

func free_cell(point: Vector2, search_radius: int = 5) -> Vector2i:
	var origin = cell_for(point)
	var best = Vector2i(-1,-1)
	var distance = INF
	for x in range(origin.x-search_radius,origin.x+search_radius+1):
		for y in range(origin.y-search_radius,origin.y+search_radius+1):
			var id = Vector2i(x,y)
			if not grid.is_in_boundsv(id) or grid.is_point_solid(id):
				continue
			var d = point.distance_squared_to(grid.get_point_position(id))
			if d < distance:
				distance = d
				best = id
	return best

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start = free_cell(from)
	var finish = free_cell(to)
	if start.x < 0 or finish.x < 0:
		return PackedVector2Array()
	var path = grid.get_point_path(start,finish)
	if path.is_empty():
		return path
	# Only append the exact destination if its segment is clear for the actor radius.
	if is_clear(to) and segment_clear(path[-1],to):
		path.append(to)
	return path

func segment_clear(a: Vector2, b: Vector2) -> bool:
	var steps = maxi(1,ceili(a.distance_to(b)/.12))
	for i in range(steps+1):
		if not is_clear(a.lerp(b,float(i)/steps)):
			return false
	return true

func line_of_sight(a: Vector2, b: Vector2) -> bool:
	var steps = maxi(1,ceili(a.distance_to(b)/.15))
	for i in range(1,steps):
		var p = a.lerp(b,float(i)/steps)
		for rect in occluders:
			if rect.has_point(p):
				return false
	return true

func slide(from: Vector2, movement: Vector2) -> Vector2:
	if segment_clear(from,from+movement):
		return from+movement
	var along_x = from+Vector2(movement.x,0)
	if segment_clear(from,along_x):
		from = along_x
	var along_y = from+Vector2(0,movement.y)
	if segment_clear(from,along_y):
		from = along_y
	return from
