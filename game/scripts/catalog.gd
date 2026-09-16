class_name OfficeCatalog
extends RefCounted

const ITEMS = {"marker": "Маркер", "stickers": "Стикеры", "paper": "Шуточный лист", "remote": "Пульт"}
const NAMES = {"dima": "Дима", "lena": "Лена", "marina": "Марина", "pasha": "Паша", "boss": "Руководитель"}
const COLORS = {"dima": "efb75e", "lena": "91aec5", "marina": "cb927a", "pasha": "b3bc78"}
const HEIGHTS = {"dima": 2.15, "lena": 2.4, "marina": 2.0, "pasha": 2.65}
const ROUTES = {
	"lena": ["mouse", "cooler", "calendar", "folders", "fridge", "sign", "chair", "gift", "whiteboard"],
	"marina": ["mug", "cooler", "coffee", "fridge", "sofa", "microwave", "towels", "speaker"],
	"pasha": ["screen", "printer", "cooler", "whiteboard", "projector"]
}
const DIFFICULTY = {
	"easy": {"name": "Спокойный", "detection": 0.65, "time": 1.3, "speed": 0.9},
	"normal": {"name": "Обычный", "detection": 1.0, "time": 1.0, "speed": 1.0},
	"hard": {"name": "На нервах", "detection": 1.35, "time": 0.86, "speed": 1.12}
}
var episodes: Array = []
var pranks: Dictionary = {}
var cascade: Dictionary = {}
var objects: Dictionary = {}
var rooms: Array = []

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	assert(parsed is Dictionary, "Campaign JSON is missing or invalid")
	episodes = parsed.episodes
	pranks = parsed.pranks
	cascade = parsed.cascade
	rooms = [
		{"id":"office", "title":"ОТДЕЛ", "rect":Rect2(0,0,12,7), "door":6.0, "side":"top", "unlock":0, "color":"b4afa0"},
		{"id":"lounge", "title":"КОФЕ / ОТДЫХ", "rect":Rect2(12,0,6,7), "door":15.0, "side":"top", "unlock":1, "color":"b49974"},
		{"id":"print", "title":"ПРИНТ-ЗОНА", "rect":Rect2(18,0,8,7), "door":22.0, "side":"top", "unlock":2, "color":"a4aca6"},
		{"id":"hall", "title":"ЭТАЖ 03", "rect":Rect2(0,7,26,3), "door":0.0, "side":"hall", "unlock":0, "color":"808b89"},
		{"id":"kitchen", "title":"КУХНЯ", "rect":Rect2(0,10,6,8), "door":3.0, "side":"bottom", "unlock":3, "color":"b9ac8e"},
		{"id":"wc", "title":"ТИХАЯ ЗОНА", "rect":Rect2(6,10,4,8), "door":8.0, "side":"bottom", "unlock":4, "color":"afbbb3"},
		{"id":"meeting", "title":"ПЕРЕГОВОРНАЯ", "rect":Rect2(10,10,9,8), "door":14.5, "side":"bottom", "unlock":5, "color":"a99478"},
		{"id":"boss", "title":"РУКОВОДИТЕЛЬ", "rect":Rect2(19,10,7,8), "door":22.5, "side":"bottom", "unlock":7, "color":"968b7b"}
	]
	add_object("mouse","Стол Лены","office",Vector2(2.2,1.9),Vector2(2.2,3.1),Vector2(2.5,1.2),"desk")
	add_object("mug","Кружка Марины","office",Vector2(5.5,1.9),Vector2(5.5,3.1),Vector2(2.5,1.2),"desk")
	add_object("screen","Компьютер Паши","office",Vector2(9.0,1.9),Vector2(9,3.1),Vector2(2.7,1.2),"desk")
	add_object("stationery","Канцтовары Димы","office",Vector2(1.4,5.3),Vector2(2.8,5.3),Vector2(1.6,1.1),"supplies",["marker","stickers"])
	add_object("calendar","Настольный календарь","office",Vector2(4.4,5.2),Vector2(4.4,4.2),Vector2(1.2,0.8),"calendar")
	add_object("folders","Папки Лены","office",Vector2(7.8,5.4),Vector2(7.8,4.3),Vector2(1.6,0.9),"folders")
	add_object("coat","Шкаф с пальто","office",Vector2(10.8,5.1),Vector2(9.7,5.1),Vector2(1.0,1.3),"wardrobe",[],true)
	add_object("coffee","Кофеавтомат","lounge",Vector2(13.7,1.8),Vector2(13.7,3.2),Vector2(1.2,1.2),"coffee")
	add_object("fridge","Холодильник","lounge",Vector2(16.4,1.6),Vector2(16.4,3.1),Vector2(1.3,1.2),"fridge")
	add_object("sofa","За диваном","lounge",Vector2(15.4,5.3),Vector2(13.4,5.3),Vector2(2.7,1.3),"sofa",[],true)
	add_object("printer","Принтер","print",Vector2(20.3,1.8),Vector2(20.3,3.2),Vector2(1.8,1.4),"printer")
	add_object("paperSupply","Шуточные листы","print",Vector2(24.2,1.8),Vector2(24.2,3.2),Vector2(1.5,1.2),"paper",["paper"])
	add_object("archive","Архивный шкаф","print",Vector2(24,5.4),Vector2(22.2,5.4),Vector2(2.5,1.0),"archive",[],true)
	add_object("cooler","Кулер","hall",Vector2(1.0,8.45),Vector2(2.0,8.45),Vector2(0.7,0.7),"cooler")
	add_object("board","Доска объявлений","hall",Vector2(11.3,8.0),Vector2(11.3,9.0),Vector2(1.5,0.25),"board")
	add_object("plant","За фикусом","hall",Vector2(24.9,8.5),Vector2(23.8,8.5),Vector2(0.8,0.8),"plant",[],true)
	add_object("microwave","Кухонный таймер","kitchen",Vector2(1.3,12.1),Vector2(2.7,12.1),Vector2(1.6,1.4),"microwave")
	add_object("towels","Сушилка с кружками","kitchen",Vector2(1.3,15.3),Vector2(2.7,15.3),Vector2(1.6,1.3),"towels")
	add_object("pantry","Кухонный шкаф","kitchen",Vector2(4.7,16.2),Vector2(3.5,16.2),Vector2(1.1,1.3),"wardrobe",[],true)
	add_object("sign","Табличка уборки","wc",Vector2(7.0,12.0),Vector2(8.0,12.0),Vector2(0.45,0.6),"sign")
	add_object("stall","Свободная кабинка","wc",Vector2(8.0,16.0),Vector2(8.0,14.5),Vector2(2.0,1.7),"stall",[],true)
	add_object("whiteboard","Маркерная доска","meeting",Vector2(11.4,12.0),Vector2(12.3,12.9),Vector2(1.8,0.5),"whiteboard")
	add_object("projector","Проектор","meeting",Vector2(15.5,13.2),Vector2(15.5,14.8),Vector2(2.6,1.7),"projector")
	add_object("remoteSupply","Пульт на тумбе","meeting",Vector2(17.8,11.6),Vector2(17.8,12.7),Vector2(1.0,0.8),"remote",["remote"])
	add_object("chair","Стул эксперта","meeting",Vector2(11.5,15.9),Vector2(12.6,15.9),Vector2(1.0,1.0),"chair")
	add_object("gift","Подарочная коробка","meeting",Vector2(14.3,16.6),Vector2(14.3,15.5),Vector2(0.9,0.9),"gift")
	add_object("speaker","Музыкальная колонка","meeting",Vector2(17.7,16.5),Vector2(16.6,16.5),Vector2(0.8,0.9),"speaker")
	add_object("bossReport","Отчёт руководителю","boss",Vector2(22.5,12.8),Vector2(22.5,14.4),Vector2(3.1,1.6),"bossdesk")
	add_object("bossCabinet","За шкафом руководителя","boss",Vector2(24.5,16.3),Vector2(22.8,16.3),Vector2(2.0,0.9),"archive",[],true)

func add_object(id: String, title: String, room: String, pos: Vector2, use_at: Vector2, size: Vector2, kind: String, items: Array = [], hiding: bool = false) -> void:
	objects[id] = {"id":id,"title":title,"room":room,"pos":pos,"use":use_at,"size":size,"kind":kind,"items":items,"hide":hiding}

func is_open(room_id: String, episode: int) -> bool:
	for room in rooms:
		if room.id == room_id:
			return episode >= int(room.unlock)
	return false

func room_at(point: Vector2) -> String:
	for room in rooms:
		if room.rect.has_point(point):
			return room.id
	return ""

func available(id: String, episode: int) -> bool:
	return objects.has(id) and is_open(objects[id].room, episode)
