# CLAUDE.md — MyYGO项目指令

## 项目概述
MyYGO是游戏王混沌力量（Yu-Gi-Oh! Power of Chaos）的从0到1重构项目，使用Godot Engine 4.x。

## 项目结构
- `tools/` — Python预处理脚本（解析bin数据、BMP转PNG）
- `assets/cards/art/` — 大卡图PNG (199x290)
- `assets/cards/mini/` — 小卡图PNG (49x72)
- `assets/ui/` — UI图形PNG
- `assets/audio/` — 音频文件
- `data/card_database.json` — 卡牌数据库（由tools生成）
- `src/core/` — GDScript核心类（CardData, CardDatabase, 规则引擎）
- `src/scenes/` — Godot场景文件
- `src/ui/` — GDScript UI组件

## 命名规范
- GDScript: snake_case (变量/函数), PascalCase (类名)
- 场景文件: PascalCase (如 card_viewer.tscn)
- JSON键: snake_case

## 关键数据编码
原版card_prop.bin 4字节编码（已验证）:
- byte0: DEF = byte0 * 10
- byte1: ATK低 = byte1 * 5
- byte2: [bit0-1=ATK乘数/子类型][bit2-3=卡类型][bit4-7=种族]
- byte3: [bit0=种族集][bit1-3=星级低][bit4=星级高][bit5-7=属性3位独立]
- ATK = byte1*5 + (byte2&3)*1280
- 星级 = ((b3>>1)&7 + (b3>>4)&1*8) mod 12, 0→11, 12→12

完整编码参考: 混沌力量相关工具/卡牌编码研究日志.md

## 工具使用
- 生成卡牌数据库: `python tools/generate_card_db.py`
- 转换卡图: `python tools/convert_bmp_to_png.py`
- 验证数据库: `python tools/validate_card_db.py`

## 原版资源路径
原版游戏资源在: `../Yu-Gi-Oh! Power of Chaos 20th Anniversary/`

## 构建和运行
- 无构建命令，直接用Godot编辑器打开project.godot
- Python工具需要: Python 3.x + Pillow
