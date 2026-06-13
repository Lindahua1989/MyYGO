# MyYGO

Yu-Gi-Oh! Power of Chaos (游戏王混沌力量) — 从0到1重构项目

## 技术栈
- **游戏引擎**: Godot Engine 4.x
- **脚本语言**: GDScript (游戏逻辑), Python (数据预处理工具)
- **卡牌数据**: JSON格式数据库，由Python脚本从原版bin文件解析生成

## 项目结构
```
MyYGO/
  tools/          — Python预处理脚本（解析bin数据、转换BMP卡图）
  assets/         — 游戏资源（转换后的PNG卡图、UI图形、音频）
  data/           — 游戏数据（card_database.json、禁限卡表）
  src/core/       — 核心系统（CardData模型、CardDatabase单例、规则引擎）
  src/scenes/     — Godot场景（主菜单、卡牌浏览、组卡、决斗）
  src/ui/         — UI组件（卡牌渲染、列表、对话框）
```

## 开发流程
1. 运行 `python tools/generate_card_db.py` 生成卡牌数据库
2. 运行 `python tools/convert_bmp_to_png.py` 转换卡图资源
3. 用Godot编辑器打开项目进行开发

## 原版数据来源
原版游戏资源位于: `../Yu-Gi-Oh! Power of Chaos 20th Anniversary/`
- 卡牌数据: `data/bin#/card_prop.bin` 等（4字节编码，详见混沌力量相关工具/卡牌编码研究日志.md）
- 卡图: `data/card/` (199x290 BMP) 和 `data/mini/` (49x72 BMP)
- 音频: `Voice/joey/english/`
- UI图形: `data/j/`
