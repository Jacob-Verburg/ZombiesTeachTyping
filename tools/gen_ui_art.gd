extends SceneTree
## Dev-only: writes the Story 5.0 MVP UI art (every sheet in the story's "UI sheet list"; the table in
## docs/art-style-sheet.md section 7 and tests/unit/test_art_ui.gd's UI_SHEETS follow it).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_ui_art.gd
## then --import, so the .png.import files are written (Lossless, no mipmaps; Nearest is the project default).
##
## Same method as tools/gen_zombie_run_art.gd: small pieces are ASCII maps (one character per pixel, '.' =
## transparent, a legend maps a character to a palette NAME read from tools/gen_art_prototypes.gd); large
## pieces (9-slice sources, panels, the level card pictures) are drawn from shapes at fixed positions (no
## randomness, so a rerun writes the same bytes). Symmetric maps are written as their left half and mirrored.
## Shapes are masks: a mask is painted with a 1 px ink outline (every mask pixel with a 4-neighbour outside
## the mask is ink), which keeps the outline rule by construction.
## Hand-lettered signs (the logo, "Coming soon", "New best!", "Crypt Closet") use the small alphabet in
## GLYPHS: a design grid, each design pixel drawn as a scale x scale block, then outlined in ink with a 1 px
## highlight on top. It is a sprite alphabet for fixed sign text only, never a second font.
## Pre-rotated pieces (the plank, the stamp) are rotated by three shears (whole rows and columns move, so
## no pixel is resampled or lost), then the outline is re-closed.
## Rules: docs/art-style-sheet.md; tests: test_art_ui.gd.

const Proto := preload("res://tools/gen_art_prototypes.gd")

const UI_DIR: String = "res://assets/sprites/ui"
const COMMON: String = UI_DIR + "/common/"
const HUD: String = UI_DIR + "/hud/"
const HANDS: String = UI_DIR + "/hands/"
const MENU: String = UI_DIR + "/menu/"
const CLOSET: String = UI_DIR + "/closet/"
const REPORT: String = UI_DIR + "/report_card/"

const ZOMBIE_IDLE: String = "res://assets/sprites/characters/zombie/zombie_idle.png"
const ZOMBIE_WALK: String = "res://assets/sprites/characters/zombie/zombie_walk.png"
const VILLAGER_WAVE: String = "res://assets/sprites/characters/villager/villager_wave.png"

## Corner insets per row from the top (and bottom) edge: DESIGN.md Shapes.
const SQUARE: Array[int] = []
const ROUND_SM: Array[int] = [1]
const ROUND_MD: Array[int] = [2, 1]
const ROUND_LG: Array[int] = [4, 2, 1, 1]

## The hand-lettered alphabet, on a design grid: 9 rows (cap height 7, x-height 5 from row 2, descenders
## rows 7-8), '#' = stroke. Only the letters the four signs need.
const GLYPHS: Dictionary[String, Array] = {
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####", ".....", "....."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..", ".....", "....."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###.", ".....", "....."],
	"N": ["#...#", "##..#", "##..#", "#.#.#", "#..##", "#..##", "#...#", ".....", "....."],
	"o": ["....", "....", ".##.", "#..#", "#..#", "#..#", ".##.", "....", "...."],
	"m": [".....", ".....", "##.#.", "#.#.#", "#.#.#", "#.#.#", "#.#.#", ".....", "....."],
	"b": ["#...", "#...", "###.", "#..#", "#..#", "#..#", "###.", "....", "...."],
	"i": ["#", ".", "#", "#", "#", "#", "#", ".", "."],
	"e": ["....", "....", ".##.", "#..#", "####", "#...", ".###", "....", "...."],
	"s": ["....", "....", ".###", "#...", ".##.", "...#", "###.", "....", "...."],
	"a": ["....", "....", ".##.", "...#", ".###", "#..#", ".###", "....", "...."],
	"c": ["....", "....", ".###", "#...", "#...", "#...", ".###", "....", "...."],
	"h": ["#...", "#...", "###.", "#..#", "#..#", "#..#", "#..#", "....", "...."],
	"y": ["....", "....", "#..#", "#..#", "#..#", "#..#", ".###", "...#", "###."],
	"p": ["....", "....", "###.", "#..#", "#..#", "#..#", "###.", "#...", "#..."],
	"n": ["....", "....", "###.", "#..#", "#..#", "#..#", "#..#", "....", "...."],
	"g": ["....", "....", ".###", "#..#", "#..#", "#..#", ".###", "...#", "###."],
	"w": [".....", ".....", "#...#", "#...#", "#.#.#", "#.#.#", ".#.#.", ".....", "....."],
	"t": [".#.", ".#.", "###", ".#.", ".#.", ".#.", "..#", "...", "..."],
	"r": ["....", "....", "#.##", "##..", "#...", "#...", "#...", "....", "...."],
	"l": ["#.", "#.", "#.", "#.", "#.", "#.", ".#", "..", ".."],
	"!": ["#", "#", "#", "#", "#", ".", "#", ".", "."],
}
const GLYPH_ROWS: int = 9
## Design px between letters (tight, DESIGN.md "tuned letter-spacing") and for a space.
const LETTER_GAP: int = 1
const SPACE_W: int = 3
## Per-letter baseline bounce for the hand-made look, in px (cycled by letter index).
const BOUNCE: Array[int] = [0, -1, 1, 0, 1, -1, 0, 1]

## --- small maps: legends ---
const ICON_LEGEND: Dictionary[String, String] = {"k": "ink", "c": "chalk"}
const BRAIN_LEGEND: Dictionary[String, String] = {
	"k": "ink", "p": "art-brain-pink", "s": "art-brain-shade", "w": "chalk",
}
const BAT_LEGEND: Dictionary[String, String] = {"k": "ink", "p": "bat-purple", "d": "dusk", "w": "chalk"}
## Half the tutorial arrow's shaft thickness, px.
const SHAFT_HALF: float = 4.0
const CHECK_LEGEND: Dictionary[String, String] = {"k": "ink", "g": "zombie-green-dark"}
const LOCKED_LEGEND: Dictionary[String, String] = {"k": "ink", "m": "ink-muted"}
## Toggle icons: 'c' is the icon colour (on: zombie-green-bright, off: stone-light).
const TOGGLE_ON: Dictionary[String, String] = {"k": "ink", "c": "zombie-green-bright"}
const TOGGLE_OFF: Dictionary[String, String] = {"k": "ink", "c": "stone-light"}

## Brain icon, 16 x 16, left half (mirrored): two lobes, a shade seam and folds. Cute, no anatomy.
const BRAIN_SMALL_HALF: Array[String] = [
	"........",
	"........",
	"..kkkkk.",
	".kpppppk",
	"kpppppps",
	"kpssppps",
	"kpppspps",
	"kpppppps",
	"kpsspppp",
	"kppsppps",
	"kpppppps",
	".kpsspps",
	".kppppps",
	"..kkpppp",
	"....kkkk",
	"........",
]

## Brain icon, 32 x 32, left half: a separate drawing (bigger folds, a smiling face). Cute, no anatomy.
const BRAIN_BIG_HALF: Array[String] = [
	"................",
	"................",
	"................",
	"........kkkkkk..",
	"......kkppppppk.",
	".....kpppppppppk",
	"....kpppsssppppk",
	"...kppppppsppppk",
	"..kpppsppppppppk",
	"..kppsppppsssppk",
	".kpppsppppppsppk",
	".kppppppsppppppk",
	".kpsspppsppppsps",
	"kppppspppppppsps",
	"kpppppppkkppppps",
	"kpppppppkkpppppp",
	"kpsspppppppppppp",
	"kppspppppppppppp",
	"kppppppsppppkppp",
	"kpppppsspppppkkk",
	".kppppppppppppps",
	".kpsspppsppppppp",
	".kppsppppssppppp",
	"..kppppppppppsps",
	"..kkppppsppppsps",
	"...kkpppsppppppp",
	".....kkpppppppps",
	".......kkkkkkkkk",
	"................",
	"................",
	"................",
	"................",
]

## Toggle icons, 20 x 20, one map each; 'c' takes the on / off colour.
const ICON_MUSIC: Array[String] = [
	"....................",
	"....................",
	"..........kkkkkkk...",
	"..........kcccccck..",
	"..........kccccccck.",
	"..........kckkkccck.",
	"..........kck..kcck.",
	"..........kck...kk..",
	"..........kck.......",
	"..........kck.......",
	"..........kck.......",
	"......kkkkkck.......",
	".....kcccccck.......",
	"....kccccccck.......",
	"....kccccccck.......",
	"....kccccccck.......",
	".....kcccccck.......",
	"......kkkkkk........",
	"....................",
	"....................",
]
## The fullscreen icon's top-left quarter (10 x 10), mirrored both ways: four corner brackets.
const ICON_FULLSCREEN_QUARTER: Array[String] = [
	"..........",
	".kkkkkkk..",
	".kcccccck.",
	".kcccccck.",
	".kcckkkk..",
	".kcck.....",
	".kcck.....",
	".kkkk.....",
	"..........",
	"..........",
]

## Pause icon, 12 x 12: two chalk bars.
const ICON_PAUSE: Array[String] = [
	"............",
	".kkkk..kkkk.",
	".kcck..kcck.",
	".kcck..kcck.",
	".kcck..kcck.",
	".kcck..kcck.",
	".kcck..kcck.",
	".kcck..kcck.",
	".kcck..kcck.",
	".kcck..kcck.",
	".kkkk..kkkk.",
	"............",
]

## The Wearing check, 12 x 10.
const CHECK: Array[String] = [
	"........kkk.",
	".......kggk.",
	"......kggk..",
	"kkk..kggk...",
	"kggkkggk....",
	".kggggk.....",
	"..kggk......",
	"...kk.......",
	"............",
	"............",
]

## The locked tile's "?" silhouette, 32 x 32, left half... not symmetric, so a full map.
const LOCKED_Q: Array[String] = [
	"................................",
	"................................",
	"................................",
	"...........kkkkkkkkk............",
	".........kkmmmmmmmmmkk..........",
	"........kmmmmmmmmmmmmmk.........",
	".......kmmmmmkkkkkmmmmmk........",
	".......kmmmmk.....kmmmmk........",
	".......kmmmk......kmmmmk........",
	".......kkkkk......kmmmmk........",
	"..................kmmmmk........",
	".................kmmmmk.........",
	"................kmmmmk..........",
	"...............kmmmmk...........",
	"..............kmmmmk............",
	".............kmmmmk.............",
	".............kmmmmk.............",
	".............kmmmmk.............",
	".............kkkkkk.............",
	"................................",
	".............kkkkkk.............",
	".............kmmmmk.............",
	".............kmmmmk.............",
	".............kmmmmk.............",
	".............kkkkkk.............",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]

## Story 6.8: the Locked level card's big padlock, 32 x 40, left half. stone-light shackle and body, a stone
## shade, ink outline and keyhole (never candy-yellow or stamp-red: Locked is not an error).
const PADLOCK_HALF: Array[String] = [
	"..........kkkkkk",
	"........kkllllll",
	".......kllllllll",
	"......kllllkkkkk",
	"......kllsk.....",
	"......kllsk.....",
	"......kllsk.....",
	"......kllsk.....",
	"......kllsk.....",
	"......kllsk.....",
	"......kllsk.....",
	"......kllsk.....",
	"......kllsk.....",
	"......kllsk.....",
	"......kllsk.....",
	"......kllsk.....",
	"..kkkkkkkkkkkkkk",
	"..klllllllllllll",
	"..ksllllllllllll",
	"..ksllllllllllll",
	"..ksllllllllllll",
	"..ksllllllllllll",
	"..ksllllllllllll",
	"..ksllllllllllll",
	"..ksllllllllllkk",
	"..kslllllllllkkk",
	"..kslllllllllkkk",
	"..ksllllllllllkk",
	"..kslllllllllllk",
	"..kslllllllllllk",
	"..kslllllllllllk",
	"..kslllllllllllk",
	"..kslllllllllllk",
	"..ksllllllllllll",
	"..ksllllllllllll",
	"..ksllllllllllll",
	"..ksssssssssssss",
	"..ksssssssssssss",
	"..ksssssssssssss",
	"..kkkkkkkkkkkkkk",
]
const PADLOCK_LEGEND: Dictionary[String, String] = {"k": "ink", "l": "stone-light", "s": "stone"}

## Report card window bat, 16 x 8, left half.
const BAT_HALF: Array[String] = [
	"......k.",
	"k....kpk",
	"kk..kpwp",
	"kpkkpppp",
	"kppppppp",
	".kpkpkdp",
	"..k.k.kd",
	"......kk",
]

## Logo bat, 24 x 12, left half.
const LOGO_BAT_HALF: Array[String] = [
	"..........k.",
	".........kpk",
	"kk......kppp",
	"kpkk...kpwkp",
	"kppkk.kppppp",
	"kpppkkpppppp",
	"kppppppppppd",
	".kppppppppdd",
	".kpkppkppkdd",
	"..k.kk.kk.kd",
	"..........kk",
	"............",
]

var _ok: bool = true


func _init() -> void:
	for dir: String in [COMMON, HUD, HANDS, MENU, CLOSET, REPORT]:
		_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)))
	_write_common()
	_write_menu()
	_write_hud()
	_write_hands()
	_write_report_card()
	_write_closet()
	# Non-zero exit on any failure, so a bad map, path or cwd doesn't look like success.
	quit(0 if _ok else 1)


func _check(err: Error) -> void:
	if err != OK:
		_ok = false


# ================================================================================================
# Sheets
# ================================================================================================

func _write_common() -> void:
	_save(_button("wood", "wood-light", "wood-dark", true, false), COMMON + "ui_button.png")
	_save(_button("pumpkin-light", "", "pumpkin", true, false), COMMON + "ui_button_focus.png")
	_save(_button("pumpkin", "", "", false, true), COMMON + "ui_button_pressed.png")
	_save(_button("disabled-fill", "", "", false, false), COMMON + "ui_button_disabled.png")
	_save(_focus_ring(), COMMON + "ui_focus_ring.png")
	_save(_ink_shape(16, ROUND_MD), COMMON + "ui_ink_md.png")
	_save(_ink_shape(24, ROUND_LG), COMMON + "ui_ink_lg.png")
	_save(_wood_panel(), COMMON + "ui_panel_wood.png")
	_save(_stone_panel(), COMMON + "ui_panel_stone.png")
	_save(_flat_box(12, ROUND_SM, "parchment", "parchment-shade"), COMMON + "ui_sign.png")
	_save(_flat_box(12, ROUND_SM, "stone-light", "stone"), COMMON + "ui_sign_grey.png")
	_save(_keycap(), COMMON + "ui_keycap.png")
	_save(_flat_box(12, ROUND_SM, "candy-yellow", ""), COMMON + "ui_candy_sign.png")
	_save(_brain_pill(), COMMON + "ui_brain_pill.png")
	_save(_map(16, 16, _sym(BRAIN_SMALL_HALF), BRAIN_LEGEND), COMMON + "ui_brain_icon.png")
	_save(_brain_big(), COMMON + "ui_brain_icon_big.png")
	_save(_toggle(ICON_MUSIC), COMMON + "ui_icon_music.png")
	_save(_toggle_images(_sound_icon("zombie-green-bright"), _sound_icon("stone-light")), COMMON + "ui_icon_sound.png")
	var fullscreen: Array[String] = _sym(ICON_FULLSCREEN_QUARTER)
	for i: int in range(ICON_FULLSCREEN_QUARTER.size() - 1, -1, -1):
		fullscreen.append(fullscreen[i])
	_save(_toggle(fullscreen), COMMON + "ui_icon_fullscreen.png")
	_save(_map(12, 12, ICON_PAUSE, ICON_LEGEND), COMMON + "ui_icon_pause.png")
	_save(_round_button("wood", "wood-light", true, false), COMMON + "ui_pause_button.png")
	_save(_round_button("pumpkin-light", "", true, false), COMMON + "ui_pause_button_hover.png")
	_save(_round_button("pumpkin", "", false, true), COMMON + "ui_pause_button_pressed.png")
	_save(_arrow(true), COMMON + "ui_arrow_down.png")
	_save(_arrow(false), COMMON + "ui_arrow_right.png")
	_save(_map(12, 10, CHECK, CHECK_LEGEND), COMMON + "ui_check.png")


func _write_menu() -> void:
	_save(_logo_big(), MENU + "ui_logo.png")
	_save(_logo_small(), MENU + "ui_logo_small.png")
	_save(_card_zombie_run(), MENU + "ui_level_card_zombie_run.png")
	_save(_card_horde_rush(), MENU + "ui_level_card_horde_rush.png")
	_save(_card_pitchfork_panic(), MENU + "ui_level_card_pitchfork_panic.png")
	_save(_card_frame(), MENU + "ui_card_frame.png")
	_save(_coming_soon(), MENU + "ui_coming_soon.png")
	_save(_signpost(), MENU + "ui_signpost.png")
	_save(_thumbtack(), MENU + "ui_thumbtack.png")
	_save(_map(32, 40, _sym(PADLOCK_HALF), PADLOCK_LEGEND), MENU + "ui_padlock.png")


func _write_hud() -> void:
	_save(_hud_band(), HUD + "ui_hud_band.png")
	_save(_cushion(), HUD + "ui_cushion.png")


func _write_report_card() -> void:
	_save(_chalkboard(), REPORT + "ui_chalkboard.png")
	_save(_chalk_tray(), REPORT + "ui_chalk_tray.png")
	_save(_new_best(), REPORT + "ui_new_best.png")
	_save(_moon(), REPORT + "ui_moon.png")
	_save(_map(16, 8, _sym(BAT_HALF), BAT_LEGEND), REPORT + "ui_bat.png")


func _write_closet() -> void:
	_save(_flat_box(16, ROUND_MD, "parchment", "parchment-shade"), CLOSET + "ui_tile_parchment.png")
	_save(_flat_box(16, ROUND_MD, "stone", "ink-muted"), CLOSET + "ui_tile_stone.png")
	_save(_flat_box(16, ROUND_MD, "disabled-fill", "stone-light"), CLOSET + "ui_tile_disabled.png")
	_save(_flat_box(12, ROUND_SM, "pumpkin", "pumpkin-light", true), CLOSET + "ui_tag_pumpkin.png")
	_save(_flat_box(12, ROUND_SM, "zombie-green", "zombie-green-bright", true), CLOSET + "ui_tag_green.png")
	_save(_flat_box(12, ROUND_SM, "zombie-green-bright", "chalk", true), CLOSET + "ui_tag_bright.png")
	_save(_map(32, 32, LOCKED_Q, LOCKED_LEGEND), CLOSET + "ui_locked.png")
	_save(_closet_sign(), CLOSET + "ui_closet_sign.png")
	_save(_mirror(), CLOSET + "ui_mirror.png")
	_save(_ribbon(), CLOSET + "ui_ribbon.png")
	_save(_bow(), CLOSET + "ui_bow.png")


func _write_hands() -> void:
	var left: Image = _hand()
	_save(left, HANDS + "ui_hand_left.png")
	var right: Image = left.duplicate() as Image
	right.flip_x()
	_save(right, HANDS + "ui_hand_right.png")
	for finger: String in HAND_FINGERS:
		var glow: Image = _glow_sheet(finger)
		_save(glow, HANDS + "ui_finger_glow_l_%s.png" % finger)
		_save(_mirror_frames(glow, HAND_W), HANDS + "ui_finger_glow_r_%s.png" % finger)


# ================================================================================================
# Shared chrome
# ================================================================================================

## A button state, 16 x 18 (9-slice 4 top / 6 bottom): md corners, ink outline, a fill with an optional
## 1 px bevel on the inner top and left and a 1 px shade on the inner bottom and right. `shadow` bakes the
## 2 px ink drop under it; `pressed` draws the body 2 px lower with no shadow (it dropped onto it).
func _button(fill: String, bevel: String, shade: String, shadow: bool, pressed: bool) -> Image:
	var img: Image = _new(16, 18)
	var top: int = 2 if pressed else 0
	var mask: PackedByteArray = _round_mask(16, 16, ROUND_MD)
	if shadow:
		_paint(img, 0, 2, mask, 16, 16, "ink")
	_outlined(img, 0, top, mask, 16, 16, fill)
	_bevel(img, 0, top, mask, 16, 16, bevel, shade)
	return img


## 1 px bevel on the inner top-left and shade on the inner bottom-right of an outlined mask.
func _bevel(img: Image, ox: int, oy: int, mask: PackedByteArray, w: int, h: int, bevel: String, shade: String) -> void:
	var inner: PackedByteArray = _shrink(mask, w, h)
	for y: int in h:
		for x: int in w:
			if not _in(inner, w, h, x, y):
				continue
			var up: bool = not _in(inner, w, h, x, y - 1)
			var left: bool = not _in(inner, w, h, x - 1, y)
			var down: bool = not _in(inner, w, h, x, y + 1)
			var right: bool = not _in(inner, w, h, x + 1, y)
			if shade != "" and (down or right):
				_px(img, ox + x, oy + y, shade)
			elif bevel != "" and (up or left):
				_px(img, ox + x, oy + y, bevel)


## The focus ring, 12 x 12 (9-slice 4): 2 px candy-yellow, stepped corners, transparent centre. It is
## its own edge (outline-exempt); expand_margin 2 puts it outside the outline it surrounds.
func _focus_ring() -> Image:
	var img: Image = _new(12, 12)
	var outer: PackedByteArray = _round_mask(12, 12, ROUND_MD)
	var inner: PackedByteArray = _shrink(_shrink(outer, 12, 12), 12, 12)
	for y: int in 12:
		for x: int in 12:
			if _in(outer, 12, 12, x, y) and not _in(inner, 12, 12, x, y):
				_px(img, x, y, "candy-yellow")
	return img


## An all-ink silhouette with stepped corners (9-slice size / 3): shadows and the start-prompt strip.
func _ink_shape(size: int, insets: Array[int]) -> Image:
	var img: Image = _new(size, size)
	_paint(img, 0, 0, _round_mask(size, size, insets), size, size, "ink")
	return img


## A flat sign / tile / tag: `size` square, outlined, a fill, a shade on the inner bottom and right
## (or, with `bevel_light`, `second` as a highlight on the inner top and left instead).
func _flat_box(size: int, insets: Array[int], fill: String, second: String, bevel_light: bool = false) -> Image:
	var img: Image = _new(size, size)
	var mask: PackedByteArray = _round_mask(size, size, insets)
	_outlined(img, 0, 0, mask, size, size, fill)
	if second != "":
		if bevel_light:
			_bevel(img, 0, 0, mask, size, size, second, "")
		else:
			_bevel(img, 0, 0, mask, size, size, "", second)
	return img


## A keycap, 12 x 12: parchment with a 2 px parchment-shade bottom lip.
func _keycap() -> Image:
	var img: Image = _flat_box(12, ROUND_SM, "parchment", "")
	_rect(img, 1, 9, 10, 2, "parchment-shade")
	_px(img, 1, 1, "chalk")
	return img


## Wood panel, 24 x 24 (9-slice 8, lg corners): a wood-dark frame, wood planks with grain, a wood-light
## bevel and a nail in each corner. The middle 8 x 8 holds one grain line, so it tiles.
func _wood_panel() -> Image:
	var img: Image = _new(24, 24)
	var mask: PackedByteArray = _round_mask(24, 24, ROUND_LG)
	_outlined(img, 0, 0, mask, 24, 24, "wood-dark")
	var inner: PackedByteArray = _shrink(_shrink(_shrink(mask, 24, 24), 24, 24), 24, 24)
	_paint(img, 0, 0, inner, 24, 24, "wood")
	_bevel_mask_edge(img, inner, 24, 24, "wood-light", true)
	for y: int in [11]:
		_rect(img, 4, y, 16, 1, "wood-dark")
	for corner: Vector2i in [Vector2i(5, 5), Vector2i(18, 5), Vector2i(5, 18), Vector2i(18, 18)]:
		_px(img, corner.x, corner.y, "stone-light")
	return img


## Paints `color` on the pixels of `mask` whose top or left neighbour is outside it (`top_left`), or bottom
## or right (otherwise).
func _bevel_mask_edge(img: Image, mask: PackedByteArray, w: int, h: int, color: String, top_left: bool) -> void:
	for y: int in h:
		for x: int in w:
			if not _in(mask, w, h, x, y):
				continue
			var edge: bool
			if top_left:
				edge = not _in(mask, w, h, x, y - 1) or not _in(mask, w, h, x - 1, y)
			else:
				edge = not _in(mask, w, h, x, y + 1) or not _in(mask, w, h, x + 1, y)
			if edge:
				_px(img, x, y, color)


## Stone panel, 32 x 32 (9-slice 8, lg corners): blocks in a running bond, ink-muted mortar, a
## stone-light top edge per block. The middle 16 x 16 is one bond period, so it tiles.
func _stone_panel() -> Image:
	var img: Image = _new(32, 32)
	var mask: PackedByteArray = _round_mask(32, 32, ROUND_LG)
	_outlined(img, 0, 0, mask, 32, 32, "stone")
	var inner: PackedByteArray = _shrink(mask, 32, 32)
	for y: int in 32:
		for x: int in 32:
			if not _in(inner, 32, 32, x, y):
				continue
			# Courses 8 rows tall from row 0, joints every 16 px, shifted 8 px every other course.
			var course: int = y / 8
			var row: int = y % 8
			var joint: bool = (x + (8 if course % 2 == 1 else 0)) % 16 == 0
			if row == 0 or joint:
				_px(img, x, y, "ink-muted")
			elif row == 1:
				_px(img, x, y, "stone-light")
	_bevel_mask_edge(img, inner, 32, 32, "stone-light", true)
	return img


## Brain-counter pill, 28 x 28 (9-slice 12, full rounding): wood-dark with a wood top highlight.
func _brain_pill() -> Image:
	var img: Image = _new(28, 28)
	var mask: PackedByteArray = _disc_mask(28, 28, 13.5, 13.5, 14.0)
	_outlined(img, 0, 0, mask, 28, 28, "wood-dark")
	var inner: PackedByteArray = _shrink(mask, 28, 28)
	for y: int in 28:
		for x: int in 28:
			if _in(inner, 28, 28, x, y) and not _in(inner, 28, 28, x, y - 1) and x > 6 and x < 21:
				_px(img, x, y, "wood")
	return img


func _brain_big() -> Image:
	return _map(32, 32, _sym(BRAIN_BIG_HALF), BRAIN_LEGEND)


## A toggle icon sheet, 40 x 20, from one map ('c' takes the on / off colour).
func _toggle(rows: Array[String]) -> Image:
	return _toggle_images(_map(20, 20, rows, TOGGLE_ON), _map(20, 20, rows, TOGGLE_OFF))


## A toggle icon sheet, 40 x 20: frame 0 the on icon, frame 1 the off icon with a stamp-red diagonal slash
## (an ink edge, bottom-left to top-right).
func _toggle_images(on: Image, off: Image) -> Image:
	var img: Image = _new(40, 20)
	img.blit_rect(on, Rect2i(0, 0, 20, 20), Vector2i(0, 0))
	var slash: PackedByteArray = _empty_mask(20, 20)
	for y: int in range(2, 18):
		var x: int = 19 - y
		for dx: int in [-1, 0]:
			slash[y * 20 + x + dx] = 1
	_outlined(off, 0, 0, _dilate(slash, 20, 20), 20, 20, "stamp-red")
	img.blit_rect(off, Rect2i(0, 0, 20, 20), Vector2i(20, 0))
	return img


## The sound icon, 20 x 20: a speaker (box and cone) and two sound-wave arcs, each outlined in ink.
func _sound_icon(color: String) -> Image:
	var img: Image = _new(20, 20)
	var speaker: PackedByteArray = _poly_mask(20, 20, PackedVector2Array([
		Vector2(1, 7), Vector2(5, 7), Vector2(10, 2), Vector2(10, 18), Vector2(5, 13), Vector2(1, 13),
	]))
	_outlined(img, 0, 0, speaker, 20, 20, color)
	var waves: PackedByteArray = _empty_mask(20, 20)
	for y: int in 20:
		for x: int in 20:
			var d: Vector2 = Vector2(x + 0.5 - 8.0, y + 0.5 - 10.0)
			if absf(d.angle()) > deg_to_rad(48.0):
				continue
			for r: float in [6.0, 9.5]:
				if absf(d.length() - r) < 0.55:
					waves[y * 20 + x] = 1
	_paint(img, 0, 0, _dilate(waves, 20, 20), 20, 20, "ink")
	_paint(img, 0, 0, waves, 20, 20, color)
	return img


## The round pause button, 24 x 24 (full rounding, one size, no 9-slice): a 22 px disc with a baked 2 px
## ink drop (or, pressed, the disc 2 px lower and no drop).
func _round_button(fill: String, bevel: String, shadow: bool, pressed: bool) -> Image:
	var img: Image = _new(24, 24)
	var mask: PackedByteArray = _disc_mask(24, 22, 11.5, 10.5, 11.0)
	if shadow:
		_paint(img, 0, 2, mask, 24, 22, "ink")
	var top: int = 2 if pressed else 0
	_outlined(img, 0, top, mask, 24, 22, fill)
	if bevel != "":
		_bevel(img, 0, top, mask, 24, 22, bevel, "")
	return img


## The tutorial arrow, 24 x 20 either way: a chunky shaft and a wide head, candy-yellow with an ink
## outline. `down`: the tip at the bottom centre (x 11-12); otherwise the tip at the right edge (rows 9-10).
## Built pointing right (length x cross), then turned for down.
func _arrow(down: bool) -> Image:
	var length: int = 20 if down else 24
	var cross: int = 24 if down else 20
	var head: int = 11 if down else 12
	var mid: float = cross / 2.0
	var mask: PackedByteArray = _empty_mask(length, cross)
	for y: int in cross:
		for x: int in length:
			var half: float = SHAFT_HALF
			if x >= length - head:
				half = maxf((mid - 1.0) * float(length - x) / head, 1.0)
			if absf(y + 0.5 - mid) <= half:
				mask[y * length + x] = 1
	if not down:
		var img: Image = _new(length, cross)
		_outlined(img, 0, 0, mask, length, cross, "candy-yellow")
		return img
	var turned: PackedByteArray = _empty_mask(cross, length)
	for y: int in cross:
		for x: int in length:
			turned[x * cross + y] = mask[y * length + x]
	var out: Image = _new(cross, length)
	_outlined(out, 0, 0, turned, cross, length, "candy-yellow")
	return out


# ================================================================================================
# Menu
# ================================================================================================

## The big logo (title, boot splash, loading page): "Zombies" at scale 7 in zombie greens with three
## slime drips, over a pumpkin and "Teach Typing" at scale 4 in pumpkin; a bat flies by. 2 px ink drop.
func _logo_big() -> Image:
	var line1: Dictionary = _drips(_trim_word(_word("Zombies", 7)), LOGO_DRIPS)
	var line2: Dictionary = _trim_word(_word("Teach Typing", 4))
	var pumpkin: Image = _logo_pumpkin()
	var bat: Image = _map(24, 12, _sym(LOGO_BAT_HALF), BAT_LEGEND)
	var x2: int = pumpkin.get_width() + 4
	var w: int = maxi(x2 + int(line2["w"]) + 4, int(line1["w"]) + 4) + bat.get_width()
	var h1: int = int(line1["h"]) + 4
	var h: int = h1 + 2 + int(line2["h"]) + 4
	var img: Image = _new(w, h)
	var x1: int = (x2 + int(line2["w"]) + 4 - int(line1["w"]) - 2) / 2
	_letter(img, x1, 0, line1, "zombie-green", "zombie-green-bright", 2)
	_letter(img, x2, h1 + 2, line2, "pumpkin", "pumpkin-light", 2)
	_blit(img, pumpkin, 0, h - pumpkin.get_height() - 2)
	_blit(img, bat, w - bat.get_width() - 1, 4)
	return _trim(img)


## Slime drips under "Zombies": [letter index, glyph column, length px]: under the Z's bar, the m's middle
## leg and the e's foot. Each is 3 px wide with a round end.
const LOGO_DRIPS: Array[Vector3i] = [Vector3i(0, 1, 7), Vector3i(2, 2, 10), Vector3i(5, 2, 6)]


## The word's rows cropped to the ones in use (a word without descenders loses the empty rows).
func _trim_word(word: Dictionary) -> Dictionary:
	var w: int = int(word["w"])
	var h: int = int(word["h"])
	var mask: PackedByteArray = word["mask"]
	var top: int = h
	var bottom: int = -1
	for y: int in h:
		for x: int in w:
			if mask[y * w + x] != 0:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	var out: PackedByteArray = mask.slice(top * w, (bottom + 1) * w)
	return {"mask": out, "w": w, "h": bottom - top + 1, "lefts": word["lefts"], "scale": word["scale"]}


## Adds drips under a word: for each [column, length], a 3 px column from the lowest stroke pixel down,
## ending in a 5 px blob. The mask grows by the longest drip plus 3 rows.
func _drips(word: Dictionary, drips: Array[Vector3i]) -> Dictionary:
	var w: int = int(word["w"])
	var h: int = int(word["h"])
	var scale: int = int(word["scale"])
	var lefts: Array[int] = word["lefts"]
	var extra: int = 3
	for drip: Vector3i in drips:
		extra = maxi(extra, drip.z + 3)
	var nh: int = h + extra
	var mask: PackedByteArray = (word["mask"] as PackedByteArray).duplicate()
	mask.resize(w * nh)
	for drip: Vector3i in drips:
		var column: int = lefts[drip.x] + drip.y * scale + (scale - 3) / 2
		var bottom: int = -1
		for y: int in h:
			if mask[y * w + column] != 0:
				bottom = y
		if bottom < 0:
			push_error("drip column %d has no stroke" % column)
			_ok = false
			continue
		for y: int in range(bottom, bottom + drip.z):
			for dx: int in 3:
				mask[y * w + column + dx] = 1
		var blob: PackedByteArray = _disc_mask(w, nh, column + 1.0, bottom + drip.z + 0.5, 2.6)
		for i: int in mask.size():
			if blob[i] != 0:
				mask[i] = 1
	return {"mask": mask, "w": w, "h": nh}


## The menu logo: the same lettering on one line at scale 3 (fits the 352 x 40 slot), its own composition.
func _logo_small() -> Image:
	var zombies: Dictionary = _word("Zombies", 3)
	var rest: Dictionary = _word("Teach Typing", 3)
	var gap: int = 10
	var w: int = int(zombies["w"]) + gap + int(rest["w"]) + 2
	var h: int = maxi(int(zombies["h"]), int(rest["h"])) + 4
	var img: Image = _new(w, h)
	_letter(img, 0, 0, zombies, "zombie-green", "zombie-green-bright", 2)
	_letter(img, int(zombies["w"]) + gap, 0, rest, "pumpkin", "pumpkin-light", 2)
	return _pad_even(_trim(img), MENU_LOGO_SLOT)


## The main menu's logo slot (Story 4.2 layout table): the logo is centred in it on whole pixels.
const MENU_LOGO_SLOT: Vector2i = Vector2i(352, 40)


## Adds a transparent column / row on the right / bottom so the image centres in `slot` on whole pixels.
func _pad_even(img: Image, slot: Vector2i) -> Image:
	var w: int = img.get_width() + (slot.x - img.get_width()) % 2
	var h: int = img.get_height() + (slot.y - img.get_height()) % 2
	var out: Image = _new(w, h)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	return out


## A 36 x 34 jack-o'-lantern for the logo: three overlapping ovals with rib lines, a stem and a leaf, a
## cute face (dot eyes with a shine, a small smile, no teeth).
func _logo_pumpkin() -> Image:
	var w: int = 36
	var h: int = 34
	var img: Image = _new(w, h)
	var body: PackedByteArray = _union([
		_ellipse_mask(w, h, 10.5, 20.0, 10.0, 12.5),
		_ellipse_mask(w, h, 24.5, 20.0, 10.0, 12.5),
		_ellipse_mask(w, h, 17.5, 19.5, 11.0, 13.5),
	])
	_outlined(img, 0, 0, body, w, h, "pumpkin")
	var inner: PackedByteArray = _shrink(body, w, h)
	for y: int in h:
		for x: int in [6, 13, 22, 29]:
			if _in(inner, w, h, x, y) and _in(inner, w, h, x, y - 2) and _in(inner, w, h, x, y + 2):
				_px(img, x, y, "pumpkin-light" if x < 18 else "ink")
	_box(img, 15, 0, 6, 8, "wood-dark")
	_box(img, 21, 2, 8, 5, "zombie-green-dark")
	_rect(img, 12, 15, 3, 5, "ink")
	_rect(img, 22, 15, 3, 5, "ink")
	_px(img, 13, 16, "chalk")
	_px(img, 23, 16, "chalk")
	_rect(img, 14, 25, 9, 1, "ink")
	_rect(img, 12, 23, 2, 2, "ink")
	_rect(img, 23, 23, 2, 2, "ink")
	_rect(img, 9, 21, 2, 1, "pumpkin-light")
	_rect(img, 26, 21, 2, 1, "pumpkin-light")
	return img


## A level card picture is 184 x 72, outline-exempt like a backdrop; never candy-yellow or stamp-red.
const CARD_W: int = 184
const CARD_H: int = 72


## Zombie Run: the Sunny Village Green (sky, a cloud, the pale hills, a cottage, bunting) with the zombie
## and a waving villager on the path.
func _card_zombie_run() -> Image:
	var img: Image = _new(CARD_W, CARD_H)
	_rect(img, 0, 0, CARD_W, CARD_H, "art-sky")
	_cloud(img, 30, 16, 5)
	_cloud(img, 140, 12, 4)
	for x: int in CARD_W:
		var top: int = 44 - roundi(4.0 * cos(TAU * x / 92.0))
		_rect(img, x, top, 1, CARD_H - top, "chalk-dim")
		_px(img, x, top, "zombie-green")
	_rect(img, 0, 52, CARD_W, 20, "art-grass")
	_rect(img, 0, 60, CARD_W, 8, "parchment-shade")
	_rect(img, 0, 60, CARD_W, 1, "ink-faded")
	_px(img, 20, 64, "ink-faded")
	_px(img, 96, 65, "ink-faded")
	_px(img, 150, 63, "ink-faded")
	_cottage(img, 134, 28)
	_bunting(img)
	_sprite(img, ZOMBIE_IDLE, 0, 40, 30)
	_sprite(img, VILLAGER_WAVE, 0, 82, 30)
	return img


## Horde Rush: a farmhouse on the right, crop lanes, three zombies marching toward it.
func _card_horde_rush() -> Image:
	var img: Image = _new(CARD_W, CARD_H)
	_rect(img, 0, 0, CARD_W, CARD_H, "art-sky")
	_cloud(img, 60, 12, 4)
	_rect(img, 0, 30, CARD_W, 42, "art-grass")
	# Lanes: wood soil rows between grass rows.
	for lane: int in 3:
		var y: int = 36 + lane * 12
		_rect(img, 0, y, CARD_W, 3, "wood")
		_rect(img, 0, y, CARD_W, 1, "wood-dark")
	# Farmhouse: wood-light walls, a wood-dark roof, a pumpkin door, a window.
	_box(img, 138, 18, 40, 26, "wood-light")
	for y: int in range(22, 43, 4):
		_rect(img, 139, y, 38, 1, "wood")
	_roof(img, 158, 4, 19, "ink")
	_roof(img, 158, 5, 18, "wood-dark")
	_box(img, 152, 30, 10, 14, "pumpkin")
	_box(img, 165, 23, 9, 8, "art-sky-light")
	_rect(img, 169, 24, 1, 6, "ink")
	_box(img, 142, 6, 5, 8, "stone")
	# A fence post line and a hay bale.
	_box(img, 118, 34, 14, 9, "parchment-shade")
	_rect(img, 119, 37, 12, 1, "wood-light")
	_sprite(img, ZOMBIE_WALK, 0, 8, 18)
	_sprite(img, ZOMBIE_WALK, 2, 44, 30)
	_sprite(img, ZOMBIE_WALK, 1, 80, 42)
	return img


## Pitchfork Panic: the moonlit village, the path, the zombie out in front and a pitchfork mob far
## behind (farm tools held straight up, never aimed at anyone).
func _card_pitchfork_panic() -> Image:
	var img: Image = _new(CARD_W, CARD_H)
	_rect(img, 0, 0, CARD_W, CARD_H, "night")
	for star: Vector2i in [Vector2i(12, 8), Vector2i(48, 4), Vector2i(70, 14), Vector2i(104, 6), Vector2i(166, 20)]:
		_px(img, star.x, star.y, "chalk")
	var moon: PackedByteArray = _disc_mask(CARD_W, CARD_H, 146.0, 16.0, 9.0)
	_paint(img, 0, 0, moon, CARD_W, CARD_H, "art-moon")
	_rect(img, 141, 13, 2, 2, "parchment-shade")
	_rect(img, 148, 19, 2, 2, "parchment-shade")
	for x: int in CARD_W:
		var top: int = 38 - roundi(5.0 * cos(TAU * (x + 20) / 120.0))
		_rect(img, x, top, 1, CARD_H - top, "dusk")
	# Village houses: dark silhouettes with lit windows.
	for house: Vector2i in [Vector2i(18, 30), Vector2i(52, 33), Vector2i(150, 31)]:
		_rect(img, house.x, house.y, 18, 14, "ink-muted")
		_roof(img, house.x + 9, house.y - 8, house.y, "ink-muted")
		_rect(img, house.x + 5, house.y + 4, 3, 3, "pumpkin-light")
		_rect(img, house.x + 11, house.y + 4, 3, 3, "pumpkin-light")
	_rect(img, 0, 46, CARD_W, 26, "ink-muted")
	_rect(img, 0, 52, CARD_W, 14, "wood-dark")
	_rect(img, 0, 52, CARD_W, 1, "wood")
	# The mob far behind (right): small villagers, pitchforks held straight up.
	for i: int in 5:
		var x: int = 128 + i * 9
		var y: int = 42 + (i % 2)
		_rect(img, x + 1, y - 9, 1, 12, "wood-light")
		_rect(img, x, y - 11, 3, 1, "stone-light")
		_px(img, x, y - 12, "stone-light")
		_px(img, x + 2, y - 12, "stone-light")
		_px(img, x + 1, y - 12, "stone-light")
		_rect(img, x + 2, y - 3, 4, 4, "art-skin-light")
		_rect(img, x + 2, y + 1, 4, 6, "pumpkin" if i % 2 == 0 else "wood")
	# The zombie in front (left), running toward the viewer's left.
	_sprite(img, ZOMBIE_WALK, 0, 26, 34, true)
	return img


## Card frame, 24 x 24 (9-slice 8, lg corners): wood-dark with a wood bevel; a nail head in each corner.
func _card_frame() -> Image:
	var img: Image = _new(24, 24)
	var mask: PackedByteArray = _round_mask(24, 24, ROUND_LG)
	_outlined(img, 0, 0, mask, 24, 24, "wood-dark")
	_bevel(img, 0, 0, mask, 24, 24, "wood", "")
	return img


## "Coming soon": a wood plank nailed across the card picture, chalk lettering, two nail heads, rotated
## about 8 degrees (right end up) by three shears.
func _coming_soon() -> Image:
	var word: Dictionary = _word("Coming soon", 2)
	var w: int = 152
	var h: int = int(word["h"]) + 8
	var plank: Image = _new(w, h)
	var mask: PackedByteArray = _round_mask(w, h, ROUND_SM)
	_outlined(plank, 0, 0, mask, w, h, "wood")
	_bevel(plank, 0, 0, mask, w, h, "wood-light", "wood-dark")
	_rect(plank, 3, h / 2 + 5, 6, 1, "wood-dark")
	_rect(plank, w - 12, h / 2 - 5, 7, 1, "wood-dark")
	for nail: int in [4, w - 6]:
		_rect(plank, nail, 3, 2, 2, "stone-light")
		_px(plank, nail + 1, 4, "ink-muted")
	_letter(plank, (w - int(word["w"]) - 2) / 2, 3, word, "chalk", "", 0)
	return _trim(_close_outline(_rotate(plank, -8.0)))


## One signpost post, 8 x 16: wood with a wood-dark grain line and a wood-light edge.
func _signpost() -> Image:
	var img: Image = _new(8, 16)
	var mask: PackedByteArray = _round_mask(8, 16, ROUND_SM)
	_outlined(img, 0, 0, mask, 8, 16, "wood")
	_rect(img, 1, 1, 1, 14, "wood-light")
	_rect(img, 4, 3, 1, 9, "wood-dark")
	return img


## The storage notice thumbtack, 8 x 8: a pumpkin pin head (never red) with a highlight.
func _thumbtack() -> Image:
	var img: Image = _new(8, 8)
	var head: PackedByteArray = _disc_mask(8, 8, 3.5, 3.5, 3.6)
	_outlined(img, 0, 0, head, 8, 8, "pumpkin")
	_px(img, 2, 2, "pumpkin-light")
	_px(img, 3, 2, "pumpkin-light")
	_px(img, 2, 3, "pumpkin-light")
	return img


# ================================================================================================
# HUD
# ================================================================================================

## HUD band, 24 x 24 (9-slice 8, square: it sits on the canvas edges): ink top edge, a wood frame with a
## wood-light top bevel, a wood-dark fill.
func _hud_band() -> Image:
	var img: Image = _new(24, 24)
	_rect(img, 0, 0, 24, 24, "ink")
	_rect(img, 1, 1, 22, 22, "wood")
	_rect(img, 1, 1, 22, 1, "wood-light")
	_rect(img, 4, 4, 16, 16, "ink")
	_rect(img, 5, 5, 14, 14, "wood-dark")
	return img


## The pet cushion, 48 x 48: a parchment pillow in the lower half (the pet stands on its top at row 36),
## parchment-shade underside and seams, a tuft button in the middle; transparent above.
func _cushion() -> Image:
	var img: Image = _new(48, 48)
	var mask: PackedByteArray = _union([
		_ellipse_mask(48, 48, 23.5, 37.5, 23.0, 9.5),
		_rect_mask(48, 48, 2, 34, 44, 8),
	])
	_outlined(img, 0, 0, mask, 48, 48, "parchment")
	var inner: PackedByteArray = _shrink(mask, 48, 48)
	for y: int in 48:
		for x: int in 48:
			if _in(inner, 48, 48, x, y) and y >= 42:
				_px(img, x, y, "parchment-shade")
	_rect(img, 6, 41, 36, 1, "parchment-shade")
	_rect(img, 22, 39, 4, 2, "parchment-shade")
	_rect(img, 23, 39, 2, 1, "ink-faded")
	for corner: Vector2i in [Vector2i(3, 35), Vector2i(43, 35)]:
		_rect(img, corner.x, corner.y, 2, 2, "parchment-shade")
	return img


# ================================================================================================
# Hands
# ================================================================================================

const HAND_W: int = 64
const HAND_H: int = 48
const HAND_FINGERS: Array[String] = ["pinky", "ring", "middle", "index", "thumb"]
## Left hand (palm down, thumb pointing inward to the right), in its own 64 x 48 image. Fingers are
## 9 px wide with a 1 px gap; their bottoms run under the palm.
const FINGER_RECTS: Dictionary[String, Rect2i] = {
	"pinky": Rect2i(4, 15, 9, 16),
	"ring": Rect2i(14, 8, 9, 22),
	"middle": Rect2i(24, 4, 9, 26),
	"index": Rect2i(34, 8, 9, 22),
	"thumb": Rect2i(42, 27, 19, 9),
}
const PALM: Rect2i = Rect2i(3, 24, 41, 16)
const PALM_TOP: int = 26
const CUFF: Rect2i = Rect2i(5, 39, 37, 8)
## Home-row bump on the index fingertip (f / j), relative to the finger rect.
const BUMP: Rect2i = Rect2i(3, 3, 3, 2)


func _finger_mask(finger: String) -> PackedByteArray:
	var r: Rect2i = FINGER_RECTS[finger]
	if finger == "thumb":
		return _round_rect_mask(HAND_W, HAND_H, r, ROUND_MD, true)
	return _round_rect_mask(HAND_W, HAND_H, r, ROUND_MD, false)


func _palm_mask() -> PackedByteArray:
	return _round_rect_mask(HAND_W, HAND_H, PALM, ROUND_LG, false)


## The resting left hand: each finger outlined on its own (so the gaps read), the palm over the finger
## bottoms, a bat-purple shirt cuff at the wrist, zombie-green-dark shade on each finger's right edge and
## the f-bump on the index.
func _hand() -> Image:
	var img: Image = _new(HAND_W, HAND_H)
	_outlined(img, 0, 0, _round_rect_mask(HAND_W, HAND_H, CUFF, ROUND_SM, false), HAND_W, HAND_H, "bat-purple")
	_rect(img, CUFF.position.x + 1, CUFF.end.y - 3, CUFF.size.x - 2, 2, "dusk")
	_draw_palm(img, "zombie-green")
	for finger: String in HAND_FINGERS:
		_draw_finger(img, finger, "zombie-green")
	return img


func _draw_palm(img: Image, fill: String) -> void:
	_outlined(img, 0, 0, _palm_mask(), HAND_W, HAND_H, fill)
	_rect(img, PALM.position.x + 2, PALM.end.y - 3, PALM.size.x - 4, 1, "zombie-green-dark")


## A finger: outlined, filled, a 1 px zombie-green-dark shade on the right; its bottom merges into the palm
## (the palm's fill continues under it), the index carries the bump.
func _draw_finger(img: Image, finger: String, fill: String) -> void:
	var mask: PackedByteArray = _finger_mask(finger)
	var r: Rect2i = FINGER_RECTS[finger]
	_outlined(img, 0, 0, mask, HAND_W, HAND_H, fill)
	var inner: PackedByteArray = _shrink(mask, HAND_W, HAND_H)
	for y: int in HAND_H:
		for x: int in HAND_W:
			if not _in(inner, HAND_W, HAND_H, x, y):
				continue
			if finger == "thumb":
				if not _in(inner, HAND_W, HAND_H, x, y + 1):
					_px(img, x, y, "zombie-green-dark")
			elif not _in(inner, HAND_W, HAND_H, x + 1, y):
				_px(img, x, y, "zombie-green-dark")
	# Join: the finger's bottom outline inside the palm is palm fill, so the finger grows out of it.
	var palm_inner: PackedByteArray = _shrink(_palm_mask(), HAND_W, HAND_H)
	for y: int in HAND_H:
		for x: int in HAND_W:
			if _in(mask, HAND_W, HAND_H, x, y) and _in(palm_inner, HAND_W, HAND_H, x, y) and y >= PALM_TOP:
				_px(img, x, y, "zombie-green")
	if finger == "index":
		_rect(img, r.position.x + BUMP.position.x, r.position.y + BUMP.position.y, BUMP.size.x, BUMP.size.y,
				"zombie-green-dark")


## A glow sheet for one left-hand finger, 128 x 48 (2 frames of the hand size): transparent except the
## lit finger (bright fill, ink outline, the bump on the index) and its candy-yellow ring, 2 px in frame 0
## (strong) and 1 px in frame 1 (weak), around the part of the finger outside the palm.
func _glow_sheet(finger: String) -> Image:
	var img: Image = _new(HAND_W * 2, HAND_H)
	var mask: PackedByteArray = _finger_mask(finger)
	var palm: PackedByteArray = _palm_mask()
	var exposed: PackedByteArray = _minus(mask, palm)
	# The ring stops at the palm's top row (also beside its rounded corners), so it never hangs below.
	var palm_rows: PackedByteArray = _rect_mask(HAND_W, HAND_H, PALM.position.x - 2, PALM.position.y, PALM.size.x + 4,
			HAND_H - PALM.position.y)
	if finger == "thumb":
		palm_rows = palm
	for frame: int in 2:
		var width: int = 2 if frame == 0 else 1
		var one: Image = _new(HAND_W, HAND_H)
		var ring: PackedByteArray = _minus(_minus(_dilate_n(exposed, HAND_W, HAND_H, width), mask), palm_rows)
		_paint(one, 0, 0, ring, HAND_W, HAND_H, "candy-yellow")
		_draw_finger(one, finger, "zombie-green-bright")
		# Only the finger's own pixels (its mask) and the ring: clear what _draw_finger painted into the palm
		# below the join, so the overlay never covers the resting palm.
		for y: int in HAND_H:
			for x: int in HAND_W:
				var keep: bool = _in(ring, HAND_W, HAND_H, x, y) or _in(exposed, HAND_W, HAND_H, x, y)
				if not keep:
					one.set_pixel(x, y, Color(0, 0, 0, 0))
		img.blit_rect(one, Rect2i(0, 0, HAND_W, HAND_H), Vector2i(frame * HAND_W, 0))
	return img


## Mirrors each `frame_w`-wide frame of a sheet in place (frames keep their order).
func _mirror_frames(sheet: Image, frame_w: int) -> Image:
	var out: Image = _new(sheet.get_width(), sheet.get_height())
	for frame: int in sheet.get_width() / frame_w:
		var one: Image = sheet.get_region(Rect2i(frame * frame_w, 0, frame_w, sheet.get_height()))
		one.flip_x()
		out.blit_rect(one, Rect2i(0, 0, frame_w, sheet.get_height()), Vector2i(frame * frame_w, 0))
	return out


# ================================================================================================
# Report card
# ================================================================================================

## Chalkboard, 32 x 32 (9-slice 8, lg corners): ink, a wood-light bevel, wood, an inner ink line, then
## the chalkboard surface (the board starts 4 px in, so the HUD stats labels at x 4 sit on it).
func _chalkboard() -> Image:
	var img: Image = _new(32, 32)
	var mask: PackedByteArray = _round_mask(32, 32, ROUND_LG)
	_outlined(img, 0, 0, mask, 32, 32, "wood")
	_bevel(img, 0, 0, mask, 32, 32, "wood-light", "")
	var board: PackedByteArray = _shrink(_shrink(_shrink(mask, 32, 32), 32, 32), 32, 32)
	_outlined(img, 0, 0, board, 32, 32, "chalkboard")
	return img


## The chalk tray with two stubs, 408 x 14: the tray (rows 4-13, wood with a wood-light lip) and two
## chalk stubs resting on it (where the 2.9 placeholders were).
func _chalk_tray() -> Image:
	var img: Image = _new(408, 14)
	var tray: PackedByteArray = _round_rect_mask(408, 14, Rect2i(0, 4, 408, 10), ROUND_SM, false)
	_outlined(img, 0, 0, tray, 408, 14, "wood")
	_rect(img, 1, 5, 406, 1, "wood-light")
	_rect(img, 1, 11, 406, 1, "wood-dark")
	for stub: Rect2i in [Rect2i(37, 0, 16, 5), Rect2i(67, 1, 10, 4)]:
		var mask: PackedByteArray = _round_rect_mask(408, 14, stub, ROUND_SM, false)
		_outlined(img, 0, 0, mask, 408, 14, "chalk")
		_rect(img, stub.position.x + 1, stub.end.y - 2, stub.size.x - 2, 1, "stone-light")
	return img


## "New best!": a stamp-red rubber stamp with a chalk inner border and chalk lettering, pre-rotated -8
## degrees (right end up) as a stepped skew: columns move, so the chalk letters keep straight uprights.
func _new_best() -> Image:
	var word: Dictionary = _word("New best!", 3)
	var w: int = int(word["w"]) + 22
	var h: int = 7 * 3 + 16
	var stamp: Image = _new(w, h)
	var mask: PackedByteArray = _round_mask(w, h, ROUND_MD)
	_outlined(stamp, 0, 0, mask, w, h, "stamp-red")
	var border: PackedByteArray = _shrink(_shrink(_shrink(mask, w, h), w, h), w, h)
	var border_in: PackedByteArray = _shrink(border, w, h)
	_paint(stamp, 0, 0, _minus(border, border_in), w, h, "chalk")
	_letter_plain(stamp, 11, 7, word, "chalk")
	return _trim(_close_outline(_skew(stamp, -8.0)))


## The window moon, 28 x 26: an art-moon disc with a sleepy smiling face and pink cheeks.
func _moon() -> Image:
	var img: Image = _new(28, 26)
	var mask: PackedByteArray = _disc_mask(28, 26, 13.5, 12.5, 12.5)
	_outlined(img, 0, 0, mask, 28, 26, "art-moon")
	_rect(img, 5, 6, 2, 2, "parchment-shade")
	_rect(img, 19, 18, 3, 2, "parchment-shade")
	_rect(img, 20, 5, 2, 1, "parchment-shade")
	# Closed happy eyes (little arcs), a smile, cheeks.
	for eye: int in [8, 16]:
		_px(img, eye, 11, "ink")
		_rect(img, eye + 1, 10, 2, 1, "ink")
		_px(img, eye + 3, 11, "ink")
	_px(img, 10, 15, "ink")
	_rect(img, 11, 16, 5, 1, "ink")
	_px(img, 16, 15, "ink")
	_rect(img, 6, 13, 2, 1, "art-brain-pink")
	_rect(img, 19, 13, 2, 1, "art-brain-pink")
	return img


# ================================================================================================
# Closet and Welcome Gift
# ================================================================================================

## "Crypt Closet": a parchment sign with bat-purple lettering, nail heads and a tiny cobweb corner.
func _closet_sign() -> Image:
	var word: Dictionary = _word("Crypt Closet", 2)
	var w: int = int(word["w"]) + 2 + 40
	var h: int = 32
	var img: Image = _new(w, h)
	var mask: PackedByteArray = _round_mask(w, h, ROUND_SM)
	_outlined(img, 0, 0, mask, w, h, "parchment")
	_bevel(img, 0, 0, mask, w, h, "", "parchment-shade")
	for nail: Vector2i in [Vector2i(5, 5), Vector2i(w - 7, 5)]:
		_rect(img, nail.x, nail.y, 2, 2, "stone")
		_px(img, nail.x, nail.y, "stone-light")
	# Cobweb in the bottom-left corner: ink-faded threads.
	for i: int in 6:
		_px(img, 2 + i, h - 3 - i, "ink-faded")
	_rect(img, 2, h - 6, 4, 1, "ink-faded")
	_rect(img, 5, h - 9, 1, 4, "ink-faded")
	_letter(img, 20, (h - int(word["h"]) - 2) / 2, word, "bat-purple", "", 0)
	return img


## Mirror, 24 x 24 (9-slice 8, lg corners): a wood frame (wood-light bevel) around night glass.
func _mirror() -> Image:
	var img: Image = _new(24, 24)
	var mask: PackedByteArray = _round_mask(24, 24, ROUND_LG)
	_outlined(img, 0, 0, mask, 24, 24, "wood")
	_bevel(img, 0, 0, mask, 24, 24, "wood-light", "wood-dark")
	var glass: PackedByteArray = _shrink(_shrink(_shrink(_shrink(mask, 24, 24), 24, 24), 24, 24), 24, 24)
	_outlined(img, 0, 0, glass, 24, 24, "night")
	_px(img, 7, 7, "stone-light")
	return img


## The Welcome Gift ribbon, 24 x 12 (9-slice 4 left / right, 1 top / bottom): pumpkin with pumpkin-light
## edges and an ink outline; the middle is uniform down its length, so it stretches.
func _ribbon() -> Image:
	var img: Image = _new(24, 12)
	_rect(img, 0, 0, 24, 12, "ink")
	_rect(img, 1, 1, 22, 10, "pumpkin")
	_rect(img, 2, 1, 1, 10, "pumpkin-light")
	_rect(img, 21, 1, 1, 10, "pumpkin-light")
	return img


## The bow, 48 x 20: two pumpkin loops (pumpkin-light inner fold), two short tails and a pumpkin-light
## knot, each piece outlined.
func _bow() -> Image:
	var img: Image = _new(48, 20)
	var tails: PackedByteArray = _union([
		_poly_mask(48, 20, PackedVector2Array([Vector2(20, 10), Vector2(24, 11), Vector2(16, 20), Vector2(10, 20)])),
		_poly_mask(48, 20, PackedVector2Array([Vector2(28, 10), Vector2(24, 11), Vector2(32, 20), Vector2(38, 20)])),
	])
	_outlined(img, 0, 0, tails, 48, 20, "pumpkin")
	for side: int in [-1, 1]:
		var loop: PackedByteArray = _poly_mask(48, 20, PackedVector2Array([
			Vector2(24, 7), Vector2(24 + side * 18, 0), Vector2(24 + side * 23, 3), Vector2(24 + side * 23, 12),
			Vector2(24 + side * 18, 16), Vector2(24, 12),
		]))
		_outlined(img, 0, 0, loop, 48, 20, "pumpkin")
		var fold: PackedByteArray = _poly_mask(48, 20, PackedVector2Array([
			Vector2(24, 8), Vector2(24 + side * 15, 4), Vector2(24 + side * 15, 11), Vector2(24, 11),
		]))
		_paint(img, 0, 0, _shrink(_minus(fold, _empty_mask(48, 20)), 48, 20), 48, 20, "pumpkin-light")
	var knot: PackedByteArray = _round_rect_mask(48, 20, Rect2i(19, 4, 10, 12), ROUND_SM, false)
	_outlined(img, 0, 0, knot, 48, 20, "pumpkin-light")
	_rect(img, 22, 7, 4, 1, "pumpkin")
	return img


## Pixels whose centre is inside the polygon.
func _poly_mask(w: int, h: int, points: PackedVector2Array) -> PackedByteArray:
	var mask: PackedByteArray = _empty_mask(w, h)
	for y: int in h:
		for x: int in w:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				mask[y * w + x] = 1
	return mask


# ================================================================================================
# Lettering
# ================================================================================================

## A word as a mask: {mask, w, h}. Each design pixel is a scale x scale block; letters are LETTER_GAP
## design px apart and bounce by BOUNCE px (times scale / 3, at least 1).
func _word(text: String, scale: int) -> Dictionary:
	var bounce_px: int = maxi(1, scale / 3)
	var pad: int = bounce_px
	var w: int = 0
	for i: int in text.length():
		var ch: String = text[i]
		if ch == " ":
			w += SPACE_W * scale
			continue
		if not GLYPHS.has(ch):
			push_error("no glyph '%s'" % ch)
			_ok = false
			continue
		var glyph: Array = GLYPHS[ch]
		w += String(glyph[0]).length() * scale + (LETTER_GAP * scale if i < text.length() - 1 else 0)
	var h: int = GLYPH_ROWS * scale + 2 * pad
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(w * h)
	var x: int = 0
	var letter: int = 0
	var lefts: Array[int] = []
	for i: int in text.length():
		var ch: String = text[i]
		if ch == " ":
			x += SPACE_W * scale
			continue
		if not GLYPHS.has(ch):
			continue
		var glyph: Array = GLYPHS[ch]
		var gw: int = String(glyph[0]).length()
		lefts.append(x)
		var dy: int = pad + BOUNCE[letter % BOUNCE.size()] * bounce_px
		for gy: int in GLYPH_ROWS:
			var row: String = glyph[gy]
			if row.length() != gw:
				push_error("glyph '%s' row %d: %d chars, want %d" % [ch, gy, row.length(), gw])
				_ok = false
				continue
			for gx: int in gw:
				if row[gx] != "#":
					continue
				for sy: int in scale:
					for sx: int in scale:
						mask[(dy + gy * scale + sy) * w + x + gx * scale + sx] = 1
		x += gw * scale + LETTER_GAP * scale
		letter += 1
	return {"mask": mask, "w": w, "h": h, "lefts": lefts, "scale": scale}


## Draws a word with a 1 px ink outline (the mask dilated by 1), a fill, an optional 1 px highlight on
## each stroke's top, and an optional ink drop of `shadow` px. (ox, oy) is the outline's top-left: the word
## needs w + 2 by h + 2 + shadow px.
func _letter(img: Image, ox: int, oy: int, word: Dictionary, fill: String, highlight: String, shadow: int) -> void:
	var w: int = int(word["w"]) + 2
	var h: int = int(word["h"]) + 2
	var core: PackedByteArray = _pad(word["mask"], int(word["w"]), int(word["h"]), 1)
	var outline: PackedByteArray = _dilate(core, w, h)
	if shadow > 0:
		_paint(img, ox, oy + shadow, outline, w, h, "ink")
	_paint(img, ox, oy, outline, w, h, "ink")
	_paint(img, ox, oy, core, w, h, fill)
	if highlight != "":
		for y: int in h:
			for x: int in w:
				if _in(core, w, h, x, y) and not _in(core, w, h, x, y - 1):
					_px(img, ox + x, oy + y, highlight)


## Draws a word's strokes only (no outline): knocked-out lettering on a filled shape (the stamp).
func _letter_plain(img: Image, ox: int, oy: int, word: Dictionary, fill: String) -> void:
	_paint(img, ox, oy, word["mask"], int(word["w"]), int(word["h"]), fill)


# ================================================================================================
# Card picture helpers (outline-exempt scenes)
# ================================================================================================

func _cloud(img: Image, cx: int, by: int, s: int) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	_rect(img, cx - 2 * s, by - s, 4 * s, s, "art-sky-light")
	_paint(img, 0, 0, _disc_mask(w, h, cx - s, by - s, s), w, h, "art-sky-light")
	_paint(img, 0, 0, _disc_mask(w, h, cx + s, by - s, s), w, h, "art-sky-light")
	_paint(img, 0, 0, _disc_mask(w, h, cx, by - s - s / 2, s + 2), w, h, "art-sky-light")


func _cottage(img: Image, x: int, wall_top: int) -> void:
	_roof(img, x + 20, wall_top - 16, wall_top + 1, "ink")
	_roof(img, x + 20, wall_top - 15, wall_top, "wood-dark")
	_box(img, x, wall_top, 40, 61 - wall_top, "wood-light")
	for y: int in range(wall_top + 4, 60, 4):
		_rect(img, x + 1, y, 38, 1, "wood")
	_box(img, x + 6, wall_top + 12, 9, 61 - wall_top - 12, "wood-dark")
	_box(img, x + 22, wall_top + 8, 11, 9, "art-sky-light")
	_rect(img, x + 27, wall_top + 9, 1, 7, "ink")


func _bunting(img: Image) -> void:
	for x: int in CARD_W:
		var y: int = 4 + roundi(4.0 * sin(PI * posmod(x, 92) / 92.0))
		_px(img, x, y, "ink")
		if x % 12 == 6:
			for row: int in 5:
				var half: int = (5 - row) / 2
				_rect(img, x - half, y + 1 + row, 2 * half + 1, 1, "bat-purple")


## Copies one 32 x 32 frame of a character sheet (hard alpha) onto the picture with its top-left at
## (x, y); `flip` mirrors it.
func _sprite(img: Image, path: String, frame: int, x: int, y: int, flip: bool = false) -> void:
	var sheet: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if sheet == null:
		push_error("cannot load %s" % path)
		_ok = false
		return
	var one: Image = sheet.get_region(Rect2i(frame * 32, 0, 32, 32))
	one.convert(Image.FORMAT_RGBA8)
	if flip:
		one.flip_x()
	_blit(img, one, x, y)


func _box(img: Image, x: int, y: int, w: int, h: int, fill: String) -> void:
	_rect(img, x, y, w, h, "ink")
	_rect(img, x + 1, y + 1, w - 2, h - 2, fill)


## A triangle with its apex at (cx, top), 1 px wider each side per row, down to `bottom`.
func _roof(img: Image, cx: int, top: int, bottom: int, color: String) -> void:
	for y: int in range(top, bottom):
		var half: int = y - top + 1
		_rect(img, cx - half, y, 2 * half, 1, color)


# ================================================================================================
# Masks
# ================================================================================================

func _in(mask: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and mask[y * w + x] != 0


func _empty_mask(w: int, h: int) -> PackedByteArray:
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(w * h)
	return mask


## A w x h rect with stepped corners: insets[i] px cut from both ends of row i from the top and bottom.
func _round_mask(w: int, h: int, insets: Array[int]) -> PackedByteArray:
	return _round_rect_mask(w, h, Rect2i(0, 0, w, h), insets, false)


## A rect inside a w x h mask with stepped corners; `right_only` rounds only the right end (the thumb).
func _round_rect_mask(w: int, h: int, r: Rect2i, insets: Array[int], right_only: bool) -> PackedByteArray:
	var mask: PackedByteArray = _empty_mask(w, h)
	for y: int in range(r.position.y, r.end.y):
		var row: int = mini(y - r.position.y, r.end.y - 1 - y)
		var inset: int = insets[row] if row < insets.size() else 0
		var left: int = r.position.x + (0 if right_only else inset)
		for x: int in range(left, r.end.x - inset):
			if x >= 0 and x < w and y >= 0 and y < h:
				mask[y * w + x] = 1
	return mask


func _rect_mask(w: int, h: int, x0: int, y0: int, rw: int, rh: int) -> PackedByteArray:
	return _round_rect_mask(w, h, Rect2i(x0, y0, rw, rh), SQUARE, false)


## Pixels whose centre is within r of (cx, cy).
func _disc_mask(w: int, h: int, cx: float, cy: float, r: float) -> PackedByteArray:
	return _ellipse_mask(w, h, cx, cy, r, r)


func _ellipse_mask(w: int, h: int, cx: float, cy: float, rx: float, ry: float) -> PackedByteArray:
	var mask: PackedByteArray = _empty_mask(w, h)
	for y: int in h:
		for x: int in w:
			var dx: float = (x - cx) / rx
			var dy: float = (y - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				mask[y * w + x] = 1
	return mask


func _union(masks: Array) -> PackedByteArray:
	var out: PackedByteArray = (masks[0] as PackedByteArray).duplicate()
	for mask: PackedByteArray in masks:
		for i: int in out.size():
			if mask[i] != 0:
				out[i] = 1
	return out


func _minus(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = a.duplicate()
	for i: int in out.size():
		if b[i] != 0:
			out[i] = 0
	return out


## The pixels of the mask whose four neighbours are all in it.
func _shrink(mask: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var out: PackedByteArray = _empty_mask(w, h)
	for y: int in h:
		for x: int in w:
			if _in(mask, w, h, x, y) and _in(mask, w, h, x - 1, y) and _in(mask, w, h, x + 1, y) \
					and _in(mask, w, h, x, y - 1) and _in(mask, w, h, x, y + 1):
				out[y * w + x] = 1
	return out


## The mask grown by 1 px to its four neighbours.
func _dilate(mask: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var out: PackedByteArray = mask.duplicate()
	for y: int in h:
		for x: int in w:
			if _in(mask, w, h, x, y):
				for step: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var nx: int = x + step.x
					var ny: int = y + step.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						out[ny * w + nx] = 1
	return out


func _dilate_n(mask: PackedByteArray, w: int, h: int, n: int) -> PackedByteArray:
	var out: PackedByteArray = mask
	for i: int in n:
		out = _dilate(out, w, h)
	return out


## The mask with `p` empty px added on every side.
func _pad(mask: PackedByteArray, w: int, h: int, p: int) -> PackedByteArray:
	var nw: int = w + 2 * p
	var out: PackedByteArray = _empty_mask(nw, h + 2 * p)
	for y: int in h:
		for x: int in w:
			if mask[y * w + x] != 0:
				out[(y + p) * nw + x + p] = 1
	return out


# ================================================================================================
# Painting
# ================================================================================================

func _new(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func _color(color_name: String) -> Color:
	if not Proto.PALETTE.has(color_name):
		push_error("'%s' is not a palette colour" % color_name)
		_ok = false
		return Color(1, 0, 1, 1)
	return Color.html(Proto.PALETTE[color_name])


func _px(img: Image, x: int, y: int, color_name: String) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, _color(color_name))


func _rect(img: Image, x: int, y: int, w: int, h: int, color_name: String) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_px(img, xx, yy, color_name)


func _paint(img: Image, ox: int, oy: int, mask: PackedByteArray, w: int, h: int, color_name: String) -> void:
	for y: int in h:
		for x: int in w:
			if mask[y * w + x] != 0:
				_px(img, ox + x, oy + y, color_name)


## Paints a mask with a 1 px ink outline: a mask pixel with a 4-neighbour outside the mask is ink.
func _outlined(img: Image, ox: int, oy: int, mask: PackedByteArray, w: int, h: int, fill: String) -> void:
	_paint(img, ox, oy, mask, w, h, "ink")
	_paint(img, ox, oy, _shrink(mask, w, h), w, h, fill)


## Copies the opaque pixels of `src` onto `img` at (x, y).
func _blit(img: Image, src: Image, x: int, y: int) -> void:
	for sy: int in src.get_height():
		for sx: int in src.get_width():
			var c: Color = src.get_pixel(sx, sy)
			if c.a8 == 255 and x + sx >= 0 and y + sy >= 0 and x + sx < img.get_width() and y + sy < img.get_height():
				img.set_pixel(x + sx, y + sy, c)


## An ASCII map painted with `legend` onto a new w x h image. A bad map fails the run.
func _map(w: int, h: int, rows: Array[String], legend: Dictionary[String, String]) -> Image:
	var img: Image = _new(w, h)
	if rows.size() != h:
		push_error("map has %d rows, want %d" % [rows.size(), h])
		_ok = false
		return img
	for y: int in h:
		var row: String = rows[y]
		if row.length() != w:
			push_error("map row %d: %d chars, want %d: %s" % [y, row.length(), w, row])
			_ok = false
			continue
		for x: int in w:
			var ch: String = row[x]
			if ch == ".":
				continue
			if not legend.has(ch):
				push_error("map (%d,%d): '%s' not in legend" % [x, y, ch])
				_ok = false
				continue
			_px(img, x, y, legend[ch])
	return img


## A symmetric map from its left halves: each row followed by its mirror.
func _sym(halves: Array[String]) -> Array[String]:
	var rows: Array[String] = []
	for half: String in halves:
		rows.append(half + half.reverse())
	return rows


## The image cropped to its opaque pixels plus a 1 px transparent margin.
func _trim(img: Image) -> Image:
	var used: Rect2i = img.get_used_rect()
	var out: Image = _new(used.size.x + 2, used.size.y + 2)
	out.blit_rect(img, used, Vector2i(1, 1))
	return out


## Turns every opaque non-ink pixel with a transparent 4-neighbour (or on the image edge) into ink, so a
## sheared shape keeps a closed 1 px outline.
func _close_outline(img: Image) -> Image:
	var out: Image = img.duplicate() as Image
	var ink: Color = _color("ink")
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in h:
		for x: int in w:
			var c: Color = img.get_pixel(x, y)
			if c.a8 == 0 or c.to_html(false) == ink.to_html(false):
				continue
			for step: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nx: int = x + step.x
				var ny: int = y + step.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or img.get_pixel(nx, ny).a8 == 0:
					out.set_pixel(x, y, ink)
					break
	return out


## Rotates by `degrees` (negative = counter-clockwise on screen, right end up) with three shears (Paeth):
## x-shear by -tan(a/2), y-shear by sin(a), x-shear by -tan(a/2). Whole rows / columns move, so every
## pixel keeps its colour and none is lost.
func _rotate(img: Image, degrees: float) -> Image:
	var a: float = deg_to_rad(degrees)
	var pad: int = ceili(maxf(img.get_width(), img.get_height()) * absf(sin(a))) + 4
	var big: Image = _new(img.get_width() + 2 * pad, img.get_height() + 2 * pad)
	big.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(pad, pad))
	var t: float = -tan(a / 2.0)
	var s: float = sin(a)
	big = _shear_x(big, t)
	big = _shear_y(big, s)
	big = _shear_x(big, t)
	return big


## Skews by `degrees` (negative: right end up): each column moves up or down by whole pixels.
func _skew(img: Image, degrees: float) -> Image:
	var pad: int = ceili(img.get_width() * absf(tan(deg_to_rad(degrees)))) / 2 + 4
	var big: Image = _new(img.get_width() + 8, img.get_height() + 2 * pad)
	big.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(4, pad))
	return _shear_y(big, tan(deg_to_rad(degrees)))


func _shear_x(img: Image, k: float) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var out: Image = _new(w, h)
	var cy: float = h / 2.0
	for y: int in h:
		var dx: int = roundi(k * (y + 0.5 - cy))
		for x: int in w:
			var nx: int = x + dx
			if nx >= 0 and nx < w:
				out.set_pixel(nx, y, img.get_pixel(x, y))
	return out


func _shear_y(img: Image, k: float) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var out: Image = _new(w, h)
	var cx: float = w / 2.0
	for x: int in w:
		var dy: int = roundi(k * (x + 0.5 - cx))
		for y: int in h:
			var ny: int = y + dy
			if ny >= 0 and ny < h:
				out.set_pixel(x, ny, img.get_pixel(x, y))
	return out


func _save(image: Image, path: String) -> void:
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s (%dx%d)" % [path, error_string(err), image.get_width(), image.get_height()])
	_check(err)
