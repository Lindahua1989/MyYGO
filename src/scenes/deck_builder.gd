## DeckBuilder - 组卡器场景
## 左侧卡池(筛选+搜索), 右侧卡组列表+统计, 底部操作按钮
extends Control

# ============================================================
# 组件引用
# ============================================================

var _current_deck: DeckData = null
var _banlist: BanlistManager = null
var _card_pool_grid: GridContainer
var _deck_list_grid: GridContainer
var _search_input: LineEdit
var _filter_buttons: VBoxContainer
var _stats_panel: VBoxContainer
var _stats_labels: Dictionary = {}
var _deck_name_input: LineEdit
var _card_pool_items: Array = []
var _deck_items: Array = []
var _detail_panel: Panel
var _detail_card_display: CardDisplay
var _card_count_label: Label

# ============================================================
# 筛选状态
# ============================================================

var _current_filters: Dictionary = {}

# ============================================================
# 场景初始化
# ============================================================

func _ready() -> void:
	name = "DeckBuilder"
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_banlist = BanlistManager.new()
	_banlist.load_default()

	_current_deck = DeckData.new()

	_build_ui()
	_refresh_card_pool()
	_refresh_deck_list()
	_update_stats()

# ============================================================
# UI构建
# ============================================================

func _build_ui() -> void:
	# 主布局: 3列 - 筛选面板 | 卡池网格 | 卡组+统计
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 8)
	add_child(main_hbox)

	# === 左列: 筛选面板 ===
	_filter_buttons = VBoxContainer.new()
	_filter_buttons.custom_minimum_size = Vector2(160, 0)
	_filter_buttons.add_theme_constant_override("separation", 4)
	main_hbox.add_child(_filter_buttons)

	var filter_title = Label.new()
	filter_title.text = "🔍 卡池筛选"
	filter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	filter_title.add_theme_font_size_override("font_size", 15)
	_filter_buttons.add_child(filter_title)

	# 搜索栏
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "搜索卡名..."
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.text_changed.connect(_on_search_changed)
	_filter_buttons.add_child(_search_input)

	# 类型筛选按钮
	_add_filter_btn("全部", {})
	_add_filter_btn("怪兽", {"kind": "monster"})
	_add_filter_btn("魔法", {"kind": "spell"})
	_add_filter_btn("陷阱", {"kind": "trap"})
	_add_filter_btn("通常怪兽", {"card_type": "monster_normal"})
	_add_filter_btn("效果怪兽", {"card_type": "monster_effect"})
	_add_filter_btn("融合怪兽", {"card_type": "monster_fusion"})
	_add_filter_btn("仪式怪兽", {"card_type": "monster_ritual"})

	# 属性筛选
	_add_section("属性")
	_add_filter_btn("光", {"attribute": "light"})
	_add_filter_btn("暗", {"attribute": "dark"})
	_add_filter_btn("水", {"attribute": "water"})
	_add_filter_btn("炎", {"attribute": "fire"})
	_add_filter_btn("地", {"attribute": "earth"})
	_add_filter_btn("风", {"attribute": "wind"})

	# === 中列: 卡池网格 ===
	var pool_vbox = VBoxContainer.new()
	pool_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(pool_vbox)

	var pool_title = Label.new()
	pool_title.text = "卡池 (点击添加到卡组)"
	pool_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pool_title.add_theme_font_size_override("font_size", 14)
	pool_vbox.add_child(pool_title)

	_card_count_label = Label.new()
	_card_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_count_label.add_theme_font_size_override("font_size", 12)
	pool_vbox.add_child(_card_count_label)

	var pool_scroll = ScrollContainer.new()
	pool_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pool_vbox.add_child(pool_scroll)

	_card_pool_grid = GridContainer.new()
	_card_pool_grid.columns = 8
	_card_pool_grid.add_theme_constant_override("h_separation", 4)
	_card_pool_grid.add_theme_constant_override("v_separation", 4)
	pool_scroll.add_child(_card_pool_grid)

	# === 右列: 卡组 + 统计 ===
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(280, 0)
	right_vbox.add_theme_constant_override("separation", 6)
	main_hbox.add_child(right_vbox)

	# 卡组名称
	var name_hbox = HBoxContainer.new()
	var name_prompt = Label.new()
	name_prompt.text = "卡组名:"
	name_hbox.add_child(name_prompt)
	_deck_name_input = LineEdit.new()
	_deck_name_input.text = _current_deck.deck_name
	_deck_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_name_input.text_changed.connect(_on_deck_name_changed)
	name_hbox.add_child(_deck_name_input)
	right_vbox.add_child(name_hbox)

	# 卡组列表标题
	var deck_title = Label.new()
	deck_title.text = "卡组列表 (点击移除)"
	deck_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_title.add_theme_font_size_override("font_size", 14)
	right_vbox.add_child(deck_title)

	# 卡组列表
	var deck_scroll = ScrollContainer.new()
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(deck_scroll)

	_deck_list_grid = GridContainer.new()
	_deck_list_grid.columns = 4
	_deck_list_grid.add_theme_constant_override("h_separation", 4)
	_deck_list_grid.add_theme_constant_override("v_separation", 4)
	deck_scroll.add_child(_deck_list_grid)

	# 统计面板
	_stats_panel = VBoxContainer.new()
	_stats_panel.add_theme_constant_override("separation", 2)
	right_vbox.add_child(_stats_panel)

	var stats_title = Label.new()
	stats_title.text = "── 卡组统计 ──"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_size_override("font_size", 12)
	_stats_panel.add_child(stats_title)

	# 预创建统计标签
	_stats_labels["main_count"] = _create_stat_label("主卡组: 0/40-60")
	_stats_labels["extra_count"] = _create_stat_label("额外: 0/15")
	_stats_labels["monsters"] = _create_stat_label("怪兽: 0")
	_stats_labels["spells"] = _create_stat_label("魔法: 0")
	_stats_labels["traps"] = _create_stat_label("陷阱: 0")
	_stats_labels["avg_atk"] = _create_stat_label("平均ATK: 0")
	_stats_labels["avg_def"] = _create_stat_label("平均DEF: 0")
	_stats_labels["banlist"] = _create_stat_label("禁限卡: ✓ 合规")

	# 操作按钮
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 6)
	right_vbox.add_child(btn_hbox)

	var save_btn = Button.new()
	save_btn.text = "💾 保存"
	save_btn.pressed.connect(_on_save_pressed)
	btn_hbox.add_child(save_btn)

	var load_btn = Button.new()
	load_btn.text = "📂 加载"
	load_btn.pressed.connect(_on_load_pressed)
	btn_hbox.add_child(load_btn)

	var clear_btn = Button.new()
	clear_btn.text = "🗑 清空"
	clear_btn.pressed.connect(_on_clear_pressed)
	btn_hbox.add_child(clear_btn)

	var back_btn = Button.new()
	back_btn.text = "↩ 返回"
	back_btn.pressed.connect(_on_back_pressed)
	btn_hbox.add_child(back_btn)

func _add_filter_btn(text: String, filter_dict: Dictionary) -> void:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 11)
	btn.custom_minimum_size = Vector2(0, 26)
	btn.pressed.connect(_on_filter_btn.bind(filter_dict))
	_filter_buttons.add_child(btn)

func _add_section(title: String) -> void:
	var label = Label.new()
	label.text = "── " + title + " ──"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	_filter_buttons.add_child(label)

func _create_stat_label(initial_text: String) -> Label:
	var label = Label.new()
	label.text = initial_text
	label.add_theme_font_size_override("font_size", 11)
	_stats_panel.add_child(label)
	return label

# ============================================================
# 卡池刷新
# ============================================================

func _refresh_card_pool() -> void:
	for item in _card_pool_items:
		item.queue_free()
	_card_pool_items.clear()

	var filtered_cards = CardDatabase.filter_cards(_current_filters)
	_card_count_label.text = "显示: %d / %d" % [filtered_cards.size(), CardDatabase.cards.size()]

	for card_data in filtered_cards:
		var display = CardDisplay.new()
		display.display_mode = "mini"
		display.show_details = true
		display.set_card(card_data)
		display.custom_minimum_size = Vector2(60, 87)
		display.gui_input.connect(_on_pool_card_clicked.bind(card_data))
		_card_pool_grid.add_child(display)
		_card_pool_items.append(display)

# ============================================================
# 卡组列表刷新
# ============================================================

func _refresh_deck_list() -> void:
	for item in _deck_items:
		item.queue_free()
	_deck_items.clear()

	for idx in _current_deck.main_deck:
		var card: CardData = CardDatabase.get_card(idx)
		if card == null:
			continue

		var display = CardDisplay.new()
		display.display_mode = "mini"
		display.show_details = true
		display.set_card(card)
		display.custom_minimum_size = Vector2(60, 87)
		display.gui_input.connect(_on_deck_card_clicked.bind(idx))
		_deck_list_grid.add_child(display)
		_deck_items.append(display)

# ============================================================
# 统计更新
# ============================================================

func _update_stats() -> void:
	var stats = _current_deck.get_statistics()
	_stats_labels["main_count"].text = "主卡组: %d / 40-60" % stats["total_main"]
	_stats_labels["extra_count"].text = "额外: %d / 15" % stats["total_extra"]
	_stats_labels["monsters"].text = "怪兽: %d" % stats["monsters"]
	_stats_labels["spells"].text = "魔法: %d" % stats["spells"]
	_stats_labels["traps"].text = "陷阱: %d" % stats["traps"]
	_stats_labels["avg_atk"].text = "平均ATK: %d" % stats["avg_atk"]
	_stats_labels["avg_def"].text = "平均DEF: %d" % stats["avg_def"]

	var errors = _current_deck.validate_banlist(_banlist)
	if errors.size() > 0:
		_stats_labels["banlist"].text = "禁限卡: ✗ " + errors[0]
	else:
		_stats_labels["banlist"].text = "禁限卡: ✓ 合规"

# ============================================================
# 事件处理
# ============================================================

func _on_pool_card_clicked(event: InputEvent, card_data: CardData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 检查禁限卡限制
		var max_allowed = _banlist.get_max_allowed(card_data.idx)
		var current_count = _current_deck.count_total(card_data.idx)
		if current_count >= max_allowed:
			return  # 超出限制, 不添加
		if card_data.is_fusion_monster():
			_current_deck.add_to_extra(card_data.idx)
		else:
			_current_deck.add_to_main(card_data.idx)
		_refresh_deck_list()
		_update_stats()

func _on_deck_card_clicked(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _current_deck.count_in_main(idx) > 0:
			_current_deck.remove_from_main(idx)
		else:
			_current_deck.remove_from_extra(idx)
		_refresh_deck_list()
		_update_stats()

func _on_filter_btn(filter_dict: Dictionary) -> void:
	_current_filters = filter_dict
	_refresh_card_pool()

func _on_search_changed(new_text: String) -> void:
	if new_text == "":
		_current_filters.erase("name_query")
	else:
		_current_filters["name_query"] = new_text
	_refresh_card_pool()

func _on_deck_name_changed(new_text: String) -> void:
	_current_deck.deck_name = new_text

func _on_save_pressed() -> void:
	var save_dir = "user://decks"
	DirAccess.make_dir_recursive_absolute(save_dir)
	var filepath = save_dir + "/" + _current_deck.deck_name + ".json"
	if _current_deck.save_to_file(filepath):
		print("卡组已保存: " + filepath)
	else:
		print("保存失败!")

func _on_load_pressed() -> void:
	var save_dir = "user://decks"
	if not DirAccess.dir_exists_absolute(save_dir):
		print("没有保存的卡组")
		return

	var dir = DirAccess.open(save_dir)
	if dir == null:
		return

	var files: Array = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()

	if files.size() == 0:
		print("没有保存的卡组")
		return

	# 简单加载第一个文件
	var filepath = save_dir + "/" + files[0]
	var loaded = DeckData.load_from_file(filepath)
	if loaded != null:
		_current_deck = loaded
		_deck_name_input.text = _current_deck.deck_name
		_refresh_deck_list()
		_update_stats()
		print("卡组已加载: " + filepath)

func _on_clear_pressed() -> void:
	_current_deck = DeckData.new()
	_current_deck.deck_name = _deck_name_input.text
	_refresh_deck_list()
	_update_stats()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://src/scenes/main_menu.tscn")
