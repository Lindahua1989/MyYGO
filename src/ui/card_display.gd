## CardDisplay - 卡牌渲染组件
## 在UI中显示一张卡牌的完整信息
## 支持大卡(详情)和小卡(列表)两种显示尺寸
class_name CardDisplay
extends Control

# ============================================================
# 导出参数
# ============================================================

## 显示尺寸模式
@export var display_mode: String = "large"  # "large" (详情 199x290比例) or "mini" (列表 49x72比例)
## 是否显示详细信息 (ATK/DEF等)
@export var show_details: bool = true
## 卡牌数据引用
var card: CardData = null

# ============================================================
# 尺寸常量
# ============================================================

const LARGE_CARD_WIDTH: float = 200.0
const LARGE_CARD_HEIGHT: float = 290.0
const MINI_CARD_WIDTH: float = 60.0
const MINI_CARD_HEIGHT: float = 87.0

# ============================================================
# 子节点引用
# ============================================================

var art_texture_rect: TextureRect
var name_label: Label
var type_label: Label
var stats_label: Label
var star_label: Label
var attribute_icon: TextureRect
var border_panel: Panel

# ============================================================
# 卡图纹理缓存
# ============================================================

static var _texture_cache: Dictionary = {}

# ============================================================
# 初始化
# ============================================================

func _init() -> void:
	# 构建UI子节点
	_build_ui()

func _ready() -> void:
	if card != null:
		update_display()

# ============================================================
# UI构建
# ============================================================

func _build_ui() -> void:
	# 设置自定义最小尺寸
	if display_mode == "large":
		custom_minimum_size = Vector2(LARGE_CARD_WIDTH, LARGE_CARD_HEIGHT)
	else:
		custom_minimum_size = Vector2(MINI_CARD_WIDTH, MINI_CARD_HEIGHT)

	# 卡牌边框背景
	border_panel = Panel.new()
	border_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(border_panel)

	# 卡图显示
	art_texture_rect = TextureRect.new()
	art_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	art_texture_rect.stretch_mode = TextureRect.STretchMode.STRETCH_KEEP_ASPECT_CENTERED
	art_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_texture_rect.set_anchor_offset(SIDE_TOP, 5)
	art_texture_rect.set_anchor_offset(SIDE_BOTTOM, -40)
	art_texture_rect.set_anchor_offset(SIDE_LEFT, 5)
	art_texture_rect.set_anchor_offset(SIDE_RIGHT, -5)
	add_child(art_texture_rect)

	# 卡名标签 (底部)
	name_label = Label.new()
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.set_anchor_offset(SIDE_TOP, -35)
	name_label.set_anchor_offset(SIDE_BOTTOM, -18)
	name_label.set_anchor_offset(SIDE_LEFT, 5)
	name_label.set_anchor_offset(SIDE_RIGHT, -5)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var name_font_size = 11 if display_mode == "mini" else 14
	name_label.add_theme_font_size_override("font_size", name_font_size)
	add_child(name_label)

	# ATK/DEF 标签 (最底部)
	stats_label = Label.new()
	stats_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stats_label.set_anchor_offset(SIDE_TOP, -16)
	stats_label.set_anchor_offset(SIDE_BOTTOM, 0)
	stats_label.set_anchor_offset(SIDE_LEFT, 5)
	stats_label.set_anchor_offset(SIDE_RIGHT, -5)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 10)
	add_child(stats_label)

	# 星级标签 (右上角)
	star_label = Label.new()
	star_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	star_label.set_anchor_offset(SIDE_LEFT, -40)
	star_label.set_anchor_offset(SIDE_RIGHT, -2)
	star_label.set_anchor_offset(SIDE_TOP, 2)
	star_label.set_anchor_offset(SIDE_BOTTOM, 15)
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	star_label.add_theme_font_size_override("font_size", 10)
	add_child(star_label)

	# 卡类型标签 (左上角)
	type_label = Label.new()
	type_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	type_label.set_anchor_offset(SIDE_LEFT, 2)
	type_label.set_anchor_offset(SIDE_RIGHT, 40)
	type_label.set_anchor_offset(SIDE_TOP, 2)
	type_label.set_anchor_offset(SIDE_BOTTOM, 15)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	type_label.add_theme_font_size_override("font_size", 9)
	add_child(type_label)

# ============================================================
# 显示更新
# ============================================================

## 设置卡牌数据并更新显示
func set_card(new_card: CardData) -> void:
	card = new_card
	if is_node_ready():
		update_display()

## 更新全部显示内容
func update_display() -> void:
	if card == null:
		_clear_display()
		return

	# 卡名
	name_label.text = card.get_display_name(CardDatabase.current_language)

	# ATK/DEF (仅怪兽显示)
	if card.is_monster() and show_details:
		stats_label.text = "%d/%d" % [card.attack, card.defense]
	else:
		stats_label.text = ""

	# 星级 (仅怪兽)
	if card.is_monster():
		star_label.text = "★%d" % card.star
	else:
		star_label.text = ""

	# 卡类型短标签
	if card.is_spell():
		type_label.text = "魔"
	elif card.is_trap():
		type_label.text = "罠"
	elif card.is_effect_monster():
		type_label.text = "效"
	elif card.is_fusion_monster():
		type_label.text = "融"
	elif card.is_ritual_monster():
		type_label.text = "仪"
	else:
		type_label.text = ""

	# 卡图纹理加载
	_load_card_art()

	# 根据卡类型设置边框颜色
	_update_border_color()

## 加载卡图纹理 (懒加载 + 缓存)
func _load_card_art() -> void:
	if card.art_file == "":
		art_texture_rect.texture = null
		return

	# 检查缓存
	if _texture_cache.has(card.art_file):
		art_texture_rect.texture = _texture_cache[card.art_file]
		return

	# 构建纹理路径
	var art_dir = "art" if display_mode == "large" else "mini"
	var texture_path = "res://assets/cards/%s/%s.png" % [art_dir, card.art_file]

	# 检查文件是否存在
	if not FileAccess.file_exists(texture_path):
		# 尝试大卡图目录作为fallback
		texture_path = "res://assets/cards/art/%s.png" % card.art_file
		if not FileAccess.file_exists(texture_path):
			art_texture_rect.texture = null
			return

	# 加载纹理
	var texture = load(texture_path)
	if texture != null:
		_texture_cache[card.art_file] = texture
		art_texture_rect.texture = texture
	else:
		art_texture_rect.texture = null

## 根据卡类型更新边框颜色
func _update_border_color() -> void:
	# 使用StyleBoxFlat设置边框颜色
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(3)

	if card.is_monster():
		# 怪兽卡 - 不同色调
		if card.attribute == "light":
			style.bg_color = Color(0.95, 0.93, 0.85)  # 淡黄
		elif card.attribute == "dark":
			style.bg_color = Color(0.15, 0.15, 0.2)   # 深紫黑
		elif card.attribute == "water":
			style.bg_color = Color(0.7, 0.85, 0.95)   # 蓝
		elif card.attribute == "fire":
			style.bg_color = Color(0.95, 0.8, 0.7)    # 红
		elif card.attribute == "earth":
			style.bg_color = Color(0.85, 0.75, 0.65)  # 土
		elif card.attribute == "wind":
			style.bg_color = Color(0.75, 0.9, 0.75)   # 绿
		elif card.attribute == "divine":
			style.bg_color = Color(0.9, 0.85, 0.6)    # 金
		else:
			style.bg_color = Color(0.8, 0.8, 0.8)
	elif card.is_spell():
		style.bg_color = Color(0.6, 0.8, 0.95)  # 魔法卡蓝绿
	elif card.is_trap():
		style.bg_color = Color(0.85, 0.6, 0.6)  # 陷阱卡红紫
	else:
		style.bg_color = Color(0.5, 0.5, 0.5)

	style.border_color = Color(0.2, 0.2, 0.2)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2

	border_panel.add_theme_stylebox_override("panel", style)

## 清除显示内容
func _clear_display() -> void:
	art_texture_rect.texture = null
	name_label.text = ""
	stats_label.text = ""
	star_label.text = ""
	type_label.text = ""

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3)
	style.set_corner_radius_all(3)
	border_panel.add_theme_stylebox_override("panel", style)

# ============================================================
# 鼠标交互
# ============================================================

var _hovered: bool = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovered = true
		# 悬停时放大一点
		if display_mode == "mini":
			scale = Vector2(1.1, 1.1)
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovered = false
		scale = Vector2(1.0, 1.0)
