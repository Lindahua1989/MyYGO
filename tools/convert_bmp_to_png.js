/**
 * MyYGO BMP to PNG Converter - 批量转换原版BMP卡图为PNG格式
 *
 * 原版32bpp BMP格式不能被sharp直接处理(unsupported format),
 * 所以我们手动解析BMP像素数据(BGRA→RGBA翻转)，然后用sharp生成PNG。
 */

const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const GAME_ROOT = path.resolve(__dirname, '..', '..', '..', 'Yu-Gi-Oh! Power of Chaos 20th Anniversary');
const PROJECT_ROOT = path.resolve(__dirname, '..');

const CARD_ART_SRC = path.join(GAME_ROOT, 'data', 'card');
const MINI_ART_SRC = path.join(GAME_ROOT, 'data', 'mini');
const CARD_ART_DST = path.join(PROJECT_ROOT, 'assets', 'cards', 'art');
const MINI_ART_DST = path.join(PROJECT_ROOT, 'assets', 'cards', 'mini');
const UI_DST = path.join(PROJECT_ROOT, 'assets', 'ui');

// ============================================================
// 手动BMP解析 → RGBA像素数据 → PNG输出
// ============================================================

function parseBmpToRawRGBA(bmpBuffer) {
  // 解析BMP头部
  const signature = bmpBuffer.toString('ascii', 0, 2);
  if (signature !== 'BM') throw new Error('Not a BMP file');

  const dataOffset = bmpBuffer.readUInt32LE(10);
  const dibHeaderSize = bmpBuffer.readUInt32LE(14);
  const width = bmpBuffer.readInt32LE(18);
  const height = bmpBuffer.readInt32LE(22);
  const bitsPerPixel = bmpBuffer.readUInt16LE(28);
  const compression = bmpBuffer.readUInt32LE(30);

  const absHeight = Math.abs(height);
  const topDown = height < 0;
  const pixelData = bmpBuffer.subarray(dataOffset);

  let rgba;

  if (bitsPerPixel === 32 && compression === 0) {
    // 32bpp BGRA → RGBA
    rgba = Buffer.alloc(width * absHeight * 4);
    for (let y = 0; y < absHeight; y++) {
      const srcRow = topDown ? y : (absHeight - 1 - y);
      for (let x = 0; x < width; x++) {
        const srcIdx = (srcRow * width + x) * 4;
        const dstIdx = (y * width + x) * 4;
        rgba[dstIdx]     = pixelData[srcIdx + 2];  // R
        rgba[dstIdx + 1] = pixelData[srcIdx + 1];  // G
        rgba[dstIdx + 2] = pixelData[srcIdx];       // B
        rgba[dstIdx + 3] = pixelData[srcIdx + 3];  // A
      }
    }
  } else if (bitsPerPixel === 24 && compression === 0) {
    // 24bpp BGR → RGBA (add full alpha)
    // 24bpp rows are padded to 4-byte alignment
    const srcRowSize = Math.ceil(width * 3 / 4) * 4;
    rgba = Buffer.alloc(width * absHeight * 4);
    for (let y = 0; y < absHeight; y++) {
      const srcRow = topDown ? y : (absHeight - 1 - y);
      for (let x = 0; x < width; x++) {
        const srcIdx = srcRow * srcRowSize + x * 3;
        const dstIdx = (y * width + x) * 4;
        rgba[dstIdx]     = pixelData[srcIdx + 2];  // R
        rgba[dstIdx + 1] = pixelData[srcIdx + 1];  // G
        rgba[dstIdx + 2] = pixelData[srcIdx];       // B
        rgba[dstIdx + 3] = 255;                     // A (full opacity for 24bpp)
      }
    }
  } else {
    throw new Error(`Unsupported BMP: bpp=${bitsPerPixel}, compression=${compression}`);
  }

  return { width, height: absHeight, rgba };
}

async function convertBmpFileToPng(srcPath, dstPath) {
  const bmpBuffer = fs.readFileSync(srcPath);
  const { width, height, rgba } = parseBmpToRawRGBA(bmpBuffer);

  await sharp(rgba, { raw: { width, height, channels: 4 } })
    .png({ compressionLevel: 6 })
    .toFile(dstPath);

  return { width, height };
}

// ============================================================
// 批量转换函数
// ============================================================

async function convertBmpDirectory(srcDir, dstDir, options = {}) {
  const { skipExisting = true, verbose = false } = options;

  if (!fs.existsSync(srcDir)) {
    console.error(`✗ 源目录不存在: ${srcDir}`);
    return { total: 0, converted: 0, skipped: 0, failed: 0, failedFiles: [] };
  }

  fs.mkdirSync(dstDir, { recursive: true });

  const bmpFiles = fs.readdirSync(srcDir)
    .filter(f => f.toLowerCase().endsWith('.bmp'));

  console.log(`转换目录: ${srcDir} → ${dstDir}`);
  console.log(`找到 ${bmpFiles.length} 个BMP文件`);

  const stats = { total: bmpFiles.length, converted: 0, skipped: 0, failed: 0, failedFiles: [] };

  for (let i = 0; i < bmpFiles.length; i++) {
    const bmpFile = bmpFiles[i];
    const srcPath = path.join(srcDir, bmpFile);
    const pngFile = bmpFile.replace(/\.bmp$/i, '.png');
    const dstPath = path.join(dstDir, pngFile);

    // 跳过已存在的PNG文件
    if (skipExisting && fs.existsSync(dstPath)) {
      stats.skipped++;
      continue;
    }

    try {
      await convertBmpFileToPng(srcPath, dstPath);
      stats.converted++;
      if (verbose || (i % 100 === 0 && i > 0)) {
        console.log(`  进度: ${i}/${bmpFiles.length} (${stats.converted} 转换, ${stats.skipped} 跳过)`);
      }
    } catch (err) {
      stats.failed++;
      stats.failedFiles.push(bmpFile);
      if (stats.failed <= 10) {
        console.error(`  ✗ ${bmpFile}: ${err.message}`);
      }
    }
  }

  console.log(`  转换: ${stats.converted}, 跳过: ${stats.skipped}, 失败: ${stats.failed}`);
  if (stats.failed > 10) {
    console.log(`  (前10个失败文件已显示，共${stats.failed}个失败)`);
  }

  return stats;
}

// ============================================================
// UI图形转换
// ============================================================

async function convertUIBmps() {
  const uiDirMappings = [
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'field'), dst: path.join(UI_DST, 'duel', 'field') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'card'), dst: path.join(UI_DST, 'duel', 'card') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'phase'), dst: path.join(UI_DST, 'duel', 'phase') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'phase_name'), dst: path.join(UI_DST, 'duel', 'phase_name') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'life'), dst: path.join(UI_DST, 'duel', 'life') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'detail'), dst: path.join(UI_DST, 'duel', 'detail') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'chain'), dst: path.join(UI_DST, 'duel', 'chain') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'effect'), dst: path.join(UI_DST, 'duel', 'effect') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'list'), dst: path.join(UI_DST, 'duel', 'list') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'list_icon'), dst: path.join(UI_DST, 'duel', 'list_icon') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'get'), dst: path.join(UI_DST, 'duel', 'get') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'dialog'), dst: path.join(UI_DST, 'duel', 'dialog') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'help'), dst: path.join(UI_DST, 'duel', 'help') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'exodia'), dst: path.join(UI_DST, 'duel', 'exodia') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'duel', 'match'), dst: path.join(UI_DST, 'duel', 'match') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'title'), dst: path.join(UI_DST, 'title') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'deck_c'), dst: path.join(UI_DST, 'deck_c') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'bust_up'), dst: path.join(UI_DST, 'bust_up') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'janken'), dst: path.join(UI_DST, 'janken') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'lan_duel'), dst: path.join(UI_DST, 'lan_duel') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'tutorial'), dst: path.join(UI_DST, 'tutorial') },
    { src: path.join(GAME_ROOT, 'data', 'j', 'file'), dst: path.join(UI_DST, 'file') },
  ];

  let totalStats = { total: 0, converted: 0, skipped: 0, failed: 0 };

  for (const mapping of uiDirMappings) {
    if (!fs.existsSync(mapping.src)) continue;

    const bmpFiles = fs.readdirSync(mapping.src)
      .filter(f => f.toLowerCase().endsWith('.bmp'));

    if (bmpFiles.length === 0) continue;

    console.log();
    const stats = await convertBmpDirectory(mapping.src, mapping.dst);
    totalStats.total += stats.total;
    totalStats.converted += stats.converted;
    totalStats.skipped += stats.skipped;
    totalStats.failed += stats.failed;
  }

  return totalStats;
}

// ============================================================
// 主入口
// ============================================================

async function main() {
  const args = process.argv.slice(2);
  const forceConvert = args.includes('--force');
  const skipUI = args.includes('--skip-ui');
  const skipMini = args.includes('--skip-mini');

  console.log('=== MyYGO BMP → PNG 转换器 ===');
  console.log('(使用自定义BMP解析器处理32bpp ARGB格式)');
  console.log();

  // 1. 大卡图
  console.log('--- 大卡图转换 (data/card/) ---');
  const cardStats = await convertBmpDirectory(CARD_ART_SRC, CARD_ART_DST, {
    skipExisting: !forceConvert,
  });

  // 2. 小卡图
  if (!skipMini) {
    console.log();
    console.log('--- 小卡图转换 (data/mini/) ---');
    const miniStats = await convertBmpDirectory(MINI_ART_SRC, MINI_ART_DST, {
      skipExisting: !forceConvert,
    });
  }

  // 3. UI图形
  if (!skipUI) {
    console.log();
    console.log('--- UI图形转换 ---');
    await convertUIBmps();
  }

  console.log();
  console.log('✓ 转换完成！');

  // 验证：检查生成的PNG文件数量
  const artPngs = fs.readdirSync(CARD_ART_DST).filter(f => f.endsWith('.png'));
  const miniPngs = fs.readdirSync(MINI_ART_DST).filter(f => f.endsWith('.png'));
  console.log(`大卡图PNG: ${artPngs.length} 个`);
  console.log(`小卡图PNG: ${miniPngs.length} 个`);
}

main().catch(err => {
  console.error('转换失败:', err);
  process.exit(1);
});
