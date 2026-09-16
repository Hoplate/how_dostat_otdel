class_name OfficeUI
extends CanvasLayer

signal command(action: String, value: Variant)

const INK = Color("243139")
const CREAM = Color("efe8d8")
const MUTED = Color("9daaa9")
const ACCENT = Color("edb65e")
var root: Control
var hud: Control
var overlay: Control
var menu: Control
var episode_label: Label
var clock_label: Label
var heat: ProgressBar
var suspicion: ProgressBar
var heat_label: Label
var suspicion_label: Label
var combo_label: Label
var task_box: VBoxContainer
var task_buttons: Dictionary = {}
var people_labels: Dictionary = {}
var inventory_labels: Dictionary = {}
var detail_panel: PanelContainer
var detail_title: Label
var detail_subtitle: Label
var action_bar: ProgressBar
var event_panel: PanelContainer
var event_text: Label
var event_time = 0.0
var event_messages: Array[String] = []
var stealth_button: Button
var innocent_button: Button
var inspect_button: Button
var binding_action = ""
var binding_button: Button
var modal_kind = ""

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	build_hud()

func style(color: Color, border: Color = Color("3e4a4d"), radius: int = 9) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func panel(parent: Node, rect: Rect2, color: Color = Color("243139")) -> PanelContainer:
	var p = PanelContainer.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel",style(color))
	parent.add_child(p)
	return p

func label(parent: Node, text: String, size: int = 18, color: Color = CREAM) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

func fixed_label(parent: Node, rect: Rect2, text: String, size: int = 18, color: Color = CREAM) -> Label:
	var l = label(parent,text,size,color)
	l.position = rect.position
	l.size = rect.size
	return l

func button(parent: Node, text: String, action: String, value: Variant = null, primary: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 45
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_stylebox_override("normal",style(ACCENT if primary else Color("303e44")))
	b.add_theme_stylebox_override("hover",style(Color("f2c580") if primary else Color("45545a"),ACCENT))
	b.add_theme_stylebox_override("pressed",style(Color("d09b4e") if primary else Color("23313a")))
	b.add_theme_stylebox_override("disabled",style(Color("222d33")))
	b.add_theme_color_override("font_color",INK if primary else CREAM)
	b.add_theme_color_override("font_hover_color",INK if primary else CREAM)
	b.add_theme_color_override("font_pressed_color",INK if primary else CREAM)
	b.add_theme_color_override("font_disabled_color",Color("697578"))
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(func(): command.emit(action,value))
	parent.add_child(b)
	return b

func fixed_button(parent: Node, rect: Rect2, text: String, action: String, value: Variant = null, primary: bool = false) -> Button:
	var b = button(parent,text,action,value,primary)
	b.position = rect.position
	b.size = rect.size
	return b

func vbox(parent: Node, separation: int = 10) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation",separation)
	parent.add_child(v)
	return v

func portrait(parent: Node, id: String, size: Vector2, full_body: bool = false) -> TextureRect:
	var rect = TextureRect.new()
	var texture = load("res://assets/characters/%s.webp" % id)
	if not full_body:
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(0,0,texture.get_width(),texture.get_height()*.42)
		rect.texture = atlas
	else:
		rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = size
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func make_meter(parent: Node, color: Color) -> ProgressBar:
	var b = ProgressBar.new()
	b.custom_minimum_size.y = 8
	b.show_percentage = false
	var background = style(Color("3a494e"),Color("3a494e"),4)
	var fill = style(color,color,4)
	background.content_margin_top = 0
	background.content_margin_bottom = 0
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	b.add_theme_stylebox_override("background",background)
	b.add_theme_stylebox_override("fill",fill)
	parent.add_child(b)
	return b

func build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var top = panel(hud,Rect2(20,18,1560,66))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",30)
	top.add_child(row)
	var brand = label(row,"КАК ДОСТАТЬ ОТДЕЛ",23,ACCENT)
	brand.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	brand.custom_minimum_size.x = 315
	episode_label = label(row,"",21)
	clock_label = label(row,"",20,MUTED)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_label.custom_minimum_size.x = 290
	clock_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	var meters = vbox(panel(hud,Rect2(20,100,252,150)),7)
	heat_label = label(meters,"НАКАЛ ОТДЕЛА",15,ACCENT)
	heat = make_meter(meters,ACCENT)
	suspicion_label = label(meters,"ПАЛЕВО",15,Color("e38d78"))
	suspicion = make_meter(meters,Color("d6816c"))
	combo_label = label(meters,"",15,MUTED)
	var sidebar = vbox(panel(hud,Rect2(1268,100,312,680)),10)
	label(sidebar,"ПЛАН НА СМЕНУ",17,ACCENT)
	label(sidebar,"Нажмите на задачу — покажу цель",13,MUTED)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)
	task_box = vbox(scroll,8)
	task_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(sidebar,"КОЛЛЕГИ",15,MUTED)
	for id in ["lena","marina","pasha"]:
		var person = HBoxContainer.new()
		person.add_theme_constant_override("separation",10)
		sidebar.add_child(person)
		portrait(person,id,Vector2(50,48))
		var texts = vbox(person,0)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(texts,OfficeCatalog.NAMES[id],17,Color(OfficeCatalog.COLORS[id]))
		people_labels[id] = label(texts,"Занят своими делами",13,MUTED)
	var bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation",10)
	panel(hud,Rect2(20,800,1560,80)).add_child(bottom)
	portrait(bottom,"dima",Vector2(58,55))
	for id in OfficeCatalog.ITEMS:
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(117,54)
		slot.add_theme_stylebox_override("panel",style(Color("1d282f")))
		bottom.add_child(slot)
		inventory_labels[id] = label(slot,"—",14,MUTED)
		inventory_labels[id].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	stealth_button = button(bottom,"Тише", "sneak")
	stealth_button.custom_minimum_size.x = 135
	innocent_button = button(bottom,"Невинное лицо", "innocent")
	innocent_button.custom_minimum_size.x = 225
	inspect_button = button(bottom,"Осмотреть", "inspect")
	inspect_button.custom_minimum_size.x = 190
	var pause = button(bottom,"Пауза", "pause")
	pause.custom_minimum_size.x = 125
	fixed_label(hud,Rect2(295,765,950,26),"ЛКМ — подойти и сделать   ·   ПКМ — отмена   ·   Колесо — масштаб   ·   Средняя кнопка — камера",14,Color("c5c5b5"))
	detail_panel = panel(hud,Rect2(320,663,920,93),Color("253239f2"))
	var details = vbox(detail_panel,3)
	detail_title = label(details,"",20,ACCENT)
	detail_subtitle = label(details,"",16)
	detail_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_bar = make_meter(details,ACCENT)
	action_bar.visible = false
	detail_panel.visible = false
	event_panel = panel(hud,Rect2(20,588,282,172),Color("efe8d8f5"))
	event_text = label(event_panel,"",16,INK)
	event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_panel.visible = false

func set_episode(g) -> void:
	for child in task_box.get_children():
		task_box.remove_child(child)
		child.queue_free()
	task_buttons.clear()
	for id in g.level.tasks:
		var b = button(task_box,"", "focus",id)
		b.custom_minimum_size.y = 72
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size",15)
		b.tooltip_text = g.catalog.pranks[id].description
		task_buttons[id] = b
	event_messages.clear()
	event_time = 0
	close_overlay()
	if is_instance_valid(menu):
		menu.queue_free()
		menu = null
	hud.visible = true
	refresh(g)

func refresh(g) -> void:
	if not is_instance_valid(hud) or g.level.is_empty():
		return
	episode_label.text = "%02d / 10   ·   %s" % [g.episode+1,g.level.title]
	clock_label.text = "%s   ·   %s" % [g.level.day,time_text(g.time_left())]
	heat.value = g.completed_count()*100.0/g.level.tasks.size()
	suspicion.value = g.suspicion
	heat_label.text = "НАКАЛ ОТДЕЛА   %d / %d" % [g.completed_count(),g.level.tasks.size()]
	suspicion_label.text = "ПАЛЕВО   %d%%" % int(g.suspicion)
	combo_label.text = "КОМБО ×%d   ·   %d ОЧКОВ\nЗАМЕЧАНИЯ %d / 3" % [g.combo,g.score,g.strikes]
	if g.level.get("boss",false):
		combo_label.text += "\nПроверка через %d с" % ceili(g.next_inspection-g.elapsed)
	for id in task_buttons:
		var state = g.states.get(id,"idle")
		var prank = g.catalog.pranks[id]
		var sub = "Готово" if state == "done" else ("Подготовлено · ждём реакцию" if state == "armed" else ("Без предметов" if prank.need == "" else "Нужен: "+OfficeCatalog.ITEMS[prank.need]))
		var prefix = "✓  " if state == "done" else ("◷  " if state == "armed" else "○  ")
		task_buttons[id].text = prefix+prank.title+"\n"+sub
		task_buttons[id].add_theme_color_override("font_color",Color("94c3a8") if state == "done" else (ACCENT if state == "armed" else CREAM))
	for npc in g.npcs:
		var status = "Ищет виновника" if npc.search_left > 0 else ("Реагирует на пакость" if npc.reaction_left > 0 else "Идёт: "+g.catalog.objects[npc.destination].title if g.catalog.objects.has(npc.destination) and not npc.path.is_empty() else "Занят своими делами")
		people_labels[npc.actor_id].text = status
		people_labels[npc.actor_id].clip_text = true
		people_labels[npc.actor_id].tooltip_text = status
	for id in inventory_labels:
		inventory_labels[id].text = ("✓ " if id in g.inventory else "")+OfficeCatalog.ITEMS[id]
		inventory_labels[id].modulate = Color.WHITE if id in g.inventory else Color(.48,.51,.51)
	stealth_button.text = ("Тише: вкл" if g.sneaking else "Тише")+" ["+Profile.key_label("sneak")+"]"
	innocent_button.text = "Невинное лицо"+(" · %d c" % ceili(g.innocent_left) if g.innocent_left > 0 else " ["+Profile.key_label("innocent")+"]")
	innocent_button.disabled = g.innocent_left > 0 or not g.action_id.is_empty()
	inspect_button.text = ("Скрыть подсказки" if g.inspect_mode else "Осмотреть")+" ["+Profile.key_label("inspect")+"]"
	var id: String = g.action_id if g.action_id != "" else (g.hover_id if g.hover_id != "" else g.pending_id)
	detail_panel.visible = id != "" or g.player.hidden
	if g.player.hidden:
		detail_title.text = "Дима в укрытии"
		detail_subtitle.text = "Нажмите E или щёлкните по полу, чтобы выйти."
		action_bar.visible = false
	elif id != "" and g.catalog.objects.has(id):
		detail_title.text = g.catalog.objects[id].title+"   /   "+g.verb(id)
		detail_subtitle.text = g.object_hint(id)
		action_bar.visible = g.action_id != ""
		if action_bar.visible:
			action_bar.value = g.action_elapsed/maxf(.01,g.action_duration)*100

func tick(delta: float) -> void:
	event_time = maxf(0,event_time-delta)
	event_panel.visible = event_time > 0 and hud.visible

func toast(text: String) -> void:
	event_messages.append(text)
	if event_messages.size() > 2:
		event_messages.pop_front()
	event_text.text = "\n\n".join(event_messages)
	event_time = 7

func time_text(seconds: float) -> String:
	var remaining = maxi(0,ceili(seconds))
	return "%02d:%02d" % [remaining/60,remaining%60]

func clear_menu() -> void:
	if is_instance_valid(menu):
		root.remove_child(menu)
		menu.queue_free()
		menu = null

func show_menu(g) -> void:
	close_overlay()
	clear_menu()
	hud.visible = false
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var shade = ColorRect.new()
	shade.color = Color("142029e9")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	fixed_label(menu,Rect2(72,37,850,35),"НЕРАБОЧЕЕ НАСТРОЕНИЕ    /    ЭТАЖ 03",17,ACCENT)
	fixed_label(menu,Rect2(74,122,850,92),"КАК ДОСТАТЬ",76)
	fixed_label(menu,Rect2(70,205,850,118),"ОТДЕЛ",104,ACCENT)
	fixed_label(menu,Rect2(78,350,740,45),"ДИМА НА РАБОТЕ",24)
	fixed_label(menu,Rect2(78,402,690,95),"У всех свои задачи. У Димы — свои планы.\nНаблюдай. Подготовь. Уходи с невинным лицом.",23,Color("b7c1bb"))
	var can_resume = not Profile.data.session.is_empty()
	fixed_button(menu,Rect2(78,520,315,61),"ПРОДОЛЖИТЬ СМЕНУ" if can_resume else "НАЧАТЬ СМЕНУ", "continue" if can_resume else "start",int(Profile.data.unlocked),true)
	fixed_button(menu,Rect2(409,520,182,61),"Управление", "settings")
	fixed_button(menu,Rect2(607,520,130,61),"Выход", "quit")
	var ids = ["dima","lena","marina","pasha"]
	for i in range(4):
		var id: String = ids[i]
		var texture = portrait(menu,id,Vector2(165,310),true)
		texture.position = Vector2(854+i*169,187)
		var name = fixed_label(menu,Rect2(854+i*169,511,165,34),OfficeCatalog.NAMES[id],21,Color(OfficeCatalog.COLORS[id]))
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fixed_label(menu,Rect2(78,626,1420,32),"ОДНА НЕДЕЛЯ. ДЕСЯТЬ ПОВОДОВ.   /   ЭПИЗОДЫ",15,MUTED)
	for i in range(g.catalog.episodes.size()):
		var e = g.catalog.episodes[i]
		var text = "%02d   %s" % [i+1,e.title]
		if Profile.data.best.has(str(i)):
			text += "   ✓"
		var card = fixed_button(menu,Rect2(78+(i%5)*289,676+(i/5)*72,275,60),text,"start",i)
		card.add_theme_font_size_override("font_size",15)
		card.disabled = i > int(Profile.data.unlocked)
		card.tooltip_text = e.intro if not card.disabled else "Сначала завершите предыдущий эпизод."
	fixed_label(menu,Rect2(78,849,1420,26),"Нативная версия 0.2  ·  ЛКМ — путь и действие  ·  ПКМ — отмена  ·  Пробел — пауза  ·  F11 — полный экран",15,MUTED)

func modal(title: String, width: float = 740, height: float = 650) -> VBoxContainer:
	close_overlay()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var shade = ColorRect.new()
	shade.color = Color(0.03,.045,.055,.83)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var card = panel(overlay,Rect2((1600-width)/2,(900-height)/2,width,height))
	var v = vbox(card,12)
	label(v,title,32,ACCENT)
	return v

func close_overlay() -> void:
	binding_action = ""
	modal_kind = ""
	if is_instance_valid(overlay):
		root.remove_child(overlay)
		overlay.queue_free()
		overlay = null

func show_pause(g) -> void:
	var v = modal("Смена на паузе",680,560)
	modal_kind = "pause"
	label(v,g.level.title,21)
	var text = label(v,"Время и коллеги остановлены. Прогресс текущей смены сохраняется автоматически.\n\nЛКМ — подойти и выполнить действие.\nПКМ — отменить путь или подготовку пакости.\nE — действие рядом, включая укрытие.\nWASD / стрелки — движение; оно отменяет команду мыши.",18,MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(v,"Продолжить  [Пробел / Esc]","resume",null,true)
	button(v,"Управление и звук","settings")
	button(v,"Начать эпизод заново","restart")
	button(v,"Сохранить и выйти в меню","menu")

func show_brief(g) -> void:
	var v = modal("Эпизод %02d   /   %s" % [g.episode+1,g.level.title],820,540)
	modal_kind = "brief"
	var intro = label(v,g.level.intro,24)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var text = label(v,g.level.brief,19,MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tip = label(v,"Канцтовары подбираются одним действием. Инструменты применяются автоматически. Подготовленная пакость засчитается только после реакции коллеги.",18,CREAM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(v,"Я вообще мимо проходил  →","resume",null,true)

func show_result(g, victory: bool) -> void:
	var v = modal("СМЕНА ЗАВЕРШЕНА" if victory else "ДИМА, НА МИНУТОЧКУ",760,600)
	modal_kind = "result"
	label(v,g.level.title,23)
	var row = HBoxContainer.new()
	v.add_child(row)
	portrait(row,"dima",Vector2(145,230),true)
	var stats = vbox(row,12)
	label(stats,"Легенда отдела" if victory and g.strikes == 0 else ("Офисный шутник" if victory else "План нуждается в доработке"),26,ACCENT)
	label(stats,"Реакций: %d / %d\nОчков: %d\nЛучшее комбо: ×%d\nЗамечаний: %d / 3" % [g.completed_count(),g.level.tasks.size(),g.score,g.best_combo,g.strikes],21)
	if victory and g.episode < 9:
		button(v,"Следующий эпизод →","start",g.episode+1,true)
	button(v,"Сыграть ещё раз","start",g.episode,not victory)
	button(v,"В меню","menu")

func show_settings(g) -> void:
	var v = modal("Управление и звук",890,790)
	modal_kind = "settings"
	var tips = label(v,"Основное управление — мышью. Левая кнопка: идти / действовать. Правая: отменить. Колесо: масштаб. Средняя кнопка: переместить камеру.\nПробел / Esc: пауза. F11: полный экран. Эти клавиши зарезервированы.",17,MUTED)
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(v,"Нажмите кнопку и затем новую клавишу",18,CREAM)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",9)
	grid.add_theme_constant_override("v_separation",9)
	v.add_child(grid)
	var names = {"move_up":"Вперёд","move_down":"Назад","move_left":"Влево","move_right":"Вправо","interact":"Действие / укрытие","sneak":"Тихий шаг","innocent":"Невинное лицо","inspect":"Подсказки","recenter":"Камера к Диме"}
	for key in names:
		var b = button(grid,names[key]+": "+Profile.key_label(key),"noop")
		b.custom_minimum_size.x = 270
		b.add_theme_font_size_override("font_size",15)
		b.pressed.connect(func(): binding_action = key; binding_button = b; b.text = "Нажмите клавишу… (Esc — отмена)")
	label(v,"Громкость",18,MUTED)
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = .05
	slider.value = float(Profile.data.volume)
	slider.custom_minimum_size.y = 32
	v.add_child(slider)
	slider.value_changed.connect(func(value): Profile.data.volume = value; Profile.apply_volume())
	label(v,"Темп новой смены (текущая смена не меняется)",18,MUTED)
	var choice = OptionButton.new()
	choice.custom_minimum_size.y = 44
	choice.add_theme_font_size_override("font_size",18)
	var difficulties = ["easy","normal","hard"]
	for key in difficulties:
		choice.add_item(OfficeCatalog.DIFFICULTY[key].name)
	choice.select(difficulties.find(Profile.data.difficulty))
	choice.item_selected.connect(func(index): Profile.data.difficulty = difficulties[index])
	v.add_child(choice)
	var note = label(v,"В этой версии персонажи — отрисованные 2D-спрайты в объёмном 3D-офисе. Руководитель участвует в поздних эпизодах за кадром: его проверки идут по таймеру.",15,MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button(v,"Сбросить клавиши","reset_keys")
	button(v,"Готово","close_settings",null,true)

func _input(event: InputEvent) -> void:
	if binding_action == "" or not event is InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		binding_button.text = Profile.key_label(binding_action)
		binding_action = ""
		return
	if Profile.rebind(binding_action,event.physical_keycode):
		binding_button.text = Profile.key_label(binding_action)
		binding_action = ""
	else:
		binding_button.text = "Клавиша занята. Выберите другую."
