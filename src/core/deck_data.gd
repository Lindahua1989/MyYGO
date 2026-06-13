## DeckData - 卡组数据模型
## 表示一个完整的卡组（主卡组 + 额外卡组）
class_name DeckData
extends RefCounted

# ============================================================
# 卡组结构常量
# ============================================================

const MAIN_DECK_MIN: int = 40
const MAIN_DECK_MAX: int = 60
const EXTRA_DECK_MAX: int = 15
const SIDE_DECK_MAX: int = 15

# ============================================================
# 数据
# ============================================================

var deck_name: String = "新卡组"
var main_deck: Array[int] = []     # 主卡组 idx列表
var extra_deck: Array[int] = []    # 额外卡组 idx列表 (融合怪兽)
var side_deck: Array[int] = []     # 侧卡组 idx列表

# ============================================================
# 卡组操作
# ============================================================

## 向主卡组添加一张卡
func add_to_main(idx: int) -> bool:
	if main_deck.size() >= MAIN_DECK_MAX:
		return false
	main_deck.append(idx)
	return true

## 从主卡组移除一张卡 (第一个匹配的idx)
func remove_from_main(idx: int) -> bool:
	var pos = main_deck.find(idx)
	if pos == -1:
		return false
	main_deck.remove_at(pos)
	return true

## 向额外卡组添加一张卡 (仅融合怪兽)
func add_to_extra(idx: int) -> bool:
	if extra_deck.size() >= EXTRA_DECK_MAX:
		return false
	var card: CardData = CardDatabase.get_card(idx)
	if card == null or not card.is_fusion_monster():
		return false
	extra_deck.append(idx)
	return true

## 从额外卡组移除一张卡
func remove_from_extra(idx: int) -> bool:
	var pos = extra_deck.find(idx)
	if pos == -1:
		return false
	extra_deck.remove_at(pos)
	return true

## 获取某张卡在主卡组中的数量
func count_in_main(idx: int) -> int:
	var count: int = 0
	for card_idx in main_deck:
		if card_idx == idx:
			count += 1
	return count

## 获取某张卡在额外卡组中的数量
func count_in_extra(idx: int) -> int:
	var count: int = 0
	for card_idx in extra_deck:
		if card_idx == idx:
			count += 1
	return count

## 获取某张卡在卡组中的总数量 (主+额外)
func count_total(idx: int) -> int:
	return count_in_main(idx) + count_in_extra(idx)

# ============================================================
# 验证
# ============================================================

## 主卡组数量是否合法
func is_main_deck_size_valid() -> bool:
	return main_deck.size() >= MAIN_DECK_MIN and main_deck.size() <= MAIN_DECK_MAX

## 验证禁限卡合规
func validate_banlist(banlist: BanlistManager) -> Array:
	var errors: Array = []
	for idx in main_deck:
		var count = count_in_main(idx)
		if banlist.is_forbidden(idx):
			errors.append("禁止卡: %s (idx=%d)" % [CardDatabase.get_card(idx).get_display_name(), idx])
		elif banlist.is_limit_one(idx) and count > 1:
			errors.append("限一卡超过1张: %s x%d (idx=%d)" % [CardDatabase.get_card(idx).get_display_name(), count, idx])
		elif banlist.is_limit_two(idx) and count > 2:
			errors.append("限二卡超过2张: %s x%d (idx=%d)" % [CardDatabase.get_card(idx).get_display_name(), count, idx])
	for idx in extra_deck:
		if banlist.is_forbidden(idx):
			errors.append("禁止卡(额外): %s (idx=%d)" % [CardDatabase.get_card(idx).get_display_name(), idx])
	return errors

## 完整合法性检查
func is_valid(banlist: BanlistManager) -> bool:
	if not is_main_deck_size_valid():
		return false
	if validate_banlist(banlist).size() > 0:
		return false
	return true

# ============================================================
# 统计信息
# ============================================================

## 获取卡组统计
func get_statistics() -> Dictionary:
	var stats: Dictionary = {
		"total_main": main_deck.size(),
		"total_extra": extra_deck.size(),
		"monsters": 0,
		"spells": 0,
		"traps": 0,
		"by_attribute": {},
		"by_race": {},
		"by_star": {},
		"avg_atk": 0,
		"avg_def": 0,
	}

	var total_atk: int = 0
	var total_def: int = 0
	var monster_count: int = 0

	for idx in main_deck:
		var card: CardData = CardDatabase.get_card(idx)
		if card == null:
			continue

		if card.is_monster():
			stats["monsters"] += 1
			monster_count += 1
			total_atk += card.attack
			total_def += card.defense
			stats["by_attribute"][card.attribute] = stats["by_attribute"].get(card.attribute, 0) + 1
			if card.race != "":
				stats["by_race"][card.race] = stats["by_race"].get(card.race, 0) + 1
			stats["by_star"][card.star] = stats["by_star"].get(card.star, 0) + 1
		elif card.is_spell():
			stats["spells"] += 1
		elif card.is_trap():
			stats["traps"] += 1

	if monster_count > 0:
		stats["avg_atk"] = total_atk / monster_count
		stats["avg_def"] = total_def / monster_count

	return stats

# ============================================================
# 序列化
# ============================================================

## 从字典加载
func from_dict(data: Dictionary) -> void:
	deck_name = data.get("name", "新卡组")
	main_deck.clear()
	extra_deck.clear()
	side_deck.clear()
	for idx in data.get("main_deck", []):
		main_deck.append(int(idx))
	for idx in data.get("extra_deck", []):
		extra_deck.append(int(idx))
	for idx in data.get("side_deck", []):
		side_deck.append(int(idx))

## 序列化为字典
func to_dict() -> Dictionary:
	return {
		"name": deck_name,
		"main_deck": main_deck,
		"extra_deck": extra_deck,
		"side_deck": side_deck,
	}

## 保存卡组到文件
func save_to_file(filepath: String) -> bool:
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		return false
	var json_string = JSON.stringify(to_dict(), "\t")
	file.store_string(json_string)
	file.close()
	return true

## 从文件加载卡组
static func load_from_file(filepath: String) -> DeckData:
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return null
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		return null

	var deck = DeckData.new()
	deck.from_dict(json.data)
	return deck
