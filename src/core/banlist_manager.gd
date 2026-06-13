## BanlistManager - 禁限卡管理器
## 加载和查询禁限卡表数据
class_name BanlistManager
extends RefCounted

# ============================================================
# 禁限卡类型常量
# ============================================================

enum BanStatus {
	FREE,       # 无限制
	LIMIT_ONE,  # 限制1张
	LIMIT_TWO,  # 限制2张
	FORBIDDEN,  # 禁止使用
}

# ============================================================
# 数据
# ============================================================

var _forbidden: Array[int] = []
var _limit_one: Array[int] = []
var _limit_two: Array[int] = []
var is_loaded: bool = false
var banlist_name: String = "default"

# ============================================================
# 加载
# ============================================================

func load_banlist(filepath: String) -> bool:
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("BanlistManager: 无法打开禁限表: " + filepath)
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("BanlistManager: JSON解析错误")
		return false

	var data = json.data

	_forbidden.clear()
	_limit_one.clear()
	_limit_two.clear()

	for idx in data.get("forbidden", []):
		_forbidden.append(int(idx))
	for idx in data.get("limit_one", []):
		_limit_one.append(int(idx))
	for idx in data.get("limit_two", []):
		_limit_two.append(int(idx))

	is_loaded = true
	banlist_name = data.get("name", "default")
	print("BanlistManager: 加载禁限表 '%s' (禁止%d, 限一%d, 限二%d)" % [banlist_name, _forbidden.size(), _limit_one.size(), _limit_two.size()])
	return true

## 加载默认禁限表
func load_default() -> bool:
	return load_banlist("res://data/banlists/default.json")

# ============================================================
# 查询
# ============================================================

## 获取卡牌的禁限状态
func get_ban_status(idx: int) -> BanStatus:
	if idx in _forbidden:
		return BanStatus.FORBIDDEN
	if idx in _limit_one:
		return BanStatus.LIMIT_ONE
	if idx in _limit_two:
		return BanStatus.LIMIT_TWO
	return BanStatus.FREE

## 是否为禁止卡
func is_forbidden(idx: int) -> bool:
	return idx in _forbidden

## 是否为限一卡
func is_limit_one(idx: int) -> bool:
	return idx in _limit_one

## 是否为限二卡
func is_limit_two(idx: int) -> bool:
	return idx in _limit_two

## 是否为禁限卡 (限一或限二)
func is_restricted(idx: int) -> bool:
	return is_limit_one(idx) or is_limit_two(idx)

## 获取某张卡在卡组中允许的最大数量
func get_max_allowed(idx: int) -> int:
	if is_forbidden(idx):
		return 0
	if is_limit_one(idx):
		return 1
	if is_limit_two(idx):
		return 2
	return 3  # 游戏王规则: 同名卡最多3张

## 获取禁限卡显示文本
func get_ban_status_text(idx: int) -> String:
	var status = get_ban_status(idx)
	if status == BanStatus.FORBIDDEN:
		return "禁止"
	if status == BanStatus.LIMIT_ONE:
		return "限1"
	if status == BanStatus.LIMIT_TWO:
		return "限2"
	return ""

## 获取全部禁止卡列表
func get_all_forbidden() -> Array:
	var cards: Array = []
	for idx in _forbidden:
		var card = CardDatabase.get_card(idx)
		if card != null:
			cards.append(card)
	return cards

## 获取全部限一卡列表
func get_all_limit_one() -> Array:
	var cards: Array = []
	for idx in _limit_one:
		var card = CardDatabase.get_card(idx)
		if card != null:
			cards.append(card)
	return cards

## 获取全部限二卡列表
func get_all_limit_two() -> Array:
	var cards: Array = []
	for idx in _limit_two:
		var card = CardDatabase.get_card(idx)
		if card != null:
			cards.append(card)
	return cards
