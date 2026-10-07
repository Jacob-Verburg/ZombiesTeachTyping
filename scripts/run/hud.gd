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
const PARAGRAPH_SIGN: Rect2 = Rect2(4, 4, 304, 48)
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


func _ready() -> void:
	%PauseButton.pressed.connect(_on_pause_button_pressed)


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
## placeholder, Keys / Errors / brains at 0, Caps Lock hint hidden.
func setup(config: LevelConfig, first_target: String) -> void:
	_mode = config.target_mode
	_duration = config.duration_s
	_line_count = PARAGRAPH_LINES if _mode == LevelConfig.TargetMode.PARAGRAPH else 1
	var target: Label = %TargetLabel
	if _mode == LevelConfig.TargetMode.PARAGRAPH:
		target.add_theme_font_size_override("font_size", PARAGRAPH_FONT_SIZE)
		target.add_theme_constant_override("line_spacing", 0)
		target.max_lines_visible = PARAGRAPH_LINES
	else:
		target.add_theme_font_size_override("font_size", LINE_FONT_SIZE)
		target.max_lines_visible = 1
	_show_prompt(PROMPTS.get(_mode, PROMPTS[LevelConfig.TargetMode.LETTER]))
	%CapsHint.visible = false
	_shake_left = 0.0
	_shake_offset = 0.0
	_shown_seconds = -1
	_wpm_tick = -1
	%WpmValue.text = WPM_PLACEHOLDER
	set_counts(0, 0)
	set_brains(0)
	show_target(first_target)
	update_clock(0.0, 0)


## Shows the current target with `typed` of its letters done (RunFrame, on every correct key; setup() for
## the first one) and lights the next letter's finger on the zombie hands. In word mode the sign grows
## with the word, the typed letters turn green and the next letter is underlined; other modes never
## show either (paragraph rendering is Story 8.2).
func show_target(target: String, typed: int = 0) -> void:
	typed = clampi(typed, 0, target.length())
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
		target.size = Vector2(PARAGRAPH_SIGN.size.x - 2.0 * SIGN_PAD_X, PARAGRAPH_SIGN.size.y)
		target.position = Vector2(SIGN_PAD_X, 0.0)
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
