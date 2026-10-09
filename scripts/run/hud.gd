extends Control
## The shared HUD band every level uses (GDD Pillar 4, UX D15): pet slot, target sign with the green
## zombie hands finger guide below it (%ZombieHands, Story 2.6), stats column (Timer, Keys, WPM,
## Errors) and the brain counter, plus the start prompt, the Caps Lock hint and the pause button in
## the playfield. Layout: the approved Story 2.5 sketch (ux-designs/.../sketches/hud-band-2-5.md).
## A view only: RunFrame calls down; the HUD never reads input, never touches the TypingSession, the
## clock or any autoload except Log, and only emits pause_pressed. The %Pet slot on the cushion (Story 4.3)
## is a cosmetics widget that listens to PlayerData by itself (Boundary 2); this script still doesn't.
## Story 5.0 art: the HudBand, Sign, Chalkboard, CandySign and InkStrip theme boxes (9-slices, so the target
## sign still stretches to 48 x 40, n x 32 + 16 x 40 and 304 x 48), the pet cushion and the round pause button.
## Word mode (Story 6.2): %TargetLabel keeps the whole word in ink; %TypedLabel paints the typed letters
## over it in zombie-green-dark and %NextUnderline marks the next letter. Both are %TargetLabel's children,
## so the wrong-key shake moves them with the word.
## Paragraph mode (Story 8.2, FR69): ParagraphLayout wraps the passage into 12-character lines. %TargetLabel
## shows line 1 (the cursor's line) in ink with the green %TypedLabel prefix and the %NextUnderline bar under
## the next character; %NextLineLabel shows line 2 in ink-faded: the passage's next line, or on its last line
## the next passage's first line. %SpaceMarker (a shape-drawn bracket, a %TargetLabel child) marks the join
## Space on whichever shown line holds it. The shake moves line 1 with its overlay and marker; line 2 stays.

## Emitted when the pause button is clicked. Pausing itself is Story 2.7.
signal pause_pressed

## The waiting prompt by target mode (EXPERIENCE.md Voice and Tone).
const PROMPTS: Dictionary[LevelConfig.TargetMode, String] = {
	LevelConfig.TargetMode.LETTER: "Type the letter to start!",
	LevelConfig.TargetMode.WORD: "Type the word to start!",
	LevelConfig.TargetMode.PARAGRAPH: "Type the text to start!",
}
## Shown instead of the live WPM until it is due (en dash; Press Start 2P has the glyph).
const WPM_PLACEHOLDER: String = "–"
## Wrong-key shake amplitude in px (EXPERIENCE.md Game Feel, a UX assumption owned by the HUD).
const SHAKE_PX: float = 2.0

## Target sign layout, in %TargetArea coordinates (sketch table).
const TARGET_CENTRE_X: float = 156.0
const SIGN_TOP: float = 4.0
const SIGN_PAD_X: float = 8.0
const SIGN_PAD_Y: float = 4.0
const LINE_FONT_SIZE: int = 32
const PARAGRAPH_FONT_SIZE: int = 24
const PARAGRAPH_LINES: int = 2
## Story 8.2 visual gate (Smuck: "lets add a little padding"): the sign is 52 px, not 48. The 4 extra rows
## overhang the top of %HandsArea, which the hand sprites leave empty (their art starts at row 4).
const PARAGRAPH_SIGN: Rect2 = Rect2(4, 4, 304, 52)
## y of line 1 inside the paragraph sign; line 2 sits one line below it. 2 px of parchment sit above the
## capitals, and line 2's descenders stay above the sign's bottom frame.
const PARAGRAPH_LINE_TOP: float = 2.0
## Start prompt strip, in HUD coordinates: centred on the target area's centre (x 220).
const PROMPT_CENTRE_X: float = 220.0
const PROMPT_PAD: float = 4.0
const PROMPT_FONT_SIZE: int = 16
## Word mode next-letter cue: UX DESIGN.md "2 px ink bar" (a shape cue, not colour alone, NFR8). The gap is
## a HUD-owned layout value: px below the 32 px text line. Tuned from the Story 6.2 screenshot: the bar sits
## 4 px under the baseline, right under the g j p q y descenders, with 1 px of parchment above the sign's
## dark bottom edge. A gap of 1 would fuse the bar with that edge, so 0 is the only clear spot in 40 px.
const UNDERLINE_PX: float = 2.0
const UNDERLINE_GAP: float = 0.0
## DESIGN.md target-paragraph tokens (HUD-owned layout values, tuned from the Story 8.2 screenshot). Lines are
## PARAGRAPH_FONT_SIZE tall with no spare row, so the 2 px next-character bar sits inside line 1's cell (y 22-24)
## and never touches line 2.
const PARAGRAPH_UNDERLINE_Y: float = 22.0
## Width of a paragraph line inside the sign's 8 px side padding: 12 characters x 24 px.
const PARAGRAPH_LINE_WIDTH: float = 288.0
## The join Space marker, a "␣"-style bracket in ink-faded, drawn with shapes (the font has no ␣ glyph): a bar
## and two uprights, inset in its 24 px cell and ending above the underline so both stay visible.
const SPACE_MARKER_BAR_PX: float = 2.0
const SPACE_MARKER_POST_PX: float = 6.0
const SPACE_MARKER_INSET_X: float = 4.0
## y of the marker's bottom edge inside its line's cell.
const SPACE_MARKER_BOTTOM: float = 20.0
## DESIGN.md ink-faded: line 2 and the space marker.
const INK_FADED: Color = Color("#8A7552")
## A shake whose remaining time is below this has ended (float sums of frame deltas).
const _SHAKE_DONE_S: float = 1e-6

var _mode: LevelConfig.TargetMode = LevelConfig.TargetMode.LETTER
var _duration: float = 0.0
var _line_count: int = 1
var _shown_seconds: int = -1
var _wpm_tick: int = -1
var _shake_left: float = 0.0
var _shake_offset: float = 0.0
var _label_base_x: float = 0.0
## ParagraphLayout.wrap results by target string (a passage only changes at a completion).
var _wrap_cache: Dictionary[String, PackedInt32Array] = {}


func _ready() -> void:
	%PauseButton.pressed.connect(_on_pause_button_pressed)
	_shape_space_marker()


## The marker's bracket from the SPACE_MARKER_* tokens: two uprights and the bar along their feet.
func _shape_space_marker() -> void:
	var width: float = float(PARAGRAPH_FONT_SIZE) - 2.0 * SPACE_MARKER_INSET_X
	var marker: Control = %SpaceMarker
	marker.size = Vector2(width, SPACE_MARKER_POST_PX)
	var rects: Dictionary[String, Rect2] = {
		"LeftPost": Rect2(0.0, 0.0, SPACE_MARKER_BAR_PX, SPACE_MARKER_POST_PX),
		"RightPost": Rect2(width - SPACE_MARKER_BAR_PX, 0.0, SPACE_MARKER_BAR_PX, SPACE_MARKER_POST_PX),
		"Bar": Rect2(0.0, SPACE_MARKER_POST_PX - SPACE_MARKER_BAR_PX, width, SPACE_MARKER_BAR_PX),
	}
	for part: String in rects:
		var rect: ColorRect = marker.get_node(part) as ColorRect
		rect.position = rects[part].position
		rect.size = rects[part].size
		rect.color = INK_FADED


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	if _shake_left <= _SHAKE_DONE_S:
		_shake_left = 0.0
		_set_shake_offset(0.0)
		return
	# Four equal slices of the shake: +, -, +, -.
	var progress: float = (GameConstants.WRONG_KEY_SHAKE_S - _shake_left) / GameConstants.WRONG_KEY_SHAKE_S
	var slice: int = clampi(floori(progress * 4.0), 0, 3)
	_set_shake_offset(SHAKE_PX if slice % 2 == 0 else -SHAKE_PX)


## Prepares the HUD for a new run (RunFrame, once the session exists): sizes the target area for the
## level's target mode, shows the first target and the start prompt, Timer at the full length, WPM
## placeholder, Keys / Errors / brains at 0, Caps Lock hint hidden. `next_target` is the passage after the
## first one (paragraph mode only). setup() may run again on the same HUD, so every mode sets every
## property it relies on.
func setup(config: LevelConfig, first_target: String, next_target: String = "") -> void:
	_mode = config.target_mode
	_duration = config.duration_s
	_line_count = PARAGRAPH_LINES if _mode == LevelConfig.TargetMode.PARAGRAPH else 1
	_wrap_cache.clear()
	var target: Label = %TargetLabel
	var typed: Label = %TypedLabel
	target.autowrap_mode = TextServer.AUTOWRAP_OFF
	target.clip_text = false
	target.max_lines_visible = 1
	typed.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _mode == LevelConfig.TargetMode.PARAGRAPH:
		target.add_theme_font_size_override("font_size", PARAGRAPH_FONT_SIZE)
		target.add_theme_constant_override("line_spacing", 0)
		target.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		typed.add_theme_font_size_override("font_size", PARAGRAPH_FONT_SIZE)
	else:
		target.add_theme_font_size_override("font_size", LINE_FONT_SIZE)
		target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		typed.add_theme_font_size_override("font_size", LINE_FONT_SIZE)
		%NextLineLabel.visible = false
		%NextLineLabel.text = ""
		%SpaceMarker.visible = false
	_show_prompt(PROMPTS.get(_mode, PROMPTS[LevelConfig.TargetMode.LETTER]))
	%CapsHint.visible = false
	_shake_left = 0.0
	_shake_offset = 0.0
	_shown_seconds = -1
	_wpm_tick = -1
	%WpmValue.text = WPM_PLACEHOLDER
	set_counts(0, 0)
	set_brains(0)
	show_target(first_target, 0, next_target)
	update_clock(0.0, 0)


## Shows the current target with `typed` of its letters done (RunFrame, on every correct key; setup() for
## the first one) and lights the next letter's finger on the zombie hands. In word mode the sign grows
## with the word, the typed letters turn green and the next letter is underlined; letter mode shows
## neither. Paragraph mode shows the 2-line window; `next_target` (the next passage) feeds its line 2.
func show_target(target: String, typed: int = 0, next_target: String = "") -> void:
	typed = clampi(typed, 0, target.length())
	if _mode == LevelConfig.TargetMode.PARAGRAPH:
		_show_paragraph(target, typed, next_target)
	else:
		%TargetLabel.text = target
		_layout_target()
		_show_word_progress(target, typed)
	%ZombieHands.show_char(target.substr(typed, 1))


## Stops the finger guide (RunFrame, when the run ends: input is off, so no key is expected).
func clear_hands() -> void:
	%ZombieHands.show_char("")


## Keys Typed and Errors (RunFrame, in the same call as each judgment).
func set_counts(keys: int, errors: int) -> void:
	%KeysValue.text = str(keys)
	%ErrorsValue.text = str(errors)


## The level's brain total for this run (RunFrame, on LevelBase.brains_earned_changed).
func set_brains(total: int) -> void:
	%BrainCounter.set_count(total)


## Hides the start prompt (RunFrame, on the first correct key).
func hide_start_prompt() -> void:
	%StartPrompt.visible = false


## Called every frame by RunFrame with the run clock's elapsed time. Timer counts down (shown rounded
## up, so it never reads 0:00 while time is left), or up when the level has no duration. Live WPM is
## hidden for LIVE_WPM_DELAY_S of run time, then refreshes once per LIVE_WPM_INTERVAL_S (FR8).
## Strings are rebuilt only when the shown value changes.
## `implied_spaces` are word mode's completed words (FR7), counted as typed Spaces.
func update_clock(elapsed: float, keys: int, implied_spaces: int = 0) -> void:
	if not is_finite(elapsed):
		return
	var shown: int = ceili(maxf(0.0, _duration - elapsed)) if _duration > 0.0 else floori(maxf(0.0, elapsed))
	if shown != _shown_seconds:
		_shown_seconds = shown
		%TimerValue.text = StatsCalculator.format_time(float(shown))
	if elapsed < GameConstants.LIVE_WPM_DELAY_S:
		return
	var tick: int = floori(elapsed / GameConstants.LIVE_WPM_INTERVAL_S)
	if tick != _wpm_tick:
		_wpm_tick = tick
		%WpmValue.text = str(StatsCalculator.wpm(keys, elapsed, implied_spaces))


## Wrong key (FR2): only the target glyph shakes, ±SHAKE_PX for WRONG_KEY_SHAKE_S; a new wrong key
## restarts it. No colour change, nothing else moves.
func shake_target() -> void:
	_shake_left = GameConstants.WRONG_KEY_SHAKE_S
	_set_shake_offset(SHAKE_PX)


## Shows or hides the "Caps Lock is on" hint (RunFrame, on TypingInput's Caps Lock signals). Never blocks typing.
func set_caps_hint(shown: bool) -> void:
	%CapsHint.visible = shown


## Lines in the target area: 1 for letter and word targets, 2 for paragraphs.
func get_target_line_count() -> int:
	return _line_count


## The target glyph's current shake offset in px (0 when still).
func get_target_offset_x() -> float:
	return _shake_offset


func _layout_target() -> void:
	var target: Label = %TargetLabel
	var sign_panel: Control = %TargetSign
	if _mode == LevelConfig.TargetMode.PARAGRAPH:
		sign_panel.position = PARAGRAPH_SIGN.position
		sign_panel.size = PARAGRAPH_SIGN.size
		target.size = Vector2(PARAGRAPH_LINE_WIDTH, PARAGRAPH_FONT_SIZE)
		target.position = Vector2(SIGN_PAD_X, PARAGRAPH_LINE_TOP)
	else:
		var font: Font = target.get_theme_font("font")
		var text_width: float = font.get_string_size(
				target.text, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FONT_SIZE).x
		text_width = maxf(text_width, float(LINE_FONT_SIZE))
		var width: float = text_width + 2.0 * SIGN_PAD_X
		sign_panel.position = Vector2(TARGET_CENTRE_X - width / 2.0, SIGN_TOP)
		sign_panel.size = Vector2(width, LINE_FONT_SIZE + 2.0 * SIGN_PAD_Y)
		target.size = Vector2(text_width, LINE_FONT_SIZE)
		target.position = Vector2(SIGN_PAD_X, SIGN_PAD_Y)
	_label_base_x = target.position.x
	_set_shake_offset(_shake_offset)


## Green typed prefix and the underline under letter `typed`, measured with the target font. The target
## label is exactly as wide as its text, so its glyphs start at x 0 and the overlay lines up with them.
func _show_word_progress(target: String, typed: int) -> void:
	var typed_label: Label = %TypedLabel
	var underline: ColorRect = %NextUnderline
	if _mode != LevelConfig.TargetMode.WORD:
		typed_label.visible = false
		typed_label.text = ""
		underline.visible = false
		return
	var font: Font = (%TargetLabel as Label).get_theme_font("font")
	var done: String = target.left(typed)
	var done_width: float = font.get_string_size(done, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FONT_SIZE).x
	typed_label.text = done
	typed_label.position = Vector2.ZERO
	typed_label.size = Vector2(done_width, LINE_FONT_SIZE)
	typed_label.visible = typed > 0
	underline.visible = typed < target.length()
	if underline.visible:
		var next_width: float = font.get_string_size(
				target.substr(typed, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FONT_SIZE).x
		underline.position = Vector2(done_width, LINE_FONT_SIZE + UNDERLINE_GAP)
		underline.size = Vector2(next_width, UNDERLINE_PX)


## The 2-line window: line 1 is the line holding the cursor (green typed prefix, underlined next character),
## line 2 the next line or the next passage's first line, and the join Space marker on whichever shows it.
func _show_paragraph(target: String, typed: int, next_target: String) -> void:
	var target_label: Label = %TargetLabel
	var starts: PackedInt32Array = _wrap(target)
	var line: int = ParagraphLayout.line_of(starts, typed)
	var line_text: String = _line_text(target, starts, line)
	target_label.text = line_text
	_layout_target()
	var font: Font = target_label.get_theme_font("font")
	var column: int = typed - starts[line]
	var done: String = line_text.left(column)
	var done_width: float = _paragraph_width(font, done)
	var typed_label: Label = %TypedLabel
	typed_label.text = done
	typed_label.position = Vector2.ZERO
	typed_label.size = Vector2(done_width, PARAGRAPH_FONT_SIZE)
	typed_label.visible = done != ""
	var underline: ColorRect = %NextUnderline
	underline.visible = typed < target.length()
	if underline.visible:
		underline.position = Vector2(done_width, PARAGRAPH_UNDERLINE_Y)
		underline.size = Vector2(_paragraph_width(font, line_text.substr(column, 1)), UNDERLINE_PX)
	var next_line: Label = %NextLineLabel
	if line + 1 < starts.size():
		next_line.text = _line_text(target, starts, line + 1)
	elif next_target != "":
		next_line.text = _line_text(next_target, _wrap(next_target), 0)
	else:
		next_line.text = ""
	next_line.position = Vector2(SIGN_PAD_X, PARAGRAPH_LINE_TOP + PARAGRAPH_FONT_SIZE)
	next_line.size = Vector2(PARAGRAPH_LINE_WIDTH, PARAGRAPH_FONT_SIZE)
	next_line.visible = true
	_place_space_marker(target, starts, line, font)


## The marker sits in the join Space's cell when the passage's last line is line 1 (y 0) or line 2 (y 24).
func _place_space_marker(target: String, starts: PackedInt32Array, line: int, font: Font) -> void:
	var marker: Control = %SpaceMarker
	var last: int = starts.size() - 1
	if not target.ends_with(ParagraphSource.JOIN) or line < last - 1:
		marker.visible = false
		return
	var last_text: String = _line_text(target, starts, last)
	var x: float = _paragraph_width(font, last_text.left(last_text.length() - 1))
	var y: float = 0.0 if line == last else float(PARAGRAPH_FONT_SIZE)
	marker.position = Vector2(x + SPACE_MARKER_INSET_X, y + SPACE_MARKER_BOTTOM - SPACE_MARKER_POST_PX)
	marker.visible = true


func _wrap(text: String) -> PackedInt32Array:
	if not _wrap_cache.has(text):
		if _wrap_cache.size() >= 4:
			_wrap_cache.clear()
		_wrap_cache[text] = ParagraphLayout.wrap(text)
	return _wrap_cache[text]


static func _line_text(text: String, starts: PackedInt32Array, line: int) -> String:
	var end: int = starts[line + 1] if line + 1 < starts.size() else text.length()
	return text.substr(starts[line], end - starts[line])


static func _paragraph_width(font: Font, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PARAGRAPH_FONT_SIZE).x


func _show_prompt(text: String) -> void:
	var label: Label = %StartPromptLabel
	label.text = text
	var font: Font = label.get_theme_font("font")
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PROMPT_FONT_SIZE).x
	var strip: Control = %StartPrompt
	strip.size = Vector2(text_width + 2.0 * PROMPT_PAD, PROMPT_FONT_SIZE + 2.0 * PROMPT_PAD)
	strip.position = Vector2(PROMPT_CENTRE_X - strip.size.x / 2.0, strip.position.y)
	label.position = Vector2(PROMPT_PAD, PROMPT_PAD)
	label.size = Vector2(text_width, PROMPT_FONT_SIZE)
	strip.visible = true


func _set_shake_offset(offset: float) -> void:
	_shake_offset = offset
	%TargetLabel.position.x = _label_base_x + offset


func _on_pause_button_pressed() -> void:
	pause_pressed.emit()
