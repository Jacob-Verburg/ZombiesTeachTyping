extends GutTest
## Shared HUD band (Story 2.5): layout from the approved sketch (sketches/hud-band-2-5.md), prompt
## per mode, countdown, live WPM rule, counts, shake, Caps Lock hint, focus and mouse rules.
## Story 7.5: the widest word of every tier pool fits the sign inside the 312 px target area.
## Disabled instance: _process is driven by hand.

const HudScene: PackedScene = preload("res://scenes/run/hud.tscn")
const HudScript := preload("res://scripts/run/hud.gd")
const THEME_PATH: String = "res://data/ui_theme.tres"

var _hud: HudScript


func before_each() -> void:
	_hud = HudScene.instantiate() as HudScript
	_hud.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(_hud)
	_hud.size = Vector2(640, 360)


func _config(mode: LevelConfig.TargetMode, duration: float = 120.0) -> LevelConfig:
	var config: LevelConfig = LevelConfig.new()
	config.duration_s = duration
	config.target_mode = mode
	return config


func _letter_setup() -> void:
	_hud.setup(_config(LevelConfig.TargetMode.LETTER), "f")


func _node(path: String) -> Control:
	return _hud.get_node(path) as Control


func _text(path: String) -> String:
	return (_hud.get_node(path) as Label).text


## The node's rect in HUD (canvas) coordinates.
func _rect(path: String) -> Rect2:
	var node: Control = _node(path)
	return Rect2(node.global_position - _hud.global_position, node.size)


func _font_size(label: Label) -> int:
	return label.get_theme_font_size("font_size")


# --- layout (approved sketch table) -------------------------------------------

func test_band_layout() -> void:
	_letter_setup()
	assert_eq(_rect("%Band"), Rect2(0, 256, 640, 104))
	assert_eq(_rect("%PetSlot"), Rect2(0, 256, 64, 104))
	assert_eq(_rect("%PetCushion"), Rect2(8, 300, 48, 48))
	assert_eq(_rect("%TargetArea"), Rect2(64, 256, 312, 104))
	assert_eq(_rect("%HandsArea"), Rect2(64, 308, 312, 48))
	assert_eq(_rect("%Stats"), Rect2(376, 260, 176, 96))
	assert_eq(_rect("%BrainCounter"), Rect2(556, 264, 80, 28))
	assert_eq(_rect("%CapsHint"), Rect2(92, 196, 256, 28))
	# Story 5.2 (Gate A): the hit area grew to 32 × 32 (the click-target floor); the 24 px art is unchanged.
	assert_eq(_rect("%PauseButton"), Rect2(592, 16, 32, 32))


## Story 4.3: the pet slot sits on the cushion, its feet inside the cushion rect, and its 32 px frame
## stays inside the 64 px pet column.
func test_pet_sits_on_the_cushion() -> void:
	_letter_setup()
	var pet: PetSlot = _hud.get_node("%Pet") as PetSlot
	assert_not_null(pet, "%Pet is a PetSlot")
	assert_eq(pet.get_parent(), _hud.get_node("%PetSlot"), "inside the %PetSlot column")
	assert_true(pet.get_index() > _hud.get_node("%PetCushion").get_index(), "drawn over the cushion")
	var feet: Vector2 = pet.global_position - _hud.global_position
	assert_true(_rect("%PetCushion").has_point(feet), "feet on the cushion")
	var frame: Rect2 = Rect2(feet + Vector2(-16, -31), Vector2(32, 32))
	assert_true(_rect("%PetSlot").encloses(frame), "the pet stays inside the 64 px column")


func test_left_to_right_order() -> void:
	_letter_setup()
	assert_lt(_rect("%PetSlot").position.x, _rect("%TargetArea").position.x)
	assert_lt(_rect("%TargetArea").position.x, _rect("%Stats").position.x)
	assert_lt(_rect("%Stats").position.x, _rect("%BrainCounter").position.x)


func test_stats_rows() -> void:
	_letter_setup()
	var rows: Array[String] = ["Timer", "Keys", "Wpm", "Errors"]
	var labels: Array[String] = ["Timer", "Keys", "WPM", "Errors"]
	for i: int in rows.size():
		var y: float = 270 + 20 * i
		assert_eq(_rect("%%%sLabel" % rows[i]), Rect2(380, y, 96, 16), "%s label rect" % rows[i])
		assert_eq(_rect("%%%sValue" % rows[i]), Rect2(480, y, 64, 16), "%s value rect" % rows[i])
		assert_eq(_text("%%%sLabel" % rows[i]), labels[i])
		var value: Label = _hud.get_node("%%%sValue" % rows[i]) as Label
		assert_eq(value.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "%s value right-aligned" % rows[i])


func test_pause_button_margins() -> void:
	var rect: Rect2 = _rect("%PauseButton")
	assert_eq(640 - rect.end.x, 16.0, "16 px from the right edge")
	assert_eq(rect.position.y, 16.0, "16 px from the top")
	assert_true(rect.end.y <= 256, "inside the playfield")


## Story 5.2 (Gate A): the 32 × 32 hit area draws the same 24 px round art, centred (every state's box is
## inset 4 px), and the pause glyph stays centred on it.
func test_pause_art_stays_24px_and_centred_in_the_hit_area() -> void:
	var button: Button = _node("%PauseButton") as Button
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var box: StyleBoxTexture = button.get_theme_stylebox(state) as StyleBoxTexture
		assert_not_null(box, "%s is the round art" % state)
		if box == null:
			continue
		assert_eq(box.texture.get_size(), Vector2(24, 24), "%s art is 24 px" % state)
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			assert_eq(box.get_expand_margin(side), -4.0, "%s drawn 4 px inside the hit area" % state)
	var icon: Control = button.get_node("PauseIcon") as Control
	assert_eq(icon.position + icon.size / 2.0, Vector2(16, 15), "the glyph stays where it was on the art")


func test_letter_sign_rect() -> void:
	_letter_setup()
	assert_eq(_rect("%TargetSign"), Rect2(196, 260, 48, 40))


func test_word_sign_grows_with_the_word() -> void:
	_hud.setup(_config(LevelConfig.TargetMode.WORD), "zombie")
	assert_eq(_rect("%TargetSign"), Rect2(116, 260, 208, 40), "6 x 32 + 16, centred on x 220")
	_hud.show_target("cat")
	assert_eq(_rect("%TargetSign"), Rect2(164, 260, 112, 40))


func test_widest_tier_word_fits_the_target_area() -> void:
	var json: JSON = load("res://data/content/word_pools.json") as JSON
	assert_not_null(json, "word_pools.json loads")
	var tiers: Array = (json.data as Dictionary).get("tiers", []) as Array
	assert_false(tiers.is_empty(), "the pools have tiers")
	_hud.setup(_config(LevelConfig.TargetMode.WORD), "a")
	var font: Font = (_hud.get_node("%TargetLabel") as Label).get_theme_font("font")
	var area: Rect2 = _rect("%TargetArea")
	assert_eq(area.size.x, 312.0, "the target area is 312 px wide")
	for entry: Dictionary in tiers:
		var words: Array = entry["words"] as Array
		assert_false(words.is_empty(), "tier %d has words" % int(entry["tier"]))
		var widest: String = ""
		var widest_px: float = 0.0
		for word: String in words:
			var px: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, HudScript.LINE_FONT_SIZE).x
			if px > widest_px:
				widest_px = px
				widest = word
		assert_true(widest_px + 2.0 * HudScript.SIGN_PAD_X <= area.size.x,
				"tier %d: '%s' (%.0f px) fits" % [int(entry["tier"]), widest, widest_px])
		_hud.show_target(widest)
		var sign_rect: Rect2 = _rect("%TargetSign")
		assert_true(sign_rect.position.x >= area.position.x and sign_rect.end.x <= area.end.x,
				"tier %d: the sign for '%s' stays inside the target area" % [int(entry["tier"]), widest])


func test_paragraph_sign_rect() -> void:
	_hud.setup(_config(LevelConfig.TargetMode.PARAGRAPH), "the cat sat")
	assert_eq(_rect("%TargetSign"), Rect2(68, 260, 304, 52), "Story 8.2: 48 + 4 px of padding")


func test_start_prompt_strip_centred_on_target_area() -> void:
	_letter_setup()
	assert_eq(_rect("%StartPrompt"), Rect2(16, 228, 408, 24), "25 chars x 16 + 8")
	_hud.setup(_config(LevelConfig.TargetMode.WORD), "cat")
	assert_eq(_rect("%StartPrompt"), Rect2(32, 228, 376, 24), "23 chars x 16 + 8")


# --- readability and glyphs ------------------------------------------------------

func test_target_font_size_by_mode() -> void:
	var target: Label = _hud.get_node("%TargetLabel") as Label
	_hud.setup(_config(LevelConfig.TargetMode.LETTER), "f")
	assert_eq(_font_size(target), 32)
	_hud.setup(_config(LevelConfig.TargetMode.WORD), "cat")
	assert_eq(_font_size(target), 32)
	_hud.setup(_config(LevelConfig.TargetMode.PARAGRAPH), "the cat sat")
	assert_eq(_font_size(target), 24)


func test_every_label_is_readable() -> void:
	_letter_setup()
	for node: Node in _hud.find_children("*", "Label", true, false):
		var label: Label = node as Label
		var size: int = _font_size(label)
		assert_true(size >= 16, "%s font size %d" % [label.name, size])
		assert_eq(size % 8, 0, "%s on the 8 px grid" % label.name)


func test_every_hud_string_has_glyphs() -> void:
	var font: Font = (load(THEME_PATH) as Theme).default_font
	var strings: Array[String] = [
		"Timer", "Keys", "WPM", "Errors", "Caps Lock is on", HudScript.WPM_PLACEHOLDER,
		"0123456789", ":",
	]
	for mode: LevelConfig.TargetMode in HudScript.PROMPTS:
		strings.append(HudScript.PROMPTS[mode])
	for s: String in strings:
		for i: int in s.length():
			assert_true(font.has_char(s.unicode_at(i)), "glyph '%s' in '%s'" % [s[i], s])


# --- target area by mode ----------------------------------------------------------

func test_target_line_count_by_mode() -> void:
	_hud.setup(_config(LevelConfig.TargetMode.LETTER), "f")
	assert_eq(_hud.get_target_line_count(), 1)
	assert_eq(_rect("%Band").size.y, 104.0)
	_hud.setup(_config(LevelConfig.TargetMode.WORD), "cat")
	assert_eq(_hud.get_target_line_count(), 1)
	assert_eq(_rect("%Band").size.y, 104.0)
	_hud.setup(_config(LevelConfig.TargetMode.PARAGRAPH), "the cat sat")
	assert_eq(_hud.get_target_line_count(), 2)
	assert_eq(_rect("%Band").size.y, 104.0)
	assert_eq(_rect("%HandsArea"), Rect2(64, 308, 312, 48), "hands area in every mode")


func test_paragraph_lines_are_24_px() -> void:
	_hud.setup(_config(LevelConfig.TargetMode.PARAGRAPH), "the cat sat")
	var target: Label = _hud.get_node("%TargetLabel") as Label
	assert_eq(target.get_line_height(), 24, "line 1")
	var next_line: Label = _hud.get_node("%NextLineLabel") as Label
	assert_eq(next_line.get_line_height(), 24, "line 2")
	assert_eq(_font_size(next_line), 24)


# --- waiting prompt ---------------------------------------------------------------

func test_prompt_per_mode() -> void:
	_hud.setup(_config(LevelConfig.TargetMode.LETTER), "f")
	assert_eq(_text("%StartPromptLabel"), "Type the letter to start!")
	_hud.setup(_config(LevelConfig.TargetMode.WORD), "cat")
	assert_eq(_text("%StartPromptLabel"), "Type the word to start!")
	_hud.setup(_config(LevelConfig.TargetMode.PARAGRAPH), "the cat")
	assert_eq(_text("%StartPromptLabel"), "Type the text to start!")


func test_prompt_hides_on_first_key() -> void:
	_letter_setup()
	assert_true(_node("%StartPrompt").visible)
	_hud.hide_start_prompt()
	assert_false(_node("%StartPrompt").visible)


func test_waiting_values() -> void:
	_letter_setup()
	assert_eq(_text("%TargetLabel"), "f")
	assert_eq(_text("%TimerValue"), "2:00")
	assert_eq(_text("%WpmValue"), HudScript.WPM_PLACEHOLDER)
	assert_eq(_text("%KeysValue"), "0")
	assert_eq(_text("%ErrorsValue"), "0")
	assert_eq((_hud.get_node("%BrainCounter/%CountLabel") as Label).text, "0")
	assert_false(_node("%CapsHint").visible)


func test_setup_resets_a_previous_run() -> void:
	_letter_setup()
	_hud.set_counts(5, 2)
	_hud.set_brains(3)
	_hud.update_clock(10.0, 5)
	_hud.hide_start_prompt()
	_hud.set_caps_hint(true)
	_letter_setup()
	assert_eq(_text("%KeysValue"), "0")
	assert_eq(_text("%ErrorsValue"), "0")
	assert_eq(_text("%TimerValue"), "2:00")
	assert_eq(_text("%WpmValue"), HudScript.WPM_PLACEHOLDER)
	assert_eq((_hud.get_node("%BrainCounter/%CountLabel") as Label).text, "0")
	assert_true(_node("%StartPrompt").visible)
	assert_false(_node("%CapsHint").visible)


# --- live stats -------------------------------------------------------------------

func test_timer_counts_down() -> void:
	_letter_setup()
	_hud.update_clock(0.0, 0)
	assert_eq(_text("%TimerValue"), "2:00")
	_hud.update_clock(0.3, 0)
	assert_eq(_text("%TimerValue"), "2:00", "ceil of 119.7")
	_hud.update_clock(1.0, 0)
	assert_eq(_text("%TimerValue"), "1:59")
	_hud.update_clock(119.5, 0)
	assert_eq(_text("%TimerValue"), "0:01", "never 0:00 while time is left")
	_hud.update_clock(120.0, 0)
	assert_eq(_text("%TimerValue"), "0:00")
	_hud.update_clock(130.0, 0)
	assert_eq(_text("%TimerValue"), "0:00")


func test_timer_counts_up_without_duration() -> void:
	_hud.setup(_config(LevelConfig.TargetMode.LETTER, 0.0), "f")
	assert_eq(_text("%TimerValue"), "0:00")
	_hud.update_clock(65.0, 0)
	assert_eq(_text("%TimerValue"), "1:05")


func test_live_wpm_rule() -> void:
	_letter_setup()
	_hud.update_clock(4.99, 10)
	assert_eq(_text("%WpmValue"), HudScript.WPM_PLACEHOLDER, "hidden for the first 5 s")
	_hud.update_clock(5.0, 10)
	assert_eq(_text("%WpmValue"), "24", "10 keys in 5 s")
	_hud.update_clock(5.5, 30)
	assert_eq(_text("%WpmValue"), "24", "1 Hz: unchanged between whole seconds")
	_hud.update_clock(6.0, 30)
	assert_eq(_text("%WpmValue"), "60")
	_hud.update_clock(6.9, 99)
	assert_eq(_text("%WpmValue"), "60")


func test_counts_and_brains() -> void:
	_letter_setup()
	_hud.set_counts(42, 3)
	assert_eq(_text("%KeysValue"), "42")
	assert_eq(_text("%ErrorsValue"), "3")
	_hud.set_brains(12)
	assert_eq((_hud.get_node("%BrainCounter/%CountLabel") as Label).text, "12")


func test_show_target() -> void:
	_letter_setup()
	_hud.show_target("k")
	assert_eq(_text("%TargetLabel"), "k")


# --- wrong-key shake --------------------------------------------------------------

func test_shake_moves_only_the_glyph_and_returns_to_zero() -> void:
	_letter_setup()
	var target: Label = _hud.get_node("%TargetLabel") as Label
	var sign_rect: Rect2 = _rect("%TargetSign")
	var modulate_before: Color = target.modulate
	var colour_before: Color = target.get_theme_color("font_color")
	assert_eq(_hud.get_target_offset_x(), 0.0)
	_hud.shake_target()
	_hud._process(0.05)
	var offset: float = _hud.get_target_offset_x()
	assert_ne(offset, 0.0)
	assert_true(absf(offset) <= HudScript.SHAKE_PX, "offset %f within 2 px" % offset)
	assert_eq(_rect("%TargetSign"), sign_rect, "the sign stays still")
	assert_eq(target.modulate, modulate_before, "no colour change")
	assert_eq(target.get_theme_color("font_color"), colour_before, "no colour change")
	_hud._process(0.15)
	assert_eq(_hud.get_target_offset_x(), 0.0, "exactly 0 after 0.2 s")


func test_shake_goes_both_ways() -> void:
	_letter_setup()
	_hud.shake_target()
	var seen: Dictionary[float, bool] = {}
	for i: int in 4:
		seen[_hud.get_target_offset_x()] = true
		_hud._process(0.04)
	assert_true(seen.has(HudScript.SHAKE_PX) and seen.has(-HudScript.SHAKE_PX), "%s" % seen)


func test_second_wrong_key_restarts_the_shake() -> void:
	_letter_setup()
	_hud.shake_target()
	_hud._process(0.15)
	_hud.shake_target()
	_hud._process(0.15)
	assert_ne(_hud.get_target_offset_x(), 0.0, "restarted: still shaking 0.3 s after the first key")
	_hud._process(0.05)
	assert_eq(_hud.get_target_offset_x(), 0.0)


func test_new_target_during_shake_ends_at_zero() -> void:
	_letter_setup()
	_hud.shake_target()
	_hud._process(0.05)
	_hud.show_target("k")
	_hud._process(0.2)
	assert_eq(_hud.get_target_offset_x(), 0.0)
	assert_eq(_text("%TargetLabel"), "k")


# --- Caps Lock hint ---------------------------------------------------------------

func test_caps_hint() -> void:
	_letter_setup()
	assert_false(_node("%CapsHint").visible)
	_hud.set_caps_hint(true)
	assert_true(_node("%CapsHint").visible)
	assert_eq(_text("%CapsHintLabel"), "Caps Lock is on")
	_hud.set_caps_hint(false)
	assert_false(_node("%CapsHint").visible)


# --- focus, mouse, pause ----------------------------------------------------------

func test_focus_and_mouse_rules() -> void:
	var controls: Array[Node] = [_hud]
	controls.append_array(_hud.find_children("*", "Control", true, false))
	var pause: Control = _node("%PauseButton")
	for node: Node in controls:
		var control: Control = node as Control
		assert_eq(control.focus_mode, Control.FOCUS_NONE, "%s focus" % control.name)
		if control != pause:
			assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s mouse" % control.name)
	assert_ne(pause.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the pause button takes clicks")


func test_pause_button_emits_pause_pressed() -> void:
	watch_signals(_hud)
	_node("%PauseButton").emit_signal("pressed")
	assert_signal_emit_count(_hud, "pause_pressed", 1)


# --- zombie hands (Story 2.6) -----------------------------------------------

func _hands_lit() -> Array[Vector2i]:
	return _hud.get_node("%ZombieHands").call("get_lit_fingers")


func test_hands_follow_the_target() -> void:
	_letter_setup()
	assert_eq(_hands_lit(), [Vector2i(FingerMap.Hand.LEFT, FingerMap.Finger.INDEX)] as Array[Vector2i], "f after setup")
	_hud.show_target("j")
	assert_eq(_hands_lit(), [Vector2i(FingerMap.Hand.RIGHT, FingerMap.Finger.INDEX)] as Array[Vector2i], "j after show_target")


func test_clear_hands_stops_the_guide() -> void:
	_letter_setup()
	_hud.clear_hands()
	assert_eq(_hands_lit(), [] as Array[Vector2i])


func test_hands_fill_the_hands_area() -> void:
	_letter_setup()
	assert_eq(_rect("%ZombieHands"), Rect2(64, 308, 312, 48))


func test_hands_do_not_shake() -> void:
	_letter_setup()
	var before: Rect2 = _rect("%ZombieHands")
	_hud.shake_target()
	_hud._process(0.05)
	assert_eq(_rect("%ZombieHands"), before)


# --- word mode (Story 6.2) ------------------------------------------------------

func _word_setup(first: String = "dad") -> void:
	_hud.setup(_config(LevelConfig.TargetMode.WORD), first)


func _glyph_width(text: String) -> float:
	var font: Font = (_hud.get_node("%TargetLabel") as Label).get_theme_font("font")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, HudScript.LINE_FONT_SIZE).x


func _typed() -> Label:
	return _hud.get_node("%TypedLabel") as Label


func _underline() -> ColorRect:
	return _hud.get_node("%NextUnderline") as ColorRect


func test_word_typed_letters_and_underline() -> void:
	_word_setup()
	_hud.show_target("dad", 1)
	assert_eq(_text("%TargetLabel"), "dad", "the target label keeps the whole word")
	assert_true(_typed().visible)
	assert_eq(_typed().text, "d")
	assert_eq(_typed().position, Vector2.ZERO)
	assert_true(_underline().visible)
	assert_eq(_underline().position.x, _glyph_width("d"), "under the second letter")
	assert_eq(_underline().size, Vector2(_glyph_width("a"), HudScript.UNDERLINE_PX))
	assert_eq(_underline().size.y, 2.0)
	assert_eq(_underline().position.y, HudScript.LINE_FONT_SIZE + HudScript.UNDERLINE_GAP)


func test_word_typed_colours_and_size() -> void:
	_word_setup()
	_hud.show_target("dad", 1)
	assert_eq(_typed().get_theme_color(&"font_color"), Color("#2E6B26"), "zombie-green-dark")
	assert_eq(_font_size(_typed()), 32)
	var ink: Color = (_hud.get_node("%TargetLabel") as Label).get_theme_color(&"font_color")
	assert_eq(_underline().color, ink, "the bar is ink")


func test_word_fully_typed_hides_the_underline() -> void:
	_word_setup()
	_hud.show_target("dad", 3)
	assert_eq(_typed().text, "dad")
	assert_true(_typed().visible)
	assert_false(_underline().visible)


func test_word_nothing_typed_underlines_the_first_letter() -> void:
	_word_setup()
	assert_false(_typed().visible, "setup shows the first word with 0 typed")
	assert_true(_underline().visible)
	assert_eq(_underline().position.x, 0.0)
	_hud.show_target("cat", 0)
	assert_false(_typed().visible)
	assert_eq(_typed().text, "")
	assert_eq(_underline().position.x, 0.0)


func test_word_typed_count_is_clamped() -> void:
	_word_setup()
	_hud.show_target("dad", 9)
	assert_eq(_typed().text, "dad")
	assert_false(_underline().visible)
	_hud.show_target("dad", -4)
	assert_false(_typed().visible)
	assert_eq(_underline().position.x, 0.0)


func test_word_hands_light_the_next_letter() -> void:
	_word_setup()
	assert_eq(_hands_lit(), [Vector2i(FingerMap.Hand.LEFT, FingerMap.Finger.MIDDLE)] as Array[Vector2i], "d")
	_hud.show_target("dad", 1)
	assert_eq(_hands_lit(), [Vector2i(FingerMap.Hand.LEFT, FingerMap.Finger.PINKY)] as Array[Vector2i], "a, not d")


func test_letter_mode_never_shows_word_progress() -> void:
	_letter_setup()
	assert_false(_typed().visible)
	assert_false(_underline().visible)
	_hud.show_target("k", 1)
	assert_false(_typed().visible)
	assert_false(_underline().visible)


## Story 8.2 replaces the 6.2 "paragraph mode never shows word progress" rule: paragraphs have their own
## overlay now (the paragraph section below).
func test_paragraph_mode_shows_progress_on_line_1() -> void:
	_hud.setup(_config(LevelConfig.TargetMode.PARAGRAPH), "the cat sat")
	_hud.show_target("the cat sat", 2)
	assert_true(_typed().visible)
	assert_eq(_typed().text, "th")
	assert_true(_underline().visible)


func test_word_shake_moves_the_overlay_with_the_word() -> void:
	_word_setup()
	_hud.show_target("dad", 1)
	var typed_before: Vector2 = _typed().global_position
	var bar_before: Vector2 = _underline().global_position
	_hud.shake_target()
	_hud._process(0.05)
	var offset: float = _hud.get_target_offset_x()
	assert_ne(offset, 0.0)
	assert_eq(_typed().global_position, typed_before + Vector2(offset, 0.0))
	assert_eq(_underline().global_position, bar_before + Vector2(offset, 0.0))


func test_word_live_wpm_counts_implied_spaces() -> void:
	_word_setup()
	_hud.update_clock(10.0, 50, 10)
	assert_eq(_text("%WpmValue"), str(StatsCalculator.wpm(50, 10.0, 10)))
	assert_ne(_text("%WpmValue"), str(StatsCalculator.wpm(50, 10.0)), "the spaces change the number")


# --- paragraph mode (Story 8.2) ---------------------------------------------------

## Passage 1 wraps to "The dog ran " / "up the big " / "hill. " (starts 0, 12, 23); passage 2 to
## "Zip woke " / "up. " (starts 0, 9). Written out by hand: the oracle is not ParagraphLayout.
const P1: String = "The dog ran up the big hill. "
const P2: String = "Zip woke up. "
const FINGER_MAP_PATH: String = "res://data/finger_map.tres"
const HAND_LEFT_PATH: String = "res://assets/sprites/ui/hands/ui_hand_left.png"
const HAND_RIGHT_PATH: String = "res://assets/sprites/ui/hands/ui_hand_right.png"


## The first row of the sprite with an opaque pixel.
func _first_opaque_row(path: String) -> int:
	var image: Image = (load(path) as Texture2D).get_image()
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				return y
	return image.get_height()


func _paragraph_setup(first: String = P1, next: String = P2) -> void:
	_hud.setup(_config(LevelConfig.TargetMode.PARAGRAPH), first, next)


func _paragraph_width(text: String) -> float:
	var font: Font = (_hud.get_node("%TargetLabel") as Label).get_theme_font("font")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, HudScript.PARAGRAPH_FONT_SIZE).x


func _marker() -> Control:
	return _hud.get_node("%SpaceMarker") as Control


## The marker's bottom edge in line 1's coordinates.
func _marker_cell_y() -> float:
	return _marker().position.y + _marker().size.y


func test_paragraph_window_at_the_start() -> void:
	_paragraph_setup()
	assert_eq(_text("%TargetLabel"), "The dog ran ")
	assert_eq(_text("%NextLineLabel"), "up the big ")
	assert_true(_node("%NextLineLabel").visible)
	assert_false(_typed().visible)
	assert_true(_underline().visible)
	assert_eq(_underline().position, Vector2(0.0, HudScript.PARAGRAPH_UNDERLINE_Y))
	assert_false(_marker().visible, "the join Space is 2 lines away")


func test_paragraph_window_mid_line() -> void:
	_paragraph_setup()
	_hud.show_target(P1, 5, P2)
	assert_eq(_text("%TargetLabel"), "The dog ran ")
	assert_eq(_typed().text, "The d", "the typed prefix of line 1")
	assert_true(_typed().visible)
	assert_eq(_underline().position.x, _paragraph_width("The d"), "under the 6th character")
	assert_eq(_underline().size, Vector2(_paragraph_width("o"), HudScript.UNDERLINE_PX))


func test_paragraph_window_scrolls_one_line() -> void:
	_paragraph_setup()
	_hud.show_target(P1, 12, P2)
	assert_eq(_text("%TargetLabel"), "up the big ", "the cursor's line is line 1")
	assert_eq(_text("%NextLineLabel"), "hill. ")
	assert_false(_typed().visible, "nothing typed on the new line yet")
	assert_eq(_underline().position.x, 0.0)
	assert_true(_marker().visible, "the last line is line 2")
	assert_eq(_marker().position.x, _paragraph_width("hill.") + HudScript.SPACE_MARKER_INSET_X)
	assert_eq(_marker_cell_y(), 24.0 + HudScript.SPACE_MARKER_BOTTOM, "inside line 2's cell")


func test_paragraph_last_line_shows_the_next_passage() -> void:
	_paragraph_setup()
	_hud.show_target(P1, 25, P2)
	assert_eq(_text("%TargetLabel"), "hill. ")
	assert_eq(_text("%NextLineLabel"), "Zip woke ", "line 2 is the next passage's first line")
	assert_eq(_typed().text, "hi")
	assert_true(_marker().visible)
	assert_eq(_marker().position.x, _paragraph_width("hill.") + HudScript.SPACE_MARKER_INSET_X)
	assert_eq(_marker_cell_y(), HudScript.SPACE_MARKER_BOTTOM, "inside line 1's cell")


func test_paragraph_cursor_on_the_join_space() -> void:
	_paragraph_setup()
	_hud.show_target(P1, P1.length() - 1, P2)
	assert_true(_underline().visible, "the join Space is underlined")
	assert_eq(_underline().position.x, _paragraph_width("hill."))
	assert_true(_marker().visible)
	var bar: Rect2 = Rect2(_underline().position, _underline().size)
	var marker: Rect2 = Rect2(_marker().position, _marker().size)
	assert_false(bar.intersects(marker), "the marker stays visible next to the underline")
	assert_true(marker.position.y >= 0.0 and marker.end.y <= 24.0, "the marker stays in its cell")
	assert_true(bar.position.y >= 0.0 and bar.end.y <= 24.0, "the underline never touches line 2")


func test_paragraph_next_passage_starts_on_a_fresh_line() -> void:
	_paragraph_setup()
	_hud.show_target(P2, 0, "")
	assert_eq(_text("%TargetLabel"), "Zip woke ")
	assert_eq(_text("%NextLineLabel"), "up. ")
	assert_false(_typed().visible)
	assert_eq(_marker_cell_y(), 24.0 + HudScript.SPACE_MARKER_BOTTOM)
	_hud.show_target(P2, 9, "")
	assert_eq(_text("%TargetLabel"), "up. ")
	assert_eq(_text("%NextLineLabel"), "", "no next passage known: line 2 is empty")


func test_paragraph_rects_fit_the_band() -> void:
	_paragraph_setup()
	var line1: Rect2 = _rect("%TargetLabel")
	var line2: Rect2 = _rect("%NextLineLabel")
	var hands: Rect2 = _rect("%HandsArea")
	var sign: Rect2 = _rect("%TargetSign")
	assert_eq(line1, Rect2(76, 262, 288, 24))
	assert_eq(line2, Rect2(76, 286, 288, 24))
	for rect: Rect2 in [line1, line2, hands, sign]:
		assert_true(rect.position.y >= 256.0 and rect.end.y <= 360.0, "%s in the band" % rect)
	assert_false(line1.intersects(line2), "line 1 and line 2 do not overlap")
	assert_true(sign.encloses(line1) and sign.encloses(line2), "both lines inside the sign")
	assert_true(line1.position.y > sign.position.y, "padding above line 1")
	assert_true(line2.end.y < sign.end.y, "padding below line 2")
	# The sign overhangs the hands area only over rows the hand sprites leave empty (read from the art).
	var art_top: int = mini(_first_opaque_row(HAND_LEFT_PATH), _first_opaque_row(HAND_RIGHT_PATH))
	assert_true(sign.end.y <= hands.position.y + art_top, "sign ends at %s, hand art starts at %s" % [
		sign.end.y, hands.position.y + art_top])


func test_paragraph_colours() -> void:
	_paragraph_setup()
	_hud.show_target(P1, 3, P2)
	var line2: Label = _hud.get_node("%NextLineLabel") as Label
	assert_eq(line2.get_theme_color(&"font_color"), Color("#8A7552"), "line 2 is ink-faded")
	assert_eq(_typed().get_theme_color(&"font_color"), Color("#2E6B26"), "typed is zombie-green-dark")
	var ink: Color = (_hud.get_node("%TargetLabel") as Label).get_theme_color(&"font_color")
	assert_eq(ink, Color("#1E1428"), "untyped is ink")
	assert_eq(_underline().color, ink)
	for part: Node in _marker().get_children():
		assert_eq((part as ColorRect).color, Color("#8A7552"), "the marker is ink-faded")
	assert_eq(_font_size(_typed()), 24)
	assert_eq((_hud.get_node("%TargetLabel") as Label).horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)


func test_paragraph_shake_moves_line_1_only() -> void:
	_paragraph_setup()
	_hud.show_target(P1, 25, P2)
	var line1_before: Vector2 = _node("%TargetLabel").global_position
	var marker_before: Vector2 = _marker().global_position
	var line2_before: Vector2 = _node("%NextLineLabel").global_position
	_hud.shake_target()
	_hud._process(0.05)
	var offset: float = _hud.get_target_offset_x()
	assert_ne(offset, 0.0)
	assert_eq(_node("%TargetLabel").global_position, line1_before + Vector2(offset, 0.0))
	assert_eq(_marker().global_position, marker_before + Vector2(offset, 0.0))
	assert_eq(_node("%NextLineLabel").global_position, line2_before, "line 2 stays still")


## The expected fingers straight from finger_map.tres entries (hand, finger, shift): the character's
## finger, plus the other hand's pinky when shifted, or the other thumb for a thumb key. Sorted.
func _expected_fingers(c: String) -> Array[Vector2i]:
	var entries: Dictionary = (load(FINGER_MAP_PATH) as FingerMap).entries
	assert_true(entries.has(c), "'%s' is mapped" % c)
	var entry: Vector3i = entries[c]
	var other: int = 1 - entry.x
	var fingers: Array[Vector2i] = [Vector2i(entry.x, entry.y)]
	if entry.y == FingerMap.Finger.THUMB:
		fingers.append(Vector2i(other, FingerMap.Finger.THUMB))
	elif entry.z == 1:
		fingers.append(Vector2i(other, FingerMap.Finger.PINKY))
	fingers.sort()
	return fingers


func _lit_sorted() -> Array[Vector2i]:
	var lit: Array[Vector2i] = _hands_lit()
	lit.sort()
	return lit


func _sorted(fingers: Array[Vector2i]) -> Array[Vector2i]:
	fingers.sort()
	return fingers


func test_paragraph_hands_capitals_symbols_digits_and_space() -> void:
	var text: String = "Tim ran! It was 3. Yes, ok. "
	_paragraph_setup(text, "")
	assert_eq(_lit_sorted(), _expected_fingers("T"), "T")
	assert_eq(_lit_sorted(), _sorted([Vector2i(FingerMap.Hand.LEFT, FingerMap.Finger.INDEX),
			Vector2i(FingerMap.Hand.RIGHT, FingerMap.Finger.PINKY)]), "T = left index + right pinky")
	var checks: Dictionary[String, int] = {
		"!": text.find("!"), ".": text.find("."), ",": text.find(","), "3": text.find("3"), " ": 3,
	}
	for c: String in checks:
		_hud.show_target(text, checks[c], "")
		assert_eq(_lit_sorted(), _expected_fingers(c), "'%s'" % c)
	_hud.show_target(text, text.find("!"), "")
	assert_eq(_lit_sorted(), _sorted([Vector2i(FingerMap.Hand.LEFT, FingerMap.Finger.PINKY),
			Vector2i(FingerMap.Hand.RIGHT, FingerMap.Finger.PINKY)]), "! is on the 1 key: both pinkies")
	_hud.show_target(text, text.find("."), "")
	assert_eq(_hands_lit().size(), 1, "an unshifted symbol lights its finger alone")
	_hud.show_target(text, text.length() - 1, "")
	assert_eq(_lit_sorted(), _sorted([Vector2i(FingerMap.Hand.LEFT, FingerMap.Finger.THUMB),
			Vector2i(FingerMap.Hand.RIGHT, FingerMap.Finger.THUMB)]), "the join Space lights both thumbs")


func test_paragraph_then_word_setup_restores_word_mode() -> void:
	_paragraph_setup()
	_hud.show_target(P1, 25, P2)
	_word_setup("dad")
	var target: Label = _hud.get_node("%TargetLabel") as Label
	assert_eq(_font_size(target), 32)
	assert_eq(_font_size(_typed()), 32)
	assert_eq(target.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_false(_node("%NextLineLabel").visible)
	assert_false(_marker().visible)
	assert_eq(_text("%TargetLabel"), "dad")
	_hud.show_target("dad", 1)
	assert_eq(_underline().position.y, HudScript.LINE_FONT_SIZE + HudScript.UNDERLINE_GAP, "word underline as before")
	assert_eq(_underline().position.x, _glyph_width("d"))
	var word_sign: Rect2 = _rect("%TargetSign")
	_letter_setup()
	assert_eq(_font_size(target), 32)
	assert_false(_node("%NextLineLabel").visible)
	assert_false(_marker().visible)
	var letter_sign: Rect2 = _rect("%TargetSign")
	_hud.setup(_config(LevelConfig.TargetMode.LETTER), "f")
	assert_eq(_rect("%TargetSign"), letter_sign, "the letter sign as before")
	assert_ne(word_sign, Rect2(68, 260, 304, 52), "the word sign is not the paragraph sign")


func test_every_tier_5_character_has_a_glyph() -> void:
	var font: Font = (load(THEME_PATH) as Theme).default_font
	var chars: String = ParagraphRules.allowed_chars(5)
	assert_gt(chars.length(), 0)
	for i: int in chars.length():
		assert_true(font.has_char(chars.unicode_at(i)), "glyph '%s'" % chars[i])
