extends GutTest
## Press Start 2P carries a "liga" table (fi, fl, ...), and Godot shapes it by default, so "fish" drew as
## an "ﬁ" block: the child saw a letter they could not type and the HUD's per-letter overlay and underline
## stopped lining up. The font's import turns "liga" off; every printable ASCII pair must draw as two cells.

const FONT_PATH: String = "res://assets/fonts/press_start_2p.ttf"
const HudScript := preload("res://scripts/run/hud.gd")
## OpenType tag "liga" as Godot stores it (TextServer.name_to_tag("liga")).
const LIGA_TAG: int = 1818847073


func test_the_import_turns_ligatures_off() -> void:
	var font: FontFile = load(FONT_PATH) as FontFile
	assert_eq(TextServerManager.get_primary_interface().name_to_tag("liga"), LIGA_TAG)
	assert_eq(font.opentype_feature_overrides.get(LIGA_TAG, -1), 0, "liga is overridden to 0")


func test_every_ascii_pair_is_two_cells_wide() -> void:
	var font: Font = load(FONT_PATH) as Font
	var size: int = HudScript.LINE_FONT_SIZE
	var cell: float = font.get_string_size("a", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var merged: Array[String] = []
	for a: int in range(33, 127):
		for b: int in range(33, 127):
			var pair: String = char(a) + char(b)
			if font.get_string_size(pair, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x != cell * 2.0:
				merged.append(pair)
	assert_eq(merged, [] as Array[String], "pairs that do not draw as two cells: %s" % [merged])
