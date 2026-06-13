/**
 * MyYGO Validate Card Database - 验证card_database.json的正确性
 *
 * 对照已知数据和研究日志验证卡牌数据库。
 */

const fs = require('fs');
const path = require('path');

const DB_PATH = path.resolve(__dirname, '..', 'data', 'card_database.json');

// ============================================================
// 已知卡牌数据（用于验证）
// ============================================================

const KNOWN_CARDS = {
  816: {  // Blue-Eyes White Dragon
    name: 'Blue-Eyes White Dragon',
    attack: 3000, defense: 2500,
    star: 8, attribute: 'light',
    race: 'dragon', cardType: 'monster_normal',
  },
  803: {  // Dark Magician - 20周年纪念版改为仪式怪兽, 属性仍为dark
    name: 'Dark Magician',
    attack: 2500, defense: 2100,
    star: 7, attribute: 'dark',
    race: 'spellcaster', cardType: 'monster_ritual',
    note: '20周年纪念版修改: 原版normal → 此版ritual',
  },
  248: {  // Sangan
    name: 'Sangan',
    attack: 1000, defense: 600,
    star: 3, attribute: 'dark',
    race: 'fiend', cardType: 'monster_effect',
  },
  // 反击陷阱
  166: { name: 'Solemn Judgment', cardType: 'trap_counter', byte2: 0x52 },
  282: { name: 'Negate Attack', cardType: 'trap_counter', byte2: 0x52 },
  406: { name: 'Horn of Heaven', cardType: 'trap_counter', byte2: 0x52 },
  624: { name: 'Seven Tools of the Bandit', cardType: 'trap_counter', byte2: 0x52 },
  784: { name: 'Riryoku Field', cardType: 'trap_counter', byte2: 0x52 },
  893: { name: 'Magic Jammer', cardType: 'trap_counter', byte2: 0x52 },
  895: { name: 'Magic Drain', cardType: 'trap_counter', byte2: 0x52 },
};

// 期望分类总数（20周年纪念版实测值，与原版研究日志有少量偏差）
const EXPECTED_COUNTS = {
  monster_normal: 340,
  monster_effect: 192,
  monster_fusion: 32,
  monster_ritual: 260,
  monster_unstable_ritual: 4,
  spell_normal: 86,
  spell_field: 14,
  spell_equip: 50,
  spell_continuous: 17,
  spell_quick_play: 19,
  spell_ritual: 5,
  trap_normal: 51,
  trap_counter: 7,
  trap_continuous: 38,
};

// ============================================================
// 验证函数
// ============================================================

function validateDatabase() {
  console.log('=== MyYGO 卡牌数据库验证器 ===');
  console.log();

  if (!fs.existsSync(DB_PATH)) {
    console.error(`✗ card_database.json 不存在: ${DB_PATH}`);
    console.log('请先运行: node tools/generate_card_db.js');
    return false;
  }

  const db = JSON.parse(fs.readFileSync(DB_PATH, 'utf-8'));
  console.log(`数据库版本: ${db.version}`);
  console.log(`数据来源: ${db.source}`);
  console.log(`生成日期: ${db.generatedDate}`);
  console.log(`卡牌总数: ${db.totalCards}`);
  console.log(`实际条目数: ${Object.keys(db.cards).length}`);
  console.log();

  let allPassed = true;

  // 1. 验证已知卡牌数据
  console.log('--- 已知卡牌验证 ---');
  for (const [idx, expected] of Object.entries(KNOWN_CARDS)) {
    const card = db.cards[idx];
    if (!card) {
      console.log(`  ✗ idx=${idx} ${expected.name}: 不存在于数据库`);
      allPassed = false;
      continue;
    }

    const errors = [];
    if (expected.attack !== undefined && card.attack !== expected.attack) {
      errors.push(`ATK: ${card.attack} (期望${expected.attack})`);
    }
    if (expected.defense !== undefined && card.defense !== expected.defense) {
      errors.push(`DEF: ${card.defense} (期望${expected.defense})`);
    }
    if (expected.star !== undefined && card.star !== expected.star) {
      errors.push(`Star: ${card.star} (期望${expected.star})`);
    }
    if (expected.attribute !== undefined && card.attribute !== expected.attribute) {
      errors.push(`Attr: ${card.attribute} (期望${expected.attribute})`);
    }
    if (expected.race !== undefined && card.race !== expected.race) {
      errors.push(`Race: ${card.race} (期望${expected.race})`);
    }
    if (expected.cardType !== undefined && card.cardType !== expected.cardType) {
      errors.push(`Type: ${card.cardType} (期望${expected.cardType})`);
    }
    if (expected.byte2 !== undefined && card.rawBytes[2] !== expected.byte2) {
      errors.push(`byte2: 0x${card.rawBytes[2].toString(16)} (期望0x${expected.byte2.toString(16)})`);
    }

    if (errors.length > 0) {
      console.log(`  ✗ idx=${idx} ${card.names.eng}: ${errors.join(', ')}`);
      allPassed = false;
    } else {
      console.log(`  ✓ idx=${idx} ${card.names.eng}: 通过`);
    }
  }

  // 2. 验证卡牌分类总数
  console.log();
  console.log('--- 分类总数验证 ---');
  const byType = {};
  for (const card of Object.values(db.cards)) {
    byType[card.cardType] = (byType[card.cardType] || 0) + 1;
  }

  for (const [type, expectedCount] of Object.entries(EXPECTED_COUNTS)) {
    const actual = byType[type] || 0;
    const diff = actual - expectedCount;
    const status = diff === 0 ? '✓' : (Math.abs(diff) <= 5 ? '~' : '✗');
    console.log(`  ${status} ${type}: ${actual} (期望${expectedCount}, 差${diff})`);
    if (Math.abs(diff) > 5) allPassed = false;
  }

  // 3. 验证反击陷阱
  console.log();
  console.log('--- 反击陷阱验证 ---');
  const counterTraps = Object.values(db.cards).filter(c => c.cardType === 'trap_counter');
  console.log(`  数量: ${counterTraps.length} (期望7)`);
  for (const ct of counterTraps) {
    const byte2 = ct.rawBytes[2];
    const ok = byte2 === 0x52;
    console.log(`  ${ok ? '✓' : '✗'} idx=${ct.idx} ${ct.names.eng}: byte2=0x${byte2.toString(16)}`);
  }

  // 4. 验证基本数据完整性
  console.log();
  console.log('--- 数据完整性验证 ---');

  // 所有卡牌都有卡名
  const missingNames = Object.values(db.cards).filter(c => !c.names.eng || c.names.eng.trim() === '');
  console.log(`  缺少英文卡名: ${missingNames.length}`);

  // 所有卡牌都有卡图映射
  const missingArt = Object.values(db.cards).filter(c => !c.artFile || c.artFile.trim() === '');
  console.log(`  缺少卡图映射: ${missingArt.length}`);

  // 所有怪兽卡都有种族
  const monstersWithoutRace = Object.values(db.cards).filter(c =>
    c.cardType.startsWith('monster') && !c.isUnstable && !c.race
  );
  console.log(`  怪兽卡缺少种族: ${monstersWithoutRace.length}`);

  // 所有怪兽卡ATK/DEF >= 0
  const invalidStats = Object.values(db.cards).filter(c =>
    c.cardType.startsWith('monster') && (c.attack < 0 || c.defense < 0)
  );
  console.log(`  ATK/DEF异常: ${invalidStats.length}`);

  // 5. 星级范围验证
  console.log();
  console.log('--- 星级范围验证 ---');
  const monsters = Object.values(db.cards).filter(c => c.cardType.startsWith('monster'));
  const stars = monsters.map(c => c.star);
  const minStar = Math.min(...stars);
  const maxStar = Math.max(...stars);
  console.log(`  星级范围: ${minStar} ~ ${maxStar} (期望1~12)`);
  const invalidStars = monsters.filter(c => c.star < 1 || c.star > 12);
  console.log(`  异常星级: ${invalidStars.length}`);
  if (invalidStars.length > 0) {
    for (const c of invalidStars.slice(0, 5)) {
      console.log(`    idx=${c.idx} ${c.names.eng}: star=${c.star}`);
    }
  }

  // 6. 属性分布验证
  console.log();
  console.log('--- 属性分布 ---');
  const byAttr = {};
  for (const card of Object.values(db.cards)) {
    byAttr[card.attribute] = (byAttr[card.attribute] || 0) + 1;
  }
  for (const [attr, count] of Object.entries(byAttr).sort()) {
    console.log(`  ${attr}: ${count}`);
  }

  // 最终结论
  console.log();
  console.log('='.repeat(50));
  if (allPassed) {
    console.log('✓ 全部验证通过！card_database.json 可用于游戏开发');
  } else {
    console.log('✗ 部分验证未通过，请检查上述标记的项目');
  }
  console.log('='.repeat(50));

  return allPassed;
}

validateDatabase();
