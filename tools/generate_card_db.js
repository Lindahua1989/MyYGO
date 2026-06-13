/**
 * MyYGO Generate Card Database - 组装完整card_database.json
 *
 * 读取解析脚本输出的卡牌数据，组装为最终JSON数据库文件。
 */

const fs = require('fs');
const path = require('path');

// 导入解析模块
const { parseAllCardData, generateStatistics, verifyRaceMapping } = require('./parse_card_data.js');

const GAME_ROOT = path.resolve(__dirname, '..', '..', '..', 'Yu-Gi-Oh! Power of Chaos 20th Anniversary');
const OUTPUT_PATH = path.resolve(__dirname, '..', 'data', 'card_database.json');

// ============================================================
// 精简数据格式 - 去除内部调试字段，保留对外接口所需字段
// ============================================================

function formatCardForDatabase(card) {
  return {
    idx: card.idx,
    passcode: card.passcode,
    passcodeTxt: card.passcodeTxt || 0,
    gameId: card.gameId,
    names: card.names,
    descriptions: card.descriptions,
    attack: card.attack,
    defense: card.defense,
    star: card.star,
    attribute: card.attribute,
    race: card.race,
    cardType: card.cardType,
    artFile: card.artFile,
    packId: card.packId,
    isPlaceholder: card.isPlaceholder,
    isUnstable: card.isUnstable,
    rawBytes: card.rawBytes,
  };
}

function main() {
  const gameRoot = process.argv[2] || GAME_ROOT;

  console.log('=== MyYGO 卡牌数据库生成器 ===');
  console.log(`原版数据路径: ${gameRoot}`);
  console.log(`输出路径: ${OUTPUT_PATH}`);
  console.log();

  // 1. 解析所有卡牌数据
  const cards = parseAllCardData(gameRoot);
  const stats = generateStatistics(cards);

  // 2. 组装数据库JSON
  const database = {
    version: '1.0',
    source: 'Yu-Gi-Oh! Power of Chaos 20th Anniversary v1.9',
    generatedDate: new Date().toISOString(),
    totalCards: stats.realCards,
    cards: {},
  };

  for (const card of cards) {
    if (card.isPlaceholder) continue;  // 跳过idx 0占位卡
    const formatted = formatCardForDatabase(card);
    database.cards[String(card.idx)] = formatted;
  }

  // 3. 写入JSON文件
  const jsonStr = JSON.stringify(database, null, 2);
  fs.writeFileSync(OUTPUT_PATH, jsonStr, 'utf-8');

  const fileSizeMB = (Buffer.byteLength(jsonStr) / (1024 * 1024)).toFixed(2);
  console.log();
  console.log(`✓ card_database.json 已生成`);
  console.log(`  文件大小: ${fileSizeMB} MB`);
  console.log(`  卡牌数量: ${stats.realCards}`);
  console.log(`  输出路径: ${OUTPUT_PATH}`);

  // 4. 输出统计摘要
  console.log();
  console.log('--- 卡牌分类统计 ---');
  for (const [ct, count] of Object.entries(stats.byType).sort()) {
    console.log(`  ${ct}: ${count}`);
  }

  console.log();
  console.log('--- 种族映射验证 ---');
  const raceReport = verifyRaceMapping(cards);
  const verifiedKeys = Object.keys(raceReport.verified);
  console.log(`  已验证种族组合: ${verifiedKeys.length}`);

  if (raceReport.discrepancies.length > 0) {
    console.log(`  ⚠ 映射不一致: ${raceReport.discrepancies.length} 处`);
    // 这些不一致多半是因为描述中提到了其他种族（如效果文本提到"龙族卡"）
    console.log('  (多数不一致是效果描述中提及了其他种族类型，而非卡牌自身种族错误)');
  }

  // 5. 关键验证
  console.log();
  console.log('--- 关键验证 ---');

  // Blue-Eyes White Dragon
  const bewd = cards[816];
  const bewdOk = bewd.attack === 3000 && bewd.defense === 2500 &&
    bewd.star === 8 && bewd.attribute === 'light' &&
    bewd.race === 'dragon' && bewd.cardType === 'monster_normal';
  console.log(`  Blue-Eyes White Dragon (idx 816): ${bewdOk ? '✓ 通过' : '✗ 失败'}`);
  if (!bewdOk) {
    console.log(`    ATK=${bewd.attack}(3000), DEF=${bewd.defense}(2500), Star=${bewd.star}(8), Attr=${bewd.attribute}(light), Race=${bewd.race}(dragon)`);
  }

  // 反击陷阱
  const counterTraps = cards.filter(c => c.cardType === 'trap_counter');
  const counterOk = counterTraps.length === 7 && counterTraps.every(c => c.rawBytes[2] === 0x52);
  console.log(`  反击陷阱验证: ${counterOk ? '✓ 通过' : '✗ 失败'} (${counterTraps.length}张, byte2=0x52)`);

  // 验证脚本调用提示
  console.log();
  console.log('运行详细验证: node tools/validate_card_db.js');
}

main();
