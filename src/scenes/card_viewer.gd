## CardViewer - 卡牌浏览场景
## 显示全部1115张卡牌，支持筛选、搜索和详情查看
extends Control

# ============================================================
# 导出参数
# ============================================================

@export var grid_columns: int = 8
@export var mini_card_size: Vector2 = Vector2(60, 87)
@export var card_spacing: float = 8.0

# ============================================================
# 子节点 (将在_ready中动态构建)
# ============================================================

var _grid_container: GridContainer
var _scroll_container: ScrollContainer
var _filter_panel: VBoxContainer
var _search_bar: HBoxContainer
var _search_input: LineEdit
var _detail_panel: Panel
var _detail_card: CardDisplay
var _detail_name_label: Label
var _detail_desc_label: RichTextLabel
var _detail_stats_label: Label
var _card_count_label: Label
var _card_items: Array = []  # 当前显示的CardDisplay实例

# ============================================================
# 筛选状态
# ============================================================

var _current_filters: Dictionary = {}
var _current_cards: Array = []

# ============================================================
# 场景初始化
# ============================================================

func _ready() -> void:
	name = "CardViewer"
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_build_ui()

	# 等待数据库加载完成后显示卡牌
	if CardDatabase.is_loaded:
		_on_database_loaded(CardDatabase.cards.size())
	else:
		CardDatabase.database_loaded.connect(_on_database_loaded)

	CardDatabase.language_changed.connect(_on_language_changed)

# ============================================================
# UI构建
# ============================================================

func _build_ui() -> void:
	# 主布局: 左侧筛选面板 + 右侧卡牌网格
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 10)
	add_child(main_hbox)

	# === 左侧: 筛选面板 ===
	_filter_panel = VBoxContainer.new()
	_filter_panel.custom_minimum_size = Vector2(180, 0)
	_filter_panel.add_theme_constant_override("separation", 5)
	main_hbox.add_child(_filter_panel)

	# 标题
	var title_label = Label.new()
	title_label.text = "🔍 卡牌筛选"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	_filter_panel.add_child(title_label)

	# 搜索栏
	_search_bar = HBoxContainer.new()
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "搜索卡名..."
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.text_changed.connect(_on_search_changed)
	_search_bar.add_child(_search_input)
	_filter_panel.add_child(_search_bar)

	# 卡类型筛选按钮组
	_add_filter_section("卡牌类型", [
		{"label": "全部", "filter": {}},
		{"label": "怪兽", "filter": {"kind": "monster"}},
		{"label": "魔法", "filter": {"kind": "spell"}},
		{"label": "陷阱", "filter": {"kind": "trap"}},
		{"label": "通常怪兽", "filter": {"card_type": "monster_normal"}},
		{"label": "效果怪兽", "filter": {"card_type": "monster_effect"}},
		{"label": "融合怪兽", "filter": {"card_type": "monster_fusion"}},
		{"label": "仪式怪兽", "filter": {"card_type": "monster_ritual"}},
		{"label": "通常魔法", "filter": {"card_type": "spell_normal"}},
		{"label": "装备魔法", "filter": {"card_type": "spell_equip"}},
		{"label": "通常陷阱", "filter": {"card_type": "trap_normal"}},
		{"label": "反击陷阱", "filter": {"card_type": "trap_counter"}},
	])

	# 属性筛选按钮组
	_add_filter_section("属性", [
		{"label": "光", "filter": {"attribute": "light"}},
		{"label": "暗", "filter": {"attribute": "dark"}},
		{"label": "水", "filter": {"attribute": "water"}},
		{"label": "炎", "filter": {"attribute": "fire"}},
		{"label": "地", "filter": {"attribute": "earth"}},
		{"label": "风", "filter": {"attribute": "wind"}},
	])

	# 种族筛选按钮组
	_add_filter_section("种族", [
		{"label": "龙族", "filter": {"race": "dragon"}},
		{"label": "战士族", "filter": {"race": "warrior"}},
		{"label": "魔法使族", "filter": {"race": "spellcaster"}},
		{"label": "恶魔族", "filter": {"race": "fiend"}},
		{"label": "机械族", "filter": {"race": "machine"}},
		{"label": "天使族", "filter": {"race": "fairy"}},
	])

	# 卡牌计数显示
	_card_count_label = Label.new()
	_card_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_count_label.add_theme_font_size_override("font_size", 12)
	_filter_panel.add_child(_card_count_label)

	# === 右侧: 卡牌网格区域 ===
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_vbox)

	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(_scroll_container)

	_grid_container = GridContainer.new()
	_grid_container.columns = grid_columns
	_grid_container.add_theme_constant_override("h_separation", card_spacing)
	_grid_container.add_theme_constant_override("v_separation", card_spacing)
	_scroll_container.add_child(_grid_container)

	# === 详情面板 (最右侧, 点击卡牌时显示) ===
	_detail_panel = Panel.new()
	_detail_panel.custom_minimum_size = Vector2(220, 0)
	_detail_panel.visible = false
	main_hbox.add_child(_detail_panel)

	var detail_vbox = VBoxContainer.new()
	detail_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_vbox.add_theme_constant_override("separation", 5)
	_detail_panel.add_child(detail_vbox)

	# 详情大卡图
	_detail_card = CardDisplay.new()
	_detail_card.display_mode = "large"
	_detail_card.show_details = true
	_detail_card.custom_minimum_size = Vector2(200, 290)
	detail_vbox.add_child(_detail_card)

	# 详情卡名
	_detail_name_label = Label.new()
	_detail_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name_label.add_theme_font_size_override("font_size", 16)
	detail_vbox.add_child(_detail_name_label)

	# 详情统计
	_detail_stats_label = Label.new()
	_detail_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_stats_label.add_theme_font_size_override("font_size", 13)
	detail_vbox.add_child(_detail_stats_label)

	# 详情描述
	_detail_desc_label = RichTextLabel.new()
	_detail_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_desc_label.add_theme_font_size_override("normal_font_size", 12)
	detail_vbox.add_child(_detail_desc_label)

## 添加筛选区块
func _add_filter_section(title: String, options: Array) -> void:
	var section_label = Label.new()
	section_label.text = "── " + title + " ──"
	section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_label.add_theme_font_size_override("font_size", 12)
	_filter_panel.add_child(section_label)

	for option in options:
		var button = Button.new()
		button.text = option["label"]
		button.add_theme_font_size_override("font_size", 11)
		button.custom_minimum_size = Vector2(0, 28)
		button.pressed.connect(_on_filter_button_pressed.bind(option["filter"]))
		_filter_panel.add_child(button)

# ============================================================
# 卡牌显示逻辑
# ============================================================

func _on_database_loaded(total_count: int) -> void:
	print("CardViewer: 数据库加载完成，开始显示 %d 张卡牌" % total_count)
	_current_cards = CardDatabase.get_all_cards()
	_refresh_grid()

func _on_language_changed(lang: String) -> void:
	# 刷新全部卡牌显示
	_refresh_grid()
	# 如果详情面板打开，也刷新详情
	if _detail_panel.visible and _detail_card.card != null:
		_show_card_detail(_detail_card.card)

## 刷新卡牌网格
func _refresh_grid() -> void:
	# 清除现有的卡牌显示
	for item in _card_items:
		item.queue_free()
	_card_items.clear()

	# 应用筛选
	var filtered_cards = CardDatabase.filter_cards(_current_filters)

	# 更新计数
	_card_count_label.text = "显示: %d / %d 张" % [filtered_cards.size(), CardDatabase.cards.size()]

	# 创建新的卡牌显示
	for card_data in filtered_cards:
		var card_display = CardDisplay.new()
		card_display.display_mode = "mini"
		card_display.show_details = true
		card_display.set_card(card_data)
		card_display.custom_minimum_size = mini_card_size
		card_display.gui_input.connect(_on_card_clicked.bind(card_data))
		_grid_container.add_child(card_display)
		_card_items.append(card_display)

## 显示卡牌详情
func _show_card_detail(card_data: CardData) -> void:
	_detail_panel.visible = true
	_detail_card.set_card(card_data)
	_detail_name_label.text = card_data.get_display_name(CardDatabase.current_language)

	# 构建详情统计行
	var stats_parts: Array = []
	if card_data.is_monster():
		stats_parts.append(card_data.get_star_display())
		stats_parts.append(card_data.get_attribute_display_cn())
		stats_parts.append(card_data.get_race_display_cn())
		stats_parts.append("ATK %d / DEF %d" % [card_data.attack, card_data.defense])
	else:
		stats_parts.append(card_data.get_card_type_display_cn())
	_detail_stats_label.text = " | ".join(stats_parts)

	# 卡牌描述
	_detail_desc_label.text = card_data.get_display_description(CardDatabase.current_language)

# ============================================================
# 事件处理
# ============================================================

func _on_filter_button_pressed(filter_dict: Dictionary) -> void:
	_current_filters = filter_dict
	_refresh_grid()

func _on_search_changed(new_text: String) -> void:
	if new_text == "":
		_current_filters.erase("name_query")
	else:
		_current_filters["name_query"] = new_text
	_refresh_grid()

func _on_card_clicked(event: InputEvent, card_data: CardData) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_card_detail(card_data)
