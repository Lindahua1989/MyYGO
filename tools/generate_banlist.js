/**
 * MyYGO Banlist Generator - 从原版禁限表目录生成banlist.json
 */
const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const GAME_ROOT = path.resolve(__dirname, '..', '..', '..', 'Yu-Gi-Oh! Power of Chaos 20th Anniversary');

const db = JSON.parse(fs.readFileSync(path.join(PROJECT_ROOT, 'data', 'card_database.json'), 'utf-8'));

// 大小写不敏感映射: artFile -> idx
const artToIdx = {};
for (const [idx, card] of Object.entries(db.cards)) {
  if (card.artFile) artToIdx[card.artFile.toUpperCase()] = parseInt(idx);
}

// 解析禁限表目录
const banlistRoot = path.join(GAME_ROOT, '禁限表');

function parseBanlistCategory(subdir) {
  const dir = path.join(banlistRoot, subdir);
  if (!fs.existsSync(dir)) return [];
  const indices = [];
  let unmapped = 0;
  for (const f of fs.readdirSync(dir)) {
    if (f === 'blue_card.png') continue;
    const base = f.replace(/\.(bmp|png)$/i, '').toUpperCase();
    const idx = artToIdx[base];
    if (idx !== undefined) {
      indices.push(idx);
    } else {
      unmapped++;
      if (unmapped <= 3) console.log('  未映射: ' + f);
    }
  }
  if (unmapped > 0) console.log('  共' + unmapped + '个未映射');
  return indices.sort((a, b) => a - b);
}

const forbidden = parseBanlistCategory('禁止卡');
const limitOne = parseBanlistCategory('限一卡');
const limitTwo = parseBanlistCategory('限二卡');

const banlist = {
  version: '1.0',
  source: 'Yu-Gi-Oh! Power of Chaos 20th Anniversary v1.9',
  forbidden: forbidden,
  limit_one: limitOne,
  limit_two: limitTwo,
  note: '禁止卡在原版游戏中未实际生效(最多38张禁限卡位), 限一和限二已生效'
};

const outDir = path.join(PROJECT_ROOT, 'data', 'banlists');
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'default.json'), JSON.stringify(banlist, null, 2));

console.log('禁止: ' + forbidden.length + ', 限一: ' + limitOne.length + ', 限二: ' + limitTwo.length);
console.log('总计: ' + (forbidden.length + limitOne.length + limitTwo.length));
console.log('输出: ' + path.join(outDir, 'default.json'));
