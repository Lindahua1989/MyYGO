/**
 * MyYGO Card Data Parser - 解析游戏王混沌力量原版所有二进制卡牌数据
 *
 * 从 data/bin#/ 目录读取所有 .bin 文件，解析为结构化数据。
 * 输出供 generate_card_db.js 使用来组装最终的 card_database.json。
 *
 * 编码参考: 混沌力量相关工具/卡牌编码研究日志.md (已验证)
 */

const fs = require('fs');
const path = require('path');

// ============================================================
// 路径配置
// ============================================================
const GAME_ROOT = path.resolve(__dirname, '..', '..', '..', 'Yu-Gi-Oh! Power of Chaos 20th Anniversary');
const BIN_DIR = path.join(GAME_ROOT, 'data', 'bin#');
const CARD_ART_DIR = path.join(GAME_ROOT, 'data', 'card');
const MINI_ART_DIR = path.join(GAME_ROOT, 'data', 'mini');
const LIST_CARD_TXT = path.join(CARD_ART_DIR, 'list_card.txt');

// ============================================================
// 编码映射表
// ============================================================

// 属性编码: byte3 bit5/6/7 三个独立位
const ATTRIBUTE_MAP = {
  '000': 'light',   // 默认/光
  '100': 'light',   // 光
  '010': 'dark',    // 暗
  '110': 'water',   // 水
  '001': 'fire',    // 炎
  '101': 'earth',   // 地
  '011': 'wind',    // 风
  '111': 'divine',  // 神(待验证)
};

const ATTRIBUTE_CN = {
  light: '光', dark: '暗', water: '水',
  fire: '炎', earth: '地', wind: '风', divine: '神'
};

// 主种族集 (byte3 bit0=0, byte2 bit4-7值) - 统一使用小写英文
const PRIMARY_RACE_MAP = {
  1:  { eng: 'dragon',      jpn: '龙族', display: 'Dragon' },
  2:  { eng: 'zombie',      jpn: '不死族', display: 'Zombie' },
  3:  { eng: 'fiend',       jpn: '恶魔族', display: 'Fiend' },
  4:  { eng: 'pyro',        jpn: '炎族', display: 'Pyro' },
  5:  { eng: 'sea_serpent', jpn: '海龙族', display: 'Sea Serpent' },
  6:  { eng: 'rock',        jpn: '岩石族', display: 'Rock' },
  7:  { eng: 'machine',     jpn: '机械族', display: 'Machine' },
  8:  { eng: 'fish',        jpn: '鱼族', display: 'Fish' },
  9:  { eng: 'dinosaur',    jpn: '恐龙族', display: 'Dinosaur' },
  10: { eng: 'insect',      jpn: '昆虫族', display: 'Insect' },
  11: { eng: 'beast',       jpn: '兽族', display: 'Beast' },
  12: { eng: 'beast_warrior', jpn: '兽战士族', display: 'Beast-Warrior' },
  13: { eng: 'plant',       jpn: '植物族', display: 'Plant' },
  14: { eng: 'aqua',        jpn: '水族', display: 'Aqua' },
  15: { eng: 'warrior',     jpn: '战士族', display: 'Warrior' },
};

// 扩展种族集 (byte3 bit0=1, byte2 bit4-7值) - 统一使用小写英文
const EXTENDED_RACE_MAP = {
  0: { eng: 'winged_beast', jpn: '鸟兽族', display: 'Winged Beast' },
  1: { eng: 'fairy',        jpn: '天使族', display: 'Fairy' },
  2: { eng: 'spellcaster',  jpn: '魔法使族', display: 'Spellcaster' },
  3: { eng: 'thunder',      jpn: '雷族', display: 'Thunder' },
  4: { eng: 'reptile',      jpn: '爬虫类族', display: 'Reptile' },
};

// 怪兽卡类型 (byte2 bit2-3)
const MONSTER_CATEGORY_MAP = {
  0: 'normal',    // 通常怪兽
  1: 'effect',    // 效果怪兽
  2: 'fusion',    // 融合怪兽
  3: 'ritual',    // 仪式怪兽
};

// 魔法卡子类型 (byte2 bit0-1 + bit2-3)
const SPELL_SUBTYPE_MAP = {
  '0_0': 'normal',       // 通常魔法 0x60
  '0_1': 'field',        // 场地魔法 0x64
  '2_1': 'equip',        // 装备魔法 0x66
  '0_2': 'continuous',   // 永续魔法 0x68
  '2_2': 'quick_play',   // 速攻魔法 0x6a
  '0_3': 'ritual',       // 仪式魔法 0x6c
  '1_3': 'ritual',       // 仪式魔法
  '2_3': 'ritual',       // 仪式魔法
  '3_3': 'ritual',       // 仪式魔法
};

// 陷阱卡子类型 (byte2 bit0-1 + bit2-3)
const TRAP_SUBTYPE_MAP = {
  '0_0': 'normal',       // 通常陷阱 0x50
  '2_0': 'counter',      // 反击陷阱 0x52
  '0_2': 'continuous',   // 永续陷阱 0x58
  '2_2': 'continuous',   // 永续陷阱(变体)
};

const CARD_TYPE_CN = {
  monster_normal: '通常怪兽',
  monster_effect: '效果怪兽',
  monster_fusion: '融合怪兽',
  monster_ritual: '仪式怪兽',
  monster_unstable_normal: '不稳定通常怪兽',
  monster_unstable_effect: '不稳定效果怪兽',
  monster_unstable_fusion: '不稳定融合怪兽',
  monster_unstable_ritual: '不稳定仪式怪兽',
  spell_normal: '通常魔法',
  spell_field: '场地魔法',
  spell_equip: '装备魔法',
  spell_continuous: '永续魔法',
  spell_quick_play: '速攻魔法',
  spell_ritual: '仪式魔法',
  trap_normal: '通常陷阱',
  trap_counter: '反击陷阱',
  trap_continuous: '永续陷阱',
};

// ============================================================
// 核心解析函数
// ============================================================

/**
 * 解析card_prop.bin的4字节编码，返回卡牌属性
 */
function parseCardProperties(b0, b1, b2, b3) {
  // DEF守备力
  const defense = b0 * 10;

  // ATK攻击力
  const atkMult = (b2 & 3);  // bit0-1: ATK乘数
  const attack = b1 * 5 + atkMult * 1280;

  // 种族集选择 (byte3 bit0)
  const raceSet = b3 & 1;

  // 种族/卡种类 (byte2 bit4-7)
  const raceBits = (b2 >> 4) & 0xF;

  // 卡类型分类 (byte2 bit2-3)
  const categoryBits = (b2 >> 2) & 3;

  // 星级
  const starRaw = ((b3 >> 1) & 7) + ((b3 >> 4) & 1) * 8;
  let star;
  if (starRaw === 0) star = 11;     // 特殊映射: 0 → 11星
  else if (starRaw === 12) star = 12; // 特殊映射: 12 → 12星
  else star = starRaw;

  // 属性 (3位独立编码)
  const attrBits = `${(b3 >> 5) & 1}${(b3 >> 6) & 1}${(b3 >> 7) & 1}`;
  const attribute = ATTRIBUTE_MAP[attrBits] || 'unknown';

  // 判断卡牌大类
  let cardKind;
  if (raceBits === 5 && raceSet === 1) {
    cardKind = 'trap';
  } else if (raceBits === 6 && raceSet === 1) {
    cardKind = 'spell';
  } else if (raceBits === 0 && raceSet === 0) {
    cardKind = 'unstable';
  } else if (raceSet === 0 && raceBits >= 1) {
    cardKind = 'monster_primary';
  } else if (raceSet === 1 && raceBits <= 4) {
    cardKind = 'monster_extended';
  } else {
    cardKind = 'unknown';
  }

  // 确定种族名称
  let race = null;
  if (cardKind.startsWith('monster')) {
    const raceInfo = raceSet === 0
      ? PRIMARY_RACE_MAP[raceBits]
      : EXTENDED_RACE_MAP[raceBits];
    race = raceInfo ? raceInfo.eng : `unknown_r${raceBits}_s${raceSet}`;
  }

  // 确定完整卡类型字符串
  let cardType;
  if (cardKind === 'spell') {
    const subtype = SPELL_SUBTYPE_MAP[`${atkMult}_${categoryBits}`] || 'unknown';
    cardType = `spell_${subtype}`;
  } else if (cardKind === 'trap') {
    const subtype = TRAP_SUBTYPE_MAP[`${atkMult}_${categoryBits}`] || 'unknown';
    cardType = `trap_${subtype}`;
  } else if (cardKind === 'unstable') {
    const category = MONSTER_CATEGORY_MAP[categoryBits] || 'unknown';
    cardType = `monster_unstable_${category}`;
  } else if (cardKind.startsWith('monster')) {
    const category = MONSTER_CATEGORY_MAP[categoryBits] || 'unknown';
    cardType = `monster_${category}`;
  } else {
    cardType = 'unknown';
  }

  const isPlaceholder = (b0 === 0 && b1 === 0 && b2 === 0 && b3 === 0);

  return {
    attack, defense, star, attribute, race, cardType,
    raceSet, raceBits, categoryBits, atkMult,
    isPlaceholder,
    isUnstable: cardKind === 'unstable',
    rawBytes: [b0, b1, b2, b3],
  };
}

/**
 * 解析固定长度卡名文件 (64字节/卡)
 * encoding: 'ascii' 或 'gbk'
 */
function parseFixedLengthNames(filepath, recordSize = 64, encoding = 'ascii') {
  const data = fs.readFileSync(filepath);
  const total = data.length / recordSize;
  const names = [];

  for (let i = 0; i < total; i++) {
    const offset = i * recordSize;
    const raw = data.subarray(offset, offset + recordSize);

    // 找到第一个null终止符
    let nullPos = 0;
    while (nullPos < raw.length && raw[nullPos] !== 0) nullPos++;

    const nameBytes = raw.subarray(0, nullPos);

    if (encoding === 'gbk') {
      // GBK解码: 使用TextDecoder (Node.js v24支持)
      try {
        const decoder = new TextDecoder('gbk');
        const name = decoder.decode(nameBytes);
        names.push(name);
      } catch {
        // fallback: 手动GBK解码或跳过
        names.push(nameBytes.toString('ascii'));
      }
    } else {
      names.push(nameBytes.toString('ascii'));
    }
  }

  return names;
}

/**
 * 解析card_id.bin (2字节/卡, 16位LE)
 */
function parseUint16LE(filepath, recordSize = 2) {
  const data = fs.readFileSync(filepath);
  const total = data.length / recordSize;
  const values = [];

  for (let i = 0; i < total; i++) {
    values.push(data.readUInt16LE(i * recordSize));
  }

  return values;
}

/**
 * 解析card_pass.bin (4字节/卡, 32位LE passcode)
 */
function parseUint32LE(filepath, recordSize = 4) {
  const data = fs.readFileSync(filepath);
  const total = data.length / recordSize;
  const values = [];

  for (let i = 0; i < total; i++) {
    values.push(data.readUInt32LE(i * recordSize));
  }

  return values;
}

/**
 * 解析卡牌描述文本 (indx+desc)
 */
function parseDescriptions(indxPath, descPath, expectedRecords) {
  const indxData = fs.readFileSync(indxPath);
  const descData = fs.readFileSync(descPath);

  const indxCount = indxData.length / 4;
  const useCount = expectedRecords || indxCount;

  // 读取偏移量数组
  const offsets = [];
  for (let i = 0; i < useCount + 1; i++) {
    if (i * 4 < indxData.length) {
      offsets.push(indxData.readUInt32LE(i * 4));
    }
  }

  const descriptions = [];
  for (let i = 0; i < useCount; i++) {
    const start = offsets[i];
    const end = (i + 1 < offsets.length) ? offsets[i + 1] : descData.length;

    if (start !== undefined && end !== undefined && start < descData.length && end <= descData.length && end > start) {
      const desc = descData.subarray(start, end).toString('ascii').replace(/\x00/g, '');
      descriptions.push(desc);
    } else {
      descriptions.push('');
    }
  }

  return descriptions;
}

/**
 * 解析 list_card.txt 卡图映射文件
 */
function parseListCardTxt(filepath) {
  const content = fs.readFileSync(filepath, 'utf-8');
  const lines = content.split('\n');
  const entries = [];

  let i = 0;
  while (i < lines.length) {
    // 寻找 "// CardName" 行 (不以 // 000开头)
    const line = lines[i].trim();
    if (line.startsWith('//') && !line.match(/^\/\/\s*0\d\d\d/)) {
      const name = line.substring(2).trim();

      // 下一行: "// 000X:[passcode]"
      i++;
      if (i < lines.length) {
        const idxPassLine = lines[i].trim();
        const match = idxPassLine.match(/^\/\/\s*(\d+):\[(\d+)\]/);
        if (match) {
          const idx = parseInt(match[1]);
          const passcode = parseInt(match[2]);

          // 下一行: BMP文件名
          i++;
          if (i < lines.length) {
            const bmpLine = lines[i].trim();
            let bmpFile = bmpLine;
            if (bmpFile.endsWith('.bmp')) {
              bmpFile = bmpFile.substring(0, bmpFile.length - 4);
            }

            entries.push({
              idx, passcodeTxt: passcode, nameTxt: name, bmpFile,
            });
          }
        }
      }
    }
    i++;
  }

  return entries;
}

// ============================================================
// 种族描述模式检测
// ============================================================

const RACE_PATTERNS = {
  'Dragon-Type': 'dragon',
  'Zombie-Type': 'zombie',
  'Fiend-Type': 'fiend',
  'Pyro-Type': 'pyro',
  'Sea Serpent-Type': 'sea_serpent',
  'Rock-Type': 'rock',
  'Machine-Type': 'machine',
  'Fish-Type': 'fish',
  'Dinosaur-Type': 'dinosaur',
  'Insect-Type': 'insect',
  'Beast-Warrior-Type': 'beast_warrior',
  'Beast-Type': 'beast',
  'Plant-Type': 'plant',
  'Aqua-Type': 'aqua',
  'Warrior-Type': 'warrior',
  'Winged Beast-Type': 'winged_beast',
  'Fairy-Type': 'fairy',
  'Spellcaster-Type': 'spellcaster',
  'Thunder-Type': 'thunder',
  'Reptile-Type': 'reptile',
};

function detectRaceFromDescription(descEng) {
  // 先检查长的模式(如Beast-Warrior-Type)避免被Beast-Type误匹配
  const patterns = Object.entries(RACE_PATTERNS)
    .sort((a, b) => b[0].length - a[0].length);  // 按长度降序

  for (const [pattern, race] of patterns) {
    if (descEng.includes(pattern)) return race;
  }
  return null;
}

// ============================================================
// 主解析 — 组装所有数据
// ============================================================

function parseAllCardData(gameRoot) {
  const binDir = path.join(gameRoot, 'data', 'bin#');
  const cardArtDir = path.join(gameRoot, 'data', 'card');

  // 1. 解析 card_prop.bin (4字节/卡)
  const propData = fs.readFileSync(path.join(binDir, 'card_prop.bin'));
  const totalCards = propData.length / 4;
  console.log(`card_prop.bin: ${totalCards} 条记录 (${propData.length} bytes)`);

  const cards = [];
  for (let i = 0; i < totalCards; i++) {
    const b0 = propData[i * 4];
    const b1 = propData[i * 4 + 1];
    const b2 = propData[i * 4 + 2];
    const b3 = propData[i * 4 + 3];

    const props = parseCardProperties(b0, b1, b2, b3);
    props.idx = i;
    cards.push(props);
  }

  // 2. 英文卡名
  const engNames = parseFixedLengthNames(path.join(binDir, 'card_nameeng.bin'), 64, 'ascii');
  console.log(`card_nameeng.bin: ${engNames.length} 条记录`);

  // 3. 中文卡名 (GBK)
  const jpnNames = parseFixedLengthNames(path.join(binDir, 'card_namejpn.bin'), 64, 'gbk');
  console.log(`card_namejpn.bin: ${jpnNames.length} 条记录`);

  // 4. 其他语言卡名
  const langNames = {};
  for (const lang of ['fra', 'ger', 'ita', 'spa']) {
    const filepath = path.join(binDir, `card_name${lang}.bin`);
    if (fs.existsSync(filepath)) {
      const names = parseFixedLengthNames(filepath, 64, 'ascii');
      // 如果记录数少于totalCards，补一个空字符串作为idx 0
      if (names.length < totalCards) {
        langNames[lang] = [''].concat(names).slice(0, totalCards);
      } else {
        langNames[lang] = names.slice(0, totalCards);
      }
      console.log(`card_name${lang}.bin: ${langNames[lang].length} 条记录`);
    }
  }

  // 5. card_id.bin
  const gameIds = parseUint16LE(path.join(binDir, 'card_id.bin'), 2);
  console.log(`card_id.bin: ${gameIds.length} 条记录`);

  // 6. card_pass.bin
  let passcodes = [];
  const passPath = path.join(binDir, 'card_pass.bin');
  if (fs.existsSync(passPath)) {
    passcodes = parseUint32LE(passPath, 4);
    // 补齐到totalCards
    while (passcodes.length < totalCards) passcodes.push(0);
    console.log(`card_pass.bin: ${passcodes.length} 条记录`);
  }

  // 7. card_pack.bin
  const packIds = parseUint16LE(path.join(binDir, 'card_pack.bin'), 2);
  console.log(`card_pack.bin: ${packIds.length} 条记录`);

  // 8. 英文描述
  let engDescs = [];
  const engIndx = path.join(binDir, 'card_indxeng.bin');
  const engDesc = path.join(binDir, 'card_desceng.bin');
  if (fs.existsSync(engIndx) && fs.existsSync(engDesc)) {
    engDescs = parseDescriptions(engIndx, engDesc, totalCards);
    console.log(`card_desceng.bin: ${engDescs.length} 条描述`);
  }

  // 9. 中文描述
  let jpnDescs = [];
  const jpnIndx = path.join(binDir, 'card_indxjpn.bin');
  const jpnDesc = path.join(binDir, 'card_descjpn.bin');
  if (fs.existsSync(jpnIndx) && fs.existsSync(jpnDesc)) {
    jpnDescs = parseDescriptions(jpnIndx, jpnDesc, totalCards);
    console.log(`card_descjpn.bin: ${jpnDescs.length} 条描述`);
  }

  // 10. 其他语言描述
  const langDescs = {};
  for (const lang of ['fra', 'ger', 'ita', 'spa']) {
    const indxPath = path.join(binDir, `card_indx${lang}.bin`);
    const descPath = path.join(binDir, `card_desc${lang}.bin`);
    if (fs.existsSync(indxPath) && fs.existsSync(descPath)) {
      const descs = parseDescriptions(indxPath, descPath, totalCards);
      langDescs[lang] = descs;
      console.log(`card_desc${lang}.bin: ${descs.length} 条描述`);
    }
  }

  // 11. 排序索引
  const sortOrders = {};
  for (const lang of ['eng', 'jpn', 'fra', 'ger', 'ita', 'spa']) {
    const sortPath = path.join(binDir, `card_sort${lang}.bin`);
    if (fs.existsSync(sortPath)) {
      sortOrders[lang] = parseUint16LE(sortPath, 2);
      console.log(`card_sort${lang}.bin: ${sortOrders[lang].length} 条排序索引`);
    }
  }

  // 12. 卡图映射 (list_card.txt)
  const artMapping = {};
  const listTxtPath = path.join(cardArtDir, 'list_card.txt');
  if (fs.existsSync(listTxtPath)) {
    const artEntries = parseListCardTxt(listTxtPath);
    for (const entry of artEntries) {
      artMapping[entry.idx] = entry;
    }
    console.log(`list_card.txt: ${artEntries.length} 条卡图映射`);
  }

  // ============================================================
  // 组装最终卡牌数据
  // ============================================================
  for (let i = 0; i < totalCards; i++) {
    const card = cards[i];

    // 卡名
    card.names = {
      eng: engNames[i] || '',
      jpn: jpnNames[i] || '',
    };
    for (const lang of ['fra', 'ger', 'ita', 'spa']) {
      if (langNames[lang] && i < langNames[lang].length) {
        card.names[lang] = langNames[lang][i];
      }
    }

    // 描述
    card.descriptions = {
      eng: engDescs[i] || '',
      jpn: jpnDescs[i] || '',
    };
    for (const lang of ['fra', 'ger', 'ita', 'spa']) {
      if (langDescs[lang] && i < langDescs[lang].length) {
        card.descriptions[lang] = langDescs[lang][i];
      }
    }

    // game_id, passcode, pack_id
    card.gameId = gameIds[i] || 0;
    card.passcode = passcodes[i] || 0;
    card.packId = packIds[i] || 0;

    // 卡图文件名
    if (artMapping[i]) {
      card.artFile = artMapping[i].bmpFile;
      card.passcodeTxt = artMapping[i].passcodeTxt;
      card.nameTxt = artMapping[i].nameTxt;
    } else {
      card.artFile = '';
    }
  }

  return cards;
}

// ============================================================
// 种族映射验证
// ============================================================

function verifyRaceMapping(cards) {
  const report = { verified: {}, discrepancies: [], noDesc: [] };

  for (const card of cards) {
    if (card.isPlaceholder || !card.cardType.startsWith('monster')) continue;

    const key = `${card.raceSet}_${card.raceBits}`;
    const parsedRace = card.race;
    const descEng = card.descriptions.eng || '';
    const detectedRace = detectRaceFromDescription(descEng);

    if (detectedRace) {
      if (!report.verified[key]) {
        report.verified[key] = {
          parsedRace, detectedRace, count: 0, samples: [],
        };
      }
      report.verified[key].count++;
      if (report.verified[key].samples.length < 3) {
        report.verified[key].samples.push(`${card.idx}:${card.names.eng}`);
      }

      if (parsedRace !== detectedRace) {
        report.discrepancies.push({
          idx: card.idx, name: card.names.eng,
          parsedRace, detectedRace,
          raceBits: card.raceBits, raceSet: card.raceSet,
        });
      }
    } else if (!card.isUnstable && card.race) {
      report.noDesc.push({
        idx: card.idx, name: card.names.eng,
        race: parsedRace, raceBits: card.raceBits, raceSet: card.raceSet,
      });
    }
  }

  return report;
}

// ============================================================
// 统计
// ============================================================

function generateStatistics(cards) {
  const stats = {
    total: cards.length,
    placeholder: 0,
    realCards: 0,
    byType: {},
    byAttribute: {},
    byRace: {},
    byStar: {},
  };

  for (const card of cards) {
    if (card.isPlaceholder) { stats.placeholder++; continue; }
    stats.realCards++;

    stats.byType[card.cardType] = (stats.byType[card.cardType] || 0) + 1;
    stats.byAttribute[card.attribute] = (stats.byAttribute[card.attribute] || 0) + 1;

    if (card.race) {
      stats.byRace[card.race] = (stats.byRace[card.race] || 0) + 1;
    }

    if (card.cardType.startsWith('monster')) {
      stats.byStar[card.star] = (stats.byStar[card.star] || 0) + 1;
    }
  }

  return stats;
}

// ============================================================
// 命令行入口
// ============================================================

function main() {
  const gameRoot = process.argv[2] || GAME_ROOT;

  console.log(`解析原版游戏数据: ${gameRoot}`);
  console.log(`Bin目录: ${path.join(gameRoot, 'data', 'bin#')}`);
  console.log();

  const cards = parseAllCardData(gameRoot);
  const stats = generateStatistics(cards);

  console.log();
  console.log('=' .repeat(50));
  console.log('卡牌分类统计:');
  console.log('=' .repeat(50));
  console.log(`总记录数: ${stats.total}`);
  console.log(`占位卡(idx 0): ${stats.placeholder}`);
  console.log(`实际卡牌数: ${stats.realCards}`);
  console.log();

  console.log('按卡类型:');
  for (const [ct, count] of Object.entries(stats.byType).sort()) {
    const cn = CARD_TYPE_CN[ct] || ct;
    console.log(`  ${ct} (${cn}): ${count}`);
  }
  console.log();

  console.log('按属性:');
  for (const [attr, count] of Object.entries(stats.byAttribute).sort()) {
    const cn = ATTRIBUTE_CN[attr] || attr;
    console.log(`  ${attr} (${cn}): ${count}`);
  }
  console.log();

  console.log('按种族:');
  for (const [race, count] of Object.entries(stats.byRace).sort()) {
    console.log(`  ${race}: ${count}`);
  }
  console.log();

  console.log('按星级:');
  for (const [star, count] of Object.entries(stats.byStar).sort((a,b) => a[0]-b[0])) {
    console.log(`  ${star}星: ${count}`);
  }
  console.log();

  // 种族映射验证
  console.log('=' .repeat(50));
  console.log('种族映射验证 (描述XX-Type模式):');
  console.log('=' .repeat(50));
  const raceReport = verifyRaceMapping(cards);
  for (const [key, info] of Object.entries(raceReport.verified).sort()) {
    console.log(`  ${key}: parsed=${info.parsedRace}, detected=${info.detectedRace}, count=${info.count}`);
  }

  if (raceReport.discrepancies.length > 0) {
    console.log('\n⚠ 种族映射不一致:');
    for (const d of raceReport.discrepancies) {
      console.log(`  idx=${d.idx} ${d.name}: parsed=${d.parsedRace} vs detected=${d.detectedRace}`);
    }
  }

  // 验证已知卡牌
  console.log();
  console.log('=' .repeat(50));
  console.log('已知卡牌验证:');
  console.log('=' .repeat(50));

  // Blue-Eyes White Dragon (idx 816)
  const bewd = cards[816];
  console.log(`idx=816: ${bewd.names.eng}`);
  console.log(`  ATK=${bewd.attack} (期望3000), DEF=${bewd.defense} (期望2500)`);
  console.log(`  Star=${bewd.star} (期望8), Attr=${bewd.attribute} (期望light)`);
  console.log(`  Race=${bewd.race} (期望dragon), Type=${bewd.cardType} (期望monster_normal)`);
  const bewdOk = bewd.attack === 3000 && bewd.defense === 2500 &&
    bewd.star === 8 && bewd.attribute === 'light' &&
    bewd.race === 'dragon' && bewd.cardType === 'monster_normal';
  console.log(`  ✓ 验证结果: ${bewdOk ? '通过 ✓' : '失败 ✗'}`);

  // 反击陷阱
  console.log();
  const counterTraps = cards.filter(c => c.cardType === 'trap_counter');
  console.log(`反击陷阱数: ${counterTraps.length} (期望7)`);
  for (const ct of counterTraps) {
    console.log(`  idx=${ct.idx} ${ct.names.eng}: byte2=0x${ct.rawBytes[2].toString(16).padStart(2,'0')} (期望0x52)`);
  }

  // 不稳定卡
  const unstableCards = cards.filter(c => c.isUnstable);
  console.log(`\n不稳定卡(race_bits=0): ${unstableCards.length} (期望33)`);
}

// 命令行运行时执行main，作为模块导入时不执行
if (require.main === module) {
  main();
}

// 导出供 generate_card_db.js 使用
module.exports = {
  parseAllCardData,
  generateStatistics,
  verifyRaceMapping,
  GAME_ROOT,
  ATTRIBUTE_CN,
  CARD_TYPE_CN,
};
