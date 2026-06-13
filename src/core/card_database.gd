## CardDatabase - 卡牌数据库AutoLoad单例
## 启动时从card_database.json加载全部卡牌数据
## 提供查询、筛选、搜索等数据库操作
extends Node

# ============================================================
# 数据存储
# ============================================================

## 全部卡牌数据 (idx -> CardData)
var cards: Dictionary = {}
## 总卡牌数
var total_cards: int = 0
## 当前语言设置
var current_language: String = "eng"
## 是否已加载完成
var is_loaded: bool = false

# ============================================================
# 信号
# ============================================================

signal database_loaded(total_count: int)
signal language_changed(lang: String)

# ============================================================
# 数据库路径
# ============================================================

const DATABASE_PATH: String = "res://data/card_database.json"

# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	load_database()

# ============================================================
# 数据库加载
# ============================================================

## 从JSON文件加载全部卡牌数据
func load_database() -> void:
	print("CardDatabase: 开始加载卡牌数据库...")

	var file = FileAccess.open(DATABASE_PATH, FileAccess.READ)
	if file == null:
		push_error("CardDatabase: 无法打开数据库文件: " + DATABASE_PATH)
		print("CardDatabase: 错误 - ", FileAccess.get_open_error())
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("CardDatabase: JSON解析错误: " + str(json.get_error_line()) + " - " + json.get_error_message())
		return

	var data = json.data
	if data == null:
		push_error("CardDatabase: JSON数据为空")
		return

	total_cards = data.get("total_cards", 0)
	var cards_dict = data.get("cards", {})

	# 将每张卡的数据转换为CardData对象
	for key in cards_dict:
		var card_data = cards_dict[key]
		var card = CardData.create_from_dict(card_data)
		if not card.is_placeholder:
			cards[int(key)] = card

	is_loaded = true
	print("CardDatabase: 加载完成! 共 %d 张卡牌" % cards.size())
	database_loaded.emit(cards.size())

# ============================================================
# 基础查询
# ============================================================

## 根据idx获取卡牌
func get_card(idx: int) -> CardData:
	return cards.get(idx, null)

## 根据passcode获取卡牌
func get_card_by_passcode(passcode: int) -> CardData:
	for card in cards.values():
		if card.passcode == passcode:
			return card
	return null

## 根据art_file获取卡牌
func get_card_by_art_file(art_file: String) -> CardData:
	for card in cards.values():
		if card.art_file == art_file:
			return card
	return null

## 获取全部卡牌数组
func get_all_cards() -> Array:
	return cards.values()

## 获取全部卡牌idx列表 (排序)
func get_all_indices() -> Array:
	var indices = cards.keys()
	indices.sort()
	return indices

# ============================================================
# 筛选查询
# ============================================================

## 按卡类型筛选
func get_cards_by_type(card_type: String) -> Array:
	var result: Array = []
	for card in cards.values():
		if card.card_type == card_type:
			result.append(card)
	return result

## 按大类筛选 (monster/spell/trap)
func get_cards_by_kind(kind: String) -> Array:
	var result: Array = []
	for card in cards.values():
		if card.card_type.begins_with(kind):
			result.append(card)
	return result

## 按属性筛选 (仅怪兽)
func get_cards_by_attribute(attr: String) -> Array:
	var result: Array = []
	for card in cards.values():
		if card.is_monster() and card.attribute == attr:
			result.append(card)
	return result

## 按种族筛选 (仅怪兽)
func get_cards_by_race(race_name: String) -> Array:
	var result: Array = []
	for card in cards.values():
		if card.is_monster() and card.race == race_name:
			result.append(card)
	return result

## 按星级筛选 (仅怪兽)
func get_cards_by_star(star_level: int) -> Array:
	var result: Array = []
	for card in cards.values():
		if card.is_monster() and card.star == star_level:
			result.append(card)
	return result

## 按星级范围筛选
func get_cards_by_star_range(min_star: int, max_star: int) -> Array:
	var result: Array = []
	for card in cards.values():
		if card.is_monster() and card.star >= min_star and card.star <= max_star:
			result.append(card)
	return result

## 按ATK范围筛选
func get_cards_by_atk_range(min_atk: int, max_atk: int) -> Array:
	var result: Array = []
	for card in cards.values():
		if card.is_monster() and card.attack >= min_atk and card.attack <= max_atk:
			result.append(card)
	return result

# ============================================================
# 搜索
# ============================================================

## 按名称搜索 (支持模糊匹配)
func search_cards_by_name(query: String, lang: String = "") -> Array:
	if lang == "":
		lang = current_language

	var result: Array = []
	var lower_query = query.to_lower()

	for card in cards.values():
		var name = card.get_display_name(lang).to_lower()
		if name.contains(lower_query):
			result.append(card)

	return result

## 组合筛选 - 支持多条件同时筛选
func filter_cards(filters: Dictionary) -> Array:
	var result: Array = []
	for card in cards.values():
		var is_matched = true

		# 卡类型筛选
		if filters.has("card_type"):
			if card.card_type != filters["card_type"]:
				is_matched = false

		# 大类筛选
		if filters.has("kind"):
			if not card.card_type.begins_with(filters["kind"]):
				is_matched = false

		# 属性筛选
		if filters.has("attribute"):
			if not card.is_monster() or card.attribute != filters["attribute"]:
				is_matched = false

		# 种族筛选
		if filters.has("race"):
			if not card.is_monster() or card.race != filters["race"]:
				is_matched = false

		# 星级筛选
		if filters.has("star"):
			if not card.is_monster() or card.star != filters["star"]:
				is_matched = false

		# 名称搜索
		if filters.has("name_query"):
			var lang = filters.get("lang", current_language)
			var name = card.get_display_name(lang).to_lower()
			if not name.contains(filters["name_query"].to_lower()):
				is_matched = false

		if is_matched:
			result.append(card)

	return result

# ============================================================
# 统计信息
# ============================================================

## 获取各类型卡牌数量统计
func get_type_statistics() -> Dictionary:
	var stats: Dictionary = {}
	for card in cards.values():
		stats[card.card_type] = stats.get(card.card_type, 0) + 1
	return stats

## 获取各属性卡牌数量统计 (仅怪兽)
func get_attribute_statistics() -> Dictionary:
	var stats: Dictionary = {}
	for card in cards.values():
		if card.is_monster():
			stats[card.attribute] = stats.get(card.attribute, 0) + 1
	return stats

## 获取各种族卡牌数量统计 (仅怪兽)
func get_race_statistics() -> Dictionary:
	var stats: Dictionary = {}
	for card in cards.values():
		if card.is_monster():
			stats[card.race] = stats.get(card.race, 0) + 1
	return stats

# ============================================================
# 语言切换
# ============================================================

## 设置当前显示语言
func set_language(lang: String) -> void:
	current_language = lang
	language_changed.emit(lang)

## 获取当前语言
func get_language() -> String:
	return current_language
