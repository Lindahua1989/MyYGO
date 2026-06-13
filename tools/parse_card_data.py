"""
MyYGO Card Data Parser - 解析游戏王混沌力量原版所有二进制卡牌数据

从 data/bin#/ 目录读取所有 .bin 文件，解析为结构化Python字典。
输出供 generate_card_db.py 使用来组装最终的 card_database.json。

编码参考: 混沌力量相关工具/卡牌编码研究日志.md (已验证)
"""

import struct
import os
import sys

# ============================================================
# 原版游戏目录路径（相对于MyYGO项目根目录）
# ============================================================
GAME_ROOT = os.path.join(os.path.dirname(__file__), '..', '..', 'Yu-Gi-Oh! Power of Chaos 20th Anniversary')
BIN_DIR = os.path.join(GAME_ROOT, 'data', 'bin#')
CARD_ART_DIR = os.path.join(GAME_ROOT, 'data', 'card')
MINI_ART_DIR = os.path.join(GAME_ROOT, 'data', 'mini')
LIST_CARD_TXT = os.path.join(CARD_ART_DIR, 'list_card.txt')

# ============================================================
# 编码映射表（已验证 + 描述推断）
# ============================================================

# 属性编码: byte3 bit5/6/7 三个独立位
# (bit5, bit6, bit7) -> 属性名
ATTRIBUTE_MAP = {
    (0, 0, 0): "light",   # 默认/光
    (1, 0, 0): "light",   # 光
    (0, 1, 0): "dark",    # 暗
    (1, 1, 0): "water",   # 水
    (0, 0, 1): "fire",    # 炎
    (1, 0, 1): "earth",   # 地
    (0, 1, 1): "wind",    # 风
    (1, 1, 1): "divine",  # 神(待验证)
}

# 属性中文名
ATTRIBUTE_CN = {
    "light": "光", "dark": "暗", "water": "水",
    "fire": "炎", "earth": "地", "wind": "风", "divine": "神"
}

# 主种族集 (byte3 bit0=0, byte2 bit4-7值)
PRIMARY_RACE_MAP = {
    1:  {"eng": "Dragon",      "jpn": "龙族"},
    2:  {"eng": "Zombie",      "jpn": "不死族"},
    3:  {"eng": "Fiend",       "jpn": "恶魔族"},
    4:  {"eng": "Pyro",        "jpn": "炎族"},
    5:  {"eng": "Sea Serpent", "jpn": "海龙族"},
    6:  {"eng": "Rock",        "jpn": "岩石族"},
    7:  {"eng": "Machine",     "jpn": "机械族"},
    8:  {"eng": "Fish",        "jpn": "鱼族"},
    9:  {"eng": "Dinosaur",    "jpn": "恐龙族"},
    10: {"eng": "Insect",      "jpn": "昆虫族"},
    11: {"eng": "Beast",       "jpn": "兽族"},
    12: {"eng": "Beast-Warrior","jpn": "兽战士族"},
    13: {"eng": "Plant",       "jpn": "植物族"},
    14: {"eng": "Aqua",        "jpn": "水族"},
    15: {"eng": "Warrior",     "jpn": "战士族"},
}

# 扩展种族集 (byte3 bit0=1, byte2 bit4-7值)
EXTENDED_RACE_MAP = {
    0: {"eng": "Winged Beast", "jpn": "鸟兽族"},
    1: {"eng": "Fairy",        "jpn": "天使族"},
    2: {"eng": "Spellcaster",  "jpn": "魔法使族"},
    3: {"eng": "Thunder",      "jpn": "雷族"},
    4: {"eng": "Reptile",      "jpn": "爬虫类族"},
}

# 怪兽卡类型 (byte2 bit2-3)
MONSTER_CATEGORY_MAP = {
    0: "normal",    # 通常怪兽
    1: "effect",    # 效果怪兽
    2: "fusion",    # 融合怪兽
    3: "ritual",    # 仪式怪兽
}

# 魔法卡子类型 (byte2 bit0-1 + bit2-3, byte3 bit0=1, byte2 bit4-7=6)
SPELL_SUBTYPE_MAP = {
    # (bit0-1, bit2-3) -> 子类型
    (0, 0): "normal",      # 通常魔法 0x60
    (0, 1): "field",       # 场地魔法 0x64
    (2, 1): "equip",       # 装备魔法 0x66
    (0, 2): "continuous",  # 永续魔法 0x68
    (2, 2): "quick_play",  # 速攻魔法 0x6a
    (0, 3): "ritual",      # 仪式魔法 0x6c
    (1, 3): "ritual",      # 仪式魔法 (ATK乘数不重要)
    (2, 3): "ritual",      # 仪式魔法
    (3, 3): "ritual",      # 仪式魔法
}

# 陷阱卡子类型 (byte2 bit0-1 + bit2-3, byte3 bit0=1, byte2 bit4-7=5)
TRAP_SUBTYPE_MAP = {
    (0, 0): "normal",      # 通常陷阱 0x50
    (2, 0): "counter",     # 反击陷阱 0x52
    (0, 2): "continuous",  # 永续陷阱 0x58
    (2, 2): "continuous",  # 永续陷阱(变体,理论上不存在)
}

# 卡类型中文名
CARD_TYPE_CN = {
    "monster_normal": "通常怪兽",
    "monster_effect": "效果怪兽",
    "monster_fusion": "融合怪兽",
    "monster_ritual": "仪式怪兽",
    "monster_unstable": "不稳定怪兽",
    "spell_normal": "通常魔法",
    "spell_field": "场地魔法",
    "spell_equip": "装备魔法",
    "spell_continuous": "永续魔法",
    "spell_quick_play": "速攻魔法",
    "spell_ritual": "仪式魔法",
    "trap_normal": "通常陷阱",
    "trap_counter": "反击陷阱",
    "trap_continuous": "永续陷阱",
}


# ============================================================
# 核心解析函数
# ============================================================

def parse_card_properties(raw_bytes):
    """解析card_prop.bin的4字节编码，返回卡牌属性字典"""
    b0, b1, b2, b3 = raw_bytes

    # DEF守备力
    defense = b0 * 10

    # ATK攻击力
    atk_mult = (b2 & 3)  # bit0-1: ATK乘数
    attack = b1 * 5 + atk_mult * 1280

    # 种族集选择 (byte3 bit0)
    race_set = b3 & 1

    # 种族/卡种类 (byte2 bit4-7)
    race_bits = (b2 >> 4) & 0xF

    # 卡类型分类 (byte2 bit2-3)
    category_bits = (b2 >> 2) & 3

    # 星级: (bit1-3 + bit4*8) mod 12, 特殊映射
    star_raw = ((b3 >> 1) & 7) + ((b3 >> 4) & 1) * 8
    if star_raw == 0:
        star = 11   # 特殊映射: 0 → 11星
    elif star_raw == 12:
        star = 12   # 特殊映射: 12 → 12星
    else:
        star = star_raw

    # 属性 (3位独立编码)
    attr_bits = ((b3 >> 5) & 1, (b3 >> 6) & 1, (b3 >> 7) & 1)
    attribute = ATTRIBUTE_MAP.get(attr_bits, "unknown")

    # 判断卡牌大类
    if race_bits == 5 and race_set == 1:
        card_kind = "trap"
    elif race_bits == 6 and race_set == 1:
        card_kind = "spell"
    elif race_bits == 0 and race_set == 0:
        card_kind = "unstable"  # 33张不稳定卡
    elif race_set == 0 and race_bits >= 1:
        card_kind = "monster_primary"
    elif race_set == 1 and race_bits <= 4:
        card_kind = "monster_extended"
    else:
        card_kind = "unknown"

    # 确定种族名称
    race = None
    race_info = None
    if card_kind.startswith("monster"):
        if race_set == 0:
            race_info = PRIMARY_RACE_MAP.get(race_bits)
        else:
            race_info = EXTENDED_RACE_MAP.get(race_bits)
        if race_info:
            race = race_info["eng"]
        else:
            race = f"unknown_r{race_bits}_s{race_set}"

    # 确定完整卡类型字符串
    if card_kind == "spell":
        subtype = SPELL_SUBTYPE_MAP.get((atk_mult, category_bits), "unknown")
        card_type = f"spell_{subtype}"
    elif card_kind == "trap":
        subtype = TRAP_SUBTYPE_MAP.get((atk_mult, category_bits), "unknown")
        card_type = f"trap_{subtype}"
    elif card_kind == "unstable":
        category = MONSTER_CATEGORY_MAP.get(category_bits, "unknown")
        card_type = f"monster_unstable_{category}"
    elif card_kind.startswith("monster"):
        category = MONSTER_CATEGORY_MAP.get(category_bits, "unknown")
        card_type = f"monster_{category}"
    else:
        card_type = "unknown"

    return {
        "attack": attack,
        "defense": defense,
        "star": star,
        "attribute": attribute,
        "race": race,
        "card_type": card_type,
        "race_set": race_set,
        "race_bits": race_bits,
        "category_bits": category_bits,
        "atk_multiplier_bits": atk_mult,
        "is_placeholder": (b0 == 0 and b1 == 0 and b2 == 0 and b3 == 0),
        "is_unstable": card_kind == "unstable",
        "raw_bytes": [b0, b1, b2, b3],
    }


def parse_fixed_length_names(filepath, record_size=64, encoding='ascii', total_records=None):
    """解析固定长度卡名文件 (64字节/卡)"""
    data = open(filepath, 'rb').read()
    if total_records is None:
        total_records = len(data) // record_size

    names = []
    for i in range(total_records):
        offset = i * record_size
        raw = data[offset:offset + record_size]
        if encoding == 'ascii':
            # 找到第一个null终止符
            null_pos = raw.find(0)
            if null_pos >= 0:
                name = raw[:null_pos].decode('ascii', errors='replace')
            else:
                name = raw.decode('ascii', errors='replace')
        elif encoding == 'gbk':
            null_pos = raw.find(0)
            if null_pos >= 0:
                name = raw[:null_pos].decode('gbk', errors='replace')
            else:
                name = raw.decode('gbk', errors='replace')
        else:
            null_pos = raw.find(0)
            if null_pos >= 0:
                name = raw[:null_pos].decode(encoding, errors='replace')
            else:
                name = raw.decode(encoding, errors='replace')
        names.append(name)

    return names


def parse_card_id(filepath, record_size=2, total_records=None):
    """解析card_id.bin (2字节/卡, 16位LE)"""
    data = open(filepath, 'rb').read()
    if total_records is None:
        total_records = len(data) // record_size

    ids = []
    for i in range(total_records):
        offset = i * record_size
        val = struct.unpack_from('<H', data, offset)[0]
        ids.append(val)
    return ids


def parse_card_pass(filepath, record_size=4, total_records=None):
    """解析card_pass.bin (4字节/卡, 32位LE passcode)"""
    data = open(filepath, 'rb').read()
    if total_records is None:
        total_records = len(data) // record_size

    passes = []
    for i in range(total_records):
        offset = i * record_size
        val = struct.unpack_from('<I', data, offset)[0]
        passes.append(val)
    return passes


def parse_card_pack(filepath, record_size=2, total_records=None):
    """解析card_pack.bin (2字节/卡, 16位LE pack ID)"""
    return parse_card_id(filepath, record_size, total_records)


def parse_descriptions(indx_filepath, desc_filepath, total_records=None):
    """
    解析卡牌描述文本。
    indx文件存储4字节LE偏移量数组, desc文件存储原始文本。
    每张卡的描述 = desc[offset[i]:offset[i+1]]
    """
    indx_data = open(indx_filepath, 'rb').read()
    desc_data = open(desc_filepath, 'rb').read()

    if total_records is None:
        total_records = len(indx_data) // 4

    # 读取偏移量数组
    offsets = []
    for i in range(total_records):
        off = struct.unpack_from('<I', indx_data, i * 4)[0]
        offsets.append(off)

    descriptions = []
    for i in range(total_records - 1):
        start = offsets[i]
        end = offsets[i + 1]
        if start < len(desc_data) and end <= len(desc_data) and end > start:
            desc = desc_data[start:end].decode('ascii', errors='replace').rstrip('\x00')
        else:
            desc = ""
        descriptions.append(desc)

    # 最后一张卡的描述需要特殊处理(到文件末尾)
    if total_records > 0:
        start = offsets[total_records - 1]
        if start < len(desc_data):
            desc = desc_data[start:].decode('ascii', errors='replace').rstrip('\x00')
        else:
            desc = ""
        descriptions.append(desc)

    return descriptions


def parse_sort_order(filepath, record_size=2, total_records=None):
    """解析排序索引文件 (2字节LE/条)"""
    data = open(filepath, 'rb').read()
    if total_records is None:
        total_records = len(data) // record_size

    order = []
    for i in range(total_records):
        offset = i * record_size
        val = struct.unpack_from('<H', data, offset)[0]
        order.append(val)
    return order


def parse_list_card_txt(filepath):
    """
    解析 list_card.txt 卡图映射文件。
    格式: // CardName\n// 000X:[passcode]\nBMP_FILENAME.bmp
    返回: [{idx, passcode, name, bmp_file}, ...]
    """
    entries = []
    lines = open(filepath, 'r', encoding='utf-8', errors='replace').readlines()

    i = 0
    while i < len(lines):
        # 寻找 "// CardName" 行
        if lines[i].startswith('//') and not lines[i].startswith('// 000'):
            name_line = lines[i].strip()
            name = name_line[2:].strip()  # 去掉 "// "

            # 下一行应该是 "// 000X:[passcode]"
            i += 1
            if i < len(lines) and lines[i].startswith('// 000'):
                idx_pass_line = lines[i].strip()
                # 解析 idx 和 passcode
                # 格式: "// 0001:[1504]"
                parts = idx_pass_line[2:].strip()  # "0001:[1504]"
                bracket_pos = parts.find(':[')
                if bracket_pos >= 0:
                    idx_str = parts[:bracket_pos]
                    passcode_str = parts[bracket_pos + 2:parts.find(']')]
                    try:
                        idx = int(idx_str)
                        passcode = int(passcode_str)
                    except ValueError:
                        idx = -1
                        passcode = 0
                else:
                    idx = -1
                    passcode = 0

                # 下一行应该是 BMP 文件名
                i += 1
                if i < len(lines) and not lines[i].startswith('//'):
                    bmp_file = lines[i].strip()
                    # 去掉 .bmp 扩展名，保留基础名
                    if bmp_file.endswith('.bmp'):
                        bmp_file = bmp_file[:-4]
                    entries.append({
                        "idx": idx,
                        "passcode_txt": passcode,
                        "name_txt": name,
                        "bmp_file": bmp_file,
                    })
            i += 1
        else:
            i += 1

    return entries


# ============================================================
# 主解析函数 — 解析所有bin文件并组装卡牌数据
# ============================================================

def parse_all_card_data(game_root=None):
    """
    解析所有卡牌二进制数据，返回完整的卡牌数据字典列表。
    """
    if game_root:
        bin_dir = os.path.join(game_root, 'data', 'bin#')
        card_art_dir = os.path.join(game_root, 'data', 'card')
    else:
        bin_dir = BIN_DIR
        card_art_dir = CARD_ART_DIR

    # 1. 解析 card_prop.bin (4字节/卡)
    prop_data = open(os.path.join(bin_dir, 'card_prop.bin'), 'rb').read()
    total_cards = len(prop_data) // 4
    print(f"card_prop.bin: {total_cards} 条记录 ({len(prop_data)} bytes)")

    cards = []
    for i in range(total_cards):
        offset = i * 4
        raw = prop_data[offset:offset + 4]
        props = parse_card_properties(raw)
        props["idx"] = i
        cards.append(props)

    # 2. 解析英文卡名 (64字节/卡, ASCII)
    eng_names = parse_fixed_length_names(
        os.path.join(bin_dir, 'card_nameeng.bin'), 64, 'ascii', total_cards)
    print(f"card_nameeng.bin: {len(eng_names)} 条记录")

    # 3. 解析中文卡名 (64字节/卡, GBK)
    jpn_names = parse_fixed_length_names(
        os.path.join(bin_dir, 'card_namejpn.bin'), 64, 'gbk', total_cards)
    print(f"card_namejpn.bin: {len(jpn_names)} 条记录")

    # 4. 解析其他语言卡名 (fra/ger/ita/spa)
    lang_names = {}
    for lang in ['fra', 'ger', 'ita', 'spa']:
        filepath = os.path.join(bin_dir, f'card_name{lang}.bin')
        if os.path.exists(filepath):
            # 其他语言可能有不同的记录数(不含idx 0)
            names = parse_fixed_length_names(filepath, 64, 'ascii')
            # 如果记录数少于total_cards，则idx 0为空
            if len(names) < total_cards:
                padded = [""] + names
                lang_names[lang] = padded[:total_cards]
            else:
                lang_names[lang] = names[:total_cards]
            print(f"card_name{lang}.bin: {len(lang_names[lang])} 条记录")

    # 5. 解析 card_id.bin (2字节/卡, 16位LE)
    game_ids = parse_card_id(os.path.join(bin_dir, 'card_id.bin'), 2, total_cards)
    print(f"card_id.bin: {len(game_ids)} 条记录")

    # 6. 解析 card_pass.bin (4字节/卡, 32位LE)
    passcodes = []
    pass_filepath = os.path.join(bin_dir, 'card_pass.bin')
    if os.path.exists(pass_filepath):
        pass_data = open(pass_filepath, 'rb').read()
        pass_total = len(pass_data) // 4
        for i in range(min(pass_total, total_cards)):
            offset = i * 4
            val = struct.unpack_from('<I', pass_data, offset)[0]
            passcodes.append(val)
        # 如果pass文件记录少于total_cards，用0填充
        while len(passcodes) < total_cards:
            passcodes.append(0)
        print(f"card_pass.bin: {pass_total} 条记录")

    # 7. 解析 card_pack.bin (2字节/卡, 16位LE)
    pack_ids = parse_card_pack(os.path.join(bin_dir, 'card_pack.bin'), 2, total_cards)
    print(f"card_pack.bin: {len(pack_ids)} 条记录")

    # 8. 解析英文描述 (indx+desc)
    eng_descs = []
    indx_path = os.path.join(bin_dir, 'card_indxeng.bin')
    desc_path = os.path.join(bin_dir, 'card_desceng.bin')
    if os.path.exists(indx_path) and os.path.exists(desc_path):
        eng_descs = parse_descriptions(indx_path, desc_path, total_cards)
        print(f"card_desceng.bin: {len(eng_descs)} 条描述")

    # 9. 解析中文描述 (indx+desc)
    jpn_descs = []
    indx_path = os.path.join(bin_dir, 'card_indxjpn.bin')
    desc_path = os.path.join(bin_dir, 'card_descjpn.bin')
    if os.path.exists(indx_path) and os.path.exists(desc_path):
        jpn_descs = parse_descriptions(indx_path, desc_path, total_cards)
        print(f"card_descjpn.bin: {len(jpn_descs)} 条描述")

    # 10. 解析其他语言描述
    lang_descs = {}
    for lang in ['fra', 'ger', 'ita', 'spa']:
        indx_path = os.path.join(bin_dir, f'card_indx{lang}.bin')
        desc_path = os.path.join(bin_dir, f'card_desc{lang}.bin')
        if os.path.exists(indx_path) and os.path.exists(desc_path):
            descs = parse_descriptions(indx_path, desc_path, total_cards)
            lang_descs[lang] = descs
            print(f"card_desc{lang}.bin: {len(descs)} 条描述")

    # 11. 解析排序索引
    sort_orders = {}
    for lang in ['eng', 'jpn', 'fra', 'ger', 'ita', 'spa']:
        sort_path = os.path.join(bin_dir, f'card_sort{lang}.bin')
        if os.path.exists(sort_path):
            sort_data = parse_sort_order(sort_path, 2)
            sort_orders[lang] = sort_data
            print(f"card_sort{lang}.bin: {len(sort_data)} 条排序索引")

    # 12. 解析 list_card.txt (卡图映射)
    art_mapping = {}
    list_txt_path = os.path.join(card_art_dir, 'list_card.txt')
    if os.path.exists(list_txt_path):
        art_entries = parse_list_card_txt(list_txt_path)
        for entry in art_entries:
            art_mapping[entry["idx"]] = entry
        print(f"list_card.txt: {len(art_entries)} 条卡图映射")

    # ============================================================
    # 组装最终卡牌数据
    # ============================================================
    result = []
    for i in range(total_cards):
        card = cards[i]  # 已有idx和属性

        # 添加卡名
        card["names"] = {"eng": eng_names[i] if i < len(eng_names) else ""}
        card["names"]["jpn"] = jpn_names[i] if i < len(jpn_names) else ""
        for lang in ['fra', 'ger', 'ita', 'spa']:
            if lang in lang_names and i < len(lang_names[lang]):
                card["names"][lang] = lang_names[lang][i]

        # 添加描述
        card["descriptions"] = {"eng": eng_descs[i] if i < len(eng_descs) else ""}
        card["descriptions"]["jpn"] = jpn_descs[i] if i < len(jpn_descs) else ""
        for lang in ['fra', 'ger', 'ita', 'spa']:
            if lang in lang_descs and i < len(lang_descs[lang]):
                card["descriptions"][lang] = lang_descs[lang][i]

        # 添加game_id
        card["game_id"] = game_ids[i] if i < len(game_ids) else 0

        # 添加passcode
        card["passcode"] = passcodes[i] if i < len(passcodes) else 0

        # 添加pack_id
        card["pack_id"] = pack_ids[i] if i < len(pack_ids) else 0

        # 添加卡图文件名
        if i in art_mapping:
            card["art_file"] = art_mapping[i]["bmp_file"]
            card["passcode_txt"] = art_mapping[i]["passcode_txt"]
            card["name_txt"] = art_mapping[i]["name_txt"]
        else:
            card["art_file"] = ""

        # 添加排序索引
        card["sort_order"] = {}
        for lang, sort_data in sort_orders.items():
            # 排序索引是外部数组，需要根据idx查找
            # sort数组存储的是排序位置，sort[idx] = 排序位置
            # 我们存储原始值
            card["sort_order"][lang] = 0  # 后续处理

        result.append(card)

    return result


# ============================================================
# 种族映射验证（使用英文描述中的"XX-Type"模式）
# ============================================================

RACE_PATTERN_MAP = {
    "Dragon-Type": "dragon",
    "Zombie-Type": "zombie",
    "Fiend-Type": "fiend",
    "Pyro-Type": "pyro",
    "Sea Serpent-Type": "sea_serpent",
    "Rock-Type": "rock",
    "Machine-Type": "machine",
    "Fish-Type": "fish",
    "Dinosaur-Type": "dinosaur",
    "Insect-Type": "insect",
    "Beast-Type": "beast",
    "Beast-Warrior-Type": "beast_warrior",
    "Plant-Type": "plant",
    "Aqua-Type": "aqua",
    "Warrior-Type": "warrior",
    "Winged Beast-Type": "winged_beast",
    "Fairy-Type": "fairy",
    "Spellcaster-Type": "spellcaster",
    "Thunder-Type": "thunder",
    "Reptile-Type": "reptile",
}


def verify_race_mapping(cards):
    """
    用英文描述中的 "XX-Type" 模式验证种族映射。
    返回验证报告字典。
    """
    report = {
        "verified": {},
        "discrepancies": [],
        "no_desc_monsters": [],
    }

    for card in cards:
        if card["is_placeholder"] or not card["card_type"].startswith("monster"):
            continue

        race_bits = card["race_bits"]
        race_set = card["race_set"]
        parsed_race = card["race"]

        # 在英文描述中搜索种族模式
        desc_eng = card["descriptions"].get("eng", "")
        detected_race = None
        for pattern, race_name in RACE_PATTERN_MAP.items():
            if pattern in desc_eng:
                detected_race = race_name
                break

        if detected_race:
            key = (race_set, race_bits)
            if key not in report["verified"]:
                report["verified"][key] = {
                    "parsed_race": parsed_race,
                    "detected_race": detected_race,
                    "sample_cards": [],
                }
            report["verified"][key]["sample_cards"].append(card["idx"])

            # 检查一致性
            if parsed_race != detected_race:
                report["discrepancies"].append({
                    "idx": card["idx"],
                    "name": card["names"]["eng"],
                    "parsed_race": parsed_race,
                    "detected_race": detected_race,
                    "race_bits": race_bits,
                    "race_set": race_set,
                })
        elif not card["is_unstable"]:
            # 没有种族描述的怪兽卡（通常怪兽可能没有种族描述）
            if parsed_race and race_bits > 0:
                report["no_desc_monsters"].append({
                    "idx": card["idx"],
                    "name": card["names"]["eng"],
                    "race": parsed_race,
                    "race_bits": race_bits,
                    "race_set": race_set,
                })

    return report


# ============================================================
# 统计报告
# ============================================================

def generate_statistics(cards):
    """生成卡牌分类统计"""
    stats = {
        "total": len(cards),
        "placeholder": 0,
        "real_cards": 0,
        "by_type": {},
        "by_attribute": {},
        "by_race": {},
        "by_star": {},
    }

    for card in cards:
        if card["is_placeholder"]:
            stats["placeholder"] += 1
            continue

        stats["real_cards"] += 1

        # 按类型统计
        ct = card["card_type"]
        stats["by_type"][ct] = stats["by_type"].get(ct, 0) + 1

        # 按属性统计
        attr = card["attribute"]
        stats["by_attribute"][attr] = stats["by_attribute"].get(attr, 0) + 1

        # 按种族统计（仅怪兽）
        if card["race"]:
            race = card["race"]
            stats["by_race"][race] = stats["by_race"].get(race, 0) + 1

        # 按星级统计（仅怪兽）
        if card["card_type"].startswith("monster"):
            star = card["star"]
            stats["by_star"][star] = stats["by_star"].get(star, 0) + 1

    return stats


# ============================================================
# 命令行入口
# ============================================================

if __name__ == "__main__":
    # 允许通过命令行指定原版游戏目录
    game_root = sys.argv[1] if len(sys.argv) > 1 else GAME_ROOT

    print(f"解析原版游戏数据: {game_root}")
    print(f"Bin目录: {os.path.join(game_root, 'data', 'bin#')}")
    print()

    cards = parse_all_card_data(game_root)
    stats = generate_statistics(cards)

    print()
    print("=" * 50)
    print("卡牌分类统计:")
    print("=" * 50)
    print(f"总记录数: {stats['total']}")
    print(f"占位卡(idx 0): {stats['placeholder']}")
    print(f"实际卡牌数: {stats['real_cards']}")
    print()

    print("按卡类型:")
    for ct, count in sorted(stats["by_type"].items()):
        cn = CARD_TYPE_CN.get(ct, ct)
        print(f"  {ct} ({cn}): {count}")
    print()

    print("按属性:")
    for attr, count in sorted(stats["by_attribute"].items()):
        cn = ATTRIBUTE_CN.get(attr, attr)
        print(f"  {attr} ({cn}): {count}")
    print()

    print("按种族:")
    for race, count in sorted(stats["by_race"].items()):
        print(f"  {race}: {count}")
    print()

    print("按星级:")
    for star, count in sorted(stats["by_star"].items()):
        print(f"  {star}星: {count}")
    print()

    # 种族映射验证
    print("=" * 50)
    print("种族映射验证 (使用英文描述 XX-Type 模式):")
    print("=" * 50)
    race_report = verify_race_mapping(cards)
    for key, info in sorted(race_report["verified"].items()):
        race_set, race_bits = key
        print(f"  race_set={race_set}, race_bits={race_bits}: parsed={info['parsed_race']}, detected={info['detected_race']}, count={len(info['sample_cards'])}")

    if race_report["discrepancies"]:
        print("\n⚠ 种族映射不一致:")
        for d in race_report["discrepancies"]:
            print(f"  idx={d['idx']} {d['name']}: parsed={d['parsed_race']} vs detected={d['detected_race']}")

    # 验证已知卡牌
    print()
    print("=" * 50)
    print("已知卡牌验证:")
    print("=" * 50)

    # idx=816: Blue-Eyes White Dragon
    bewd = cards[816]
    print(f"idx=816: {bewd['names']['eng']}")
    print(f"  ATK={bewd['attack']} (期望3000), DEF={bewd['defense']} (期望2500)")
    print(f"  Star={bewd['star']} (期望8), Attr={bewd['attribute']} (期望light)")
    print(f"  Race={bewd['race']} (期望dragon), Type={bewd['card_type']} (期望monster_normal)")
    bewd_ok = (bewd['attack'] == 3000 and bewd['defense'] == 2500 and
               bewd['star'] == 8 and bewd['attribute'] == 'light' and
               bewd['race'] == 'dragon' and bewd['card_type'] == 'monster_normal')
    print(f"  ✓ 验证结果: {'通过' if bewd_ok else '失败'}")

    # 反击陷阱验证
    print()
    counter_traps = [c for c in cards if c["card_type"] == "trap_counter"]
    print(f"反击陷阱数: {len(counter_traps)} (期望7)")
    for ct in counter_traps:
        print(f"  idx={ct['idx']} {ct['names']['eng']}: byte2=0x{ct['raw_bytes'][2]:02x} (期望0x52)")
