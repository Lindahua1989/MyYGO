## MainMenu - 主菜单场景
## 游戏启动入口，提供导航到各功能场景
extends Control

# ============================================================
# 场景路径常量
# ============================================================

const CARD_VIEWER_PATH: String = "res://src/scenes/card_viewer.tscn"

# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	name = "MainMenu"
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_build_ui()

# ============================================================
# UI构建
# ============================================================

func _build_ui() -> void:
	# 背景面板
	var bg_panel = Panel.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	# 主布局 - 居中垂直排列
	var center_vbox = VBoxContainer.new()
	center_vbox.set_anchors_preset(Control.PRESET_CENTER)
	center_vbox.add_theme_constant_override("separation", 20)
	add_child(center_vbox)

	# 游戏标题
	var title_label = Label.new()
	title_label.text = "MyYGO\n游戏王混沌力量"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.15, 0.15, 0.2)
	title_style.set_corner_radius_all(10)
	title_style.border_color = Color(0.4, 0.4, 0.6)
	title_style.border_width_bottom = 2; title_style.border_width_top = 2; title_style.border_width_left = 2; title_style.border_width_right = 2
	title_label.add_theme_stylebox_override("normal", title_style)
	center_vbox.add_child(title_label)

	# 版本信息
	var version_label = Label.new()
	version_label.text = "v0.2 - Phase 3: 组卡器"

	# 功能按钮
	_add_menu_button(center_vbox, "📚 卡牌浏览", _on_card_viewer_pressed)
	_add_menu_button(center_vbox, "🃏 组卡器", _on_deck_builder_pressed)
	_add_menu_button(center_vbox, "⚔ 决斗 (Phase 5)", _on_not_implemented)
	_add_menu_button(center_vbox, "⚙ 设置", _on_settings_pressed)
	_add_menu_button(center_vbox, "❌ 退出", _on_quit_pressed)

## 添加菜单按钮
func _add_menu_button(container: VBoxContainer, text: String, callback: Callable) -> void:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 45)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)

	# 按钮样式
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.2, 0.25)
	btn_style.set_corner_radius_all(8)
	btn_style.border_color = Color(0.4, 0.4, 0.5)
	btn_style.border_width_bottom = 1; btn_style.border_width_top = 1; btn_style.border_width_left = 1; btn_style.border_width_right = 1

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.3, 0.3, 0.35)
	btn_hover.set_corner_radius_all(8)
	btn_hover.border_color = Color(0.6, 0.6, 0.7)
	btn_hover.border_width_bottom = 1; btn_style.border_width_top = 1; btn_style.border_width_left = 1; btn_style.border_width_right = 1

	button.add_theme_stylebox_override("normal", btn_style)
	button.add_theme_stylebox_override("hover", btn_hover)

	container.add_child(button)

# ============================================================
# 事件处理
# ============================================================

func _on_card_viewer_pressed() -> void:
	get_tree().change_scene_to_file("res://src/scenes/card_viewer.tscn")

func _on_deck_builder_pressed() -> void:
	get_tree().change_scene_to_file("res://src/scenes/deck_builder.tscn")

func _on_settings_pressed() -> void:
	# 简单的语言切换对话框
	var dialog = AcceptDialog.new()
	dialog.title = "设置"
	dialog.dialog_text = "语言: English (当前)\n更多设置功能将在后续版本实现"
	add_child(dialog)
	dialog.popup_centered()

func _on_not_implemented() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "提示"
	dialog.dialog_text = "此功能尚未实现，将在后续Phase中开发"
	add_child(dialog)
	dialog.popup_centered()

func _on_quit_pressed() -> void:
	get_tree().quit()
