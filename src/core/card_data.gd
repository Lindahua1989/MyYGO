## CardData - 卡牌数据模型类
## 从card_database.json加载的单张卡牌数据
class_name CardData
extends RefCounted

# ============================================================
# 卡牌基础属性
# ============================================================

var idx: int = 0                   # 卡牌索引号 (0-based, 游戏内部ID)
var passcode: int = 0              # 8位密码/passcode
var passcode_txt: int = 0          # list_card.txt中的passcode
var game_id: int = 0               # card_id.bin中的游戏ID
var names: Dictionary = {}         # 多语言卡名 {"eng": "...", "jpn": "...", ...}
var descriptions: Dictionary = {}  # 多语言描述 {"eng": "...", "jpn": "...", ...}
var attack: int = 0                # ATK攻击力
var defense: int = 0               # DEF守备力
var star: int = 0                  # 星级 (1-12)
var attribute: String = ""         # 属性: light/dark/water/fire/earth/wind/divine
var race: String = ""              # 种族: dragon/warrior/fiend/... (null for spell/trap)
var card_type: String = ""         # 卡类型: monster_normal/monster_effect/spell_normal等
var art_file: String = ""          # 卡图文件名(无扩展名)
var pack_id: int = 0               # 卡包ID
var is_placeholder: bool = false   # 是否占位卡(idx 0)
var is_unstable: bool = false      # 是否不稳定卡(race_bits=0)
var raw_bytes: Array = []          # 原始4字节编码 [b0, b1, b2, b3]

# ============================================================
# 辅助方法 - 卡牌类型判断
# ============================================================

## 是否为怪兽卡
func is_monster() -> bool:
	return card_type.begins_with("monster")

## 是否为魔法卡
func is_spell() -> bool:
	return card_type.begins_with("spell")

## 是否为陷阱卡
func is_trap() -> bool:
	return card_type.begins_with("trap")

## 是否为通常怪兽
func is_normal_monster() -> bool:
	return card_type == "monster_normal"

## 是否为效果怪兽
func is_effect_monster() -> bool:
	return card_type == "monster_effect"

## 是否为融合怪兽
func is_fusion_monster() -> bool:
	return card_type == "monster_fusion"

## 是否为仪式怪兽
func is_ritual_monster() -> bool:
	return card_type == "monster_ritual"

## 获取怪兽子类型 (normal/effect/fusion/ritual/unstable)
func get_monster_subtype() -> String:
	if not is_monster():
		return ""
	if is_unstable:
		return "unstable"
	var parts = card_type.split("_")
	return parts[1] if parts.size() > 1 else ""

## 获取魔法子类型 (normal/field/equip/continuous/quick_play/ritual)
func get_spell_subtype() -> String:
	if not is_spell():
		return ""
	var parts = card_type.split("_")
	return parts[1] if parts.size() > 1 else ""

## 获取陷阱子类型 (normal/counter/continuous)
func get_trap_subtype() -> String:
	if not is_trap():
		return ""
	var parts = card_type.split("_")
	return parts[1] if parts.size() > 1 else ""

# ============================================================
# 辅助方法 - 显示信息
# ============================================================

## 获取指定语言的卡名 (默认英语)
func get_display_name(lang: String = "eng") -> String:
	return names.get(lang, names.get("eng", ""))

## 获取指定语言的描述 (默认英语)
func get_display_description(lang: String = "eng") -> String:
	return descriptions.get(lang, descriptions.get("eng", ""))

## 获取属性显示名 (中文)
func get_attribute_display_cn() -> String:
	var cn_map = {
		"light": "光", "dark": "暗", "water": "水",
		"fire": "炎", "earth": "地", "wind": "风", "divine": "神"
	}
	return cn_map.get(attribute, attribute)

## 获取种族显示名 (中文)
func get_race_display_cn() -> String:
	var cn_map = {
		"dragon": "龙族", "zombie": "不死族", "fiend": "恶魔族",
		"pyro": "炎族", "sea_serpent": "海龙族", "rock": "岩石族",
		"machine": "机械族", "fish": "鱼族", "dinosaur": "恐龙族",
		"insect": "昆虫族", "beast": "兽族", "beast_warrior": "兽战士族",
		"plant": "植物族", "aqua": "水族", "warrior": "战士族",
		"winged_beast": "鸟兽族", "fairy": "天使族", "spellcaster": "魔法使族",
		"thunder": "雷族", "reptile": "爬虫类族"
	}
	return cn_map.get(race, race)

## 获取卡类型显示名 (中文)
func get_card_type_display_cn() -> String:
	var cn_map = {
		"monster_normal": "通常怪兽", "monster_effect": "效果怪兽",
		"monster_fusion": "融合怪兽", "monster_ritual": "仪式怪兽",
		"monster_unstable_normal": "不稳定通常怪兽",
		"monster_unstable_effect": "不稳定效果怪兽",
		"monster_unstable_fusion": "不稳定融合怪兽",
		"monster_unstable_ritual": "不稳定仪式怪兽",
		"spell_normal": "通常魔法", "spell_field": "场地魔法",
		"spell_equip": "装备魔法", "spell_continuous": "永续魔法",
		"spell_quick_play": "速攻魔法", "spell_ritual": "仪式魔法",
		"trap_normal": "通常陷阱", "trap_counter": "反击陷阱",
		"trap_continuous": "永续陷阱"
	}
	return cn_map.get(card_type, card_type)

## 获取星级显示字符串 (★ x N)
func get_star_display() -> String:
	if not is_monster():
		return ""
	return "★" + str(star)

## 获取ATK/DEF显示字符串
func get_stats_display() -> String:
	if not is_monster():
		return ""
	return "ATK %d / DEF %d" % [attack, defense]

# ============================================================
# 数据加载 - 从JSON字典创建CardData
# ============================================================

## 从JSON字典初始化卡牌数据
func from_dict(data: Dictionary) -> void:
	idx = data.get("idx", 0)
	passcode = data.get("passcode", 0)
	passcode_txt = data.get("passcodeTxt", 0)
	game_id = data.get("gameId", 0)
	names = data.get("names", {})
	descriptions = data.get("descriptions", {})
	attack = data.get("attack", 0)
	defense = data.get("defense", 0)
	star = data.get("star", 0)
	attribute = data.get("attribute", "")
	race = data.get("race", "")
	card_type = data.get("cardType", "")
	art_file = data.get("artFile", "")
	pack_id = data.get("packId", 0)
	is_placeholder = data.get("isPlaceholder", false)
	is_unstable = data.get("isUnstable", false)
	raw_bytes = data.get("rawBytes", [])

## 创建CardData的静态工厂方法
static func create_from_dict(data: Dictionary) -> CardData:
	var card = CardData.new()
	card.from_dict(data)
	return card
