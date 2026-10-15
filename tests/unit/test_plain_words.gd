extends GutTest
## Plain words (Story 5.2, NFR9, NFR10, NFR11, NFR16): every player-facing string in the MVP is collected from
## the scenes (static `text` of every node under the MVP scene folders), the script copy (HUD prompts, toggle
## captions, Closet tile info lines, the confirm question for every live item, the report card, the gift, the
## storage notice, the conga badge) and the data (live catalogue names: all 18 since Story 9.3, non-debug
## level names), then:
## (a) each string is approved copy (exact, or a number pattern), so new copy can't ship without being added
##     here on purpose (and to EXPERIENCE.md Voice and Tone, the copy contract);
## (b) no zombie slang in labels ("Brainsss" lives in voice lines and flavor art only);
## (c) no technical text;
## (d) no ranks, grades or difficulty words (NFR10);
## (e) no all-caps words except "WPM" (Gate A: kept, the GDD stat name).
## The approved list matches the `## Copy Review` verdicts of Story 5.2 (Gate A, 2026-10-06).
## Story 10.5: the Progress screen's copy (scene, script titles, a filled live screen with its totals) is
## walked too; its strings were approved at Gate 1 (2026-10-14).
## Debug-only screens are exempt: keyboard_test.tscn, scenes/debug/, the art reviews, the debug-only Test level.

const SCENE_DIRS: Array[String] = [
	"res://scenes/screens/", "res://scenes/run/", "res://scenes/ui/", "res://scenes/levels/zombie_run/",
]
const EXEMPT_SCENES: Array[String] = ["res://scenes/screens/keyboard_test.tscn"]

const APPROVED_COPY: Array[String] = [
	# Title
	"Click or press any key",
	# Main menu
	"Zombie Run", "Horde Rush", "Pitchfork Panic", "Crypt Closet", "Music", "Sound", "Fullscreen",
	"This browser might forget your brains",
	# Story 6.8: the Locked card's hint sign and the New badge
	"Finish Zombie Run to open!", "Finish Horde Rush to open!", "New!",
	# Run HUD (the word / text prompts are post-MVP modes, spec verbatim)
	"Timer", "Keys", "WPM", "Errors", "Type the letter to start!", "Type the word to start!",
	"Type the text to start!", "Caps Lock is on",
	# Pause panel
	"Paused", "Resume", "Quit to Menu",
	# Report card
	"Report Card", "Keys Typed", "Accuracy", "Lesson Time", "Brains Collected", "Play Again", "Menu",
	"Enter", "Esc",
	# Welcome Gift
	"Welcome gift!", "Open the Crypt Closet",
	# Crypt Closet
	"Hats", "Pets", "Coming soon", "Buy", "Wear", "Wearing", "Yes", "No",
	# Live catalogue items (locked items show no name). A newly live item is added here on purpose.
	# Story 9.3: the full catalogue (FR75), hats then pets in grid order.
	"Pumpkin hat", "Witch hat", "Bunny ears", "Santa hat", "Leprechaun hat", "Heart headband", "Top hat",
	"Pirate hat", "Golden crown",
	"Cute ghost", "Black cat", "Spider", "Orange cat", "Bat", "Crow", "Wolf-dog", "Floating eyeball",
	"Brain buddy",
	# Story 10.5: the Progress screen (Gate 1, 2026-10-14)
	"Progress", "Words per minute", "Practice time", "Best WPM", "Brains Earned", "Time Practiced",
	"Finish a game to see your charts!",
	# Story 11.1: the name screen (Gate 1, 2026-10-15). The kid's typed name is their own words, never copy.
	"Name your zombie!", "Done",
	# Story 11.2: the "Who's playing?" picker and the name screen's new-zombie mode (Gate 1, 2026-10-15). "Zombie" is
	# the card of a zombie with no name yet (GameConstants.ZOMBIE_NAME_DEFAULT); real names are never copy.
	"Who's playing?", "New zombie", "Back", "Zombie",
]
## Numbers and formatted values: counts, "+N", "+N bonus", "Need N more", times, percents, the conga badge,
## the WPM placeholder (en dash), the confirm question for a live item (a word may carry one hyphenated part,
## "Wolf-dog"; no digits, apostrophes or capitals after the first letter).
const APPROVED_PATTERNS: Array[String] = [
	"^\\d+$", "^\\+\\d+$", "^\\+\\d+ bonus$", "^Need \\d+ more$", "^\\d+:\\d\\d$", "^\\d+%$", "^×\\d+$", "^–$",
	# Story 10.5: Time Practiced ("45 min", "1 hr 5 min").
	"^\\d+ min$", "^\\d+ hr \\d+ min$",
	"^Buy the [A-Z][a-z]+(-[a-z]+)?( [a-z]+(-[a-z]+)?)* for \\d+ brains\\?$",
]
const SLANG: String = "(?i)(brains{2,}|bra{2,}i*n|\\bu{2,}h+|\\bgr{2,}|\\bargh+|\\bra{2,}wr|\\bmm{2,}|\\bnom\\b)"
const TECHNICAL: String = "(?i)(error:|\\bnull\\b|\\bnil\\b|invalid|exception|failed|res://|user://|%s|%d|\\w_\\w|StringName|&\")"
const RANKS: String = "(?i)(\\beasy\\b|\\bhard\\b|difficult|\\brank|\\bgrade|beginner|expert|\\blevel \\d|noob|\\bpro\\b|\\btier)"
const ALL_CAPS_ALLOWED: Array[String] = ["WPM"]

const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const HudScript := preload("res://scripts/run/hud.gd")
const MainMenuScript := preload("res://scripts/screens/main_menu.gd")
const ReportScript := preload("res://scripts/screens/report_card.gd")
const TrendsScript := preload("res://scripts/screens/trends.gd")
const TrendsScene: PackedScene = preload("res://scenes/screens/trends.tscn")
const NameZombieScene: PackedScene = preload("res://scenes/screens/name_zombie.tscn")
const WhosPlayingScene: PackedScene = preload("res://scenes/screens/whos_playing.tscn")
const ClosetScene: PackedScene = preload("res://scenes/screens/crypt_closet.tscn")
const ReportScene: PackedScene = preload("res://scenes/screens/report_card.tscn")
const GiftScene: PackedScene = preload("res://scenes/screens/welcome_gift.tscn")
const CongaScene: PackedScene = preload("res://scenes/levels/zombie_run/conga_line.tscn")
const SHIPPED: Catalogue = preload("res://data/cosmetics/catalogue.tres")
const REGISTRY: LevelRegistry = preload("res://data/levels/level_registry.tres")
const TEST_DIR: String = "user://test_plain_words/"

var _player: PlayerDataScript


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = TEST_DIR
	add_child_autofree(save)
	_player = PlayerDataScript.new()
	_player.save_service = save
	add_child_autofree(_player)


func after_each() -> void:
	Router.take_payload()
	_clear()
	_player = null


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _noop(_id: StringName) -> void:
	pass


func _noop_nav(_screen: int, _payload: Dictionary) -> void:
	pass


# --- collection --------------------------------------------------------------------------------------------

## Static `text` of every node in every MVP scene, read from the PackedScene state (no instancing).
func _scene_strings() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	for dir: String in SCENE_DIRS:
		for file_name: String in DirAccess.get_files_at(dir):
			var path: String = dir + file_name
			if not file_name.ends_with(".tscn") or path in EXEMPT_SCENES:
				continue
			var scene: PackedScene = load(path) as PackedScene
			assert_not_null(scene, "%s loads" % path)
			if scene == null:
				continue
			var state: SceneState = scene.get_state()
			for i: int in state.get_node_count():
				for p: int in state.get_node_property_count(i):
					if state.get_node_property_name(i, p) == &"text":
						# The node path, not the name: same-named nodes (TagLabel on each tile) must not overwrite each other.
						out["%s:%s" % [file_name, state.get_node_path(i)]] = str(state.get_node_property_value(i, p))
	return out


## The script and data copy, and the strings a live screen formats at runtime.
func _runtime_strings() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	for mode: LevelConfig.TargetMode in HudScript.PROMPTS:
		out["hud prompt %d" % mode] = HudScript.PROMPTS[mode]
	out["hud wpm placeholder"] = HudScript.WPM_PLACEHOLDER
	for kind: MenuToggle.Kind in MenuToggle.CAPTIONS:
		out["toggle %d" % kind] = MenuToggle.CAPTIONS[kind]
	out["storage notice"] = MainMenuScript.STORAGE_NOTICE_TEXT
	out["report fallback"] = ReportScript.FALLBACK_HEADING
	out["trends wpm title"] = TrendsScript.WPM_TITLE
	out["trends accuracy title"] = TrendsScript.ACCURACY_TITLE
	out["trends practice title"] = TrendsScript.PRACTICE_TITLE
	for entry: LevelEntry in REGISTRY.menu_entries():
		out["level %s" % entry.id] = entry.display_name
		if entry.unlocked_by != &"":
			out["hint %s" % entry.id] = "Finish %s to open!" % REGISTRY.get_entry(entry.unlocked_by).display_name
	for state: ClosetItemTile.State in ClosetItemTile.State.values():
		var lines: PackedStringArray = ClosetItemTile.info_lines(null, state, 40)
		out["tile null %d" % state] = lines[0]
	for item: CosmeticItem in SHIPPED.items:
		if not item.is_available:
			continue
		for state: ClosetItemTile.State in ClosetItemTile.State.values():
			var lines: PackedStringArray = ClosetItemTile.info_lines(item, state, 40)
			out["tile %s %d name" % [item.id, state]] = lines[0]
			out["tile %s %d words" % [item.id, state]] = lines[1]
	return out


func _live_strings() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	# Every live item's confirm question, as the Closet formats it.
	var closet: Control = ClosetScene.instantiate() as Control
	closet.process_mode = Node.PROCESS_MODE_DISABLED
	closet.set("navigate", _noop_nav)
	closet.set("is_transitioning", func() -> bool: return false)
	closet.set("play_sfx", _noop)
	closet.set("play_music", _noop)
	closet.set("player_data", _player)
	_player.add_brains(9999)
	add_child_autofree(closet)
	var prompt: ConfirmPrompt = closet.get_node("%ConfirmPrompt") as ConfirmPrompt
	for item: CosmeticItem in SHIPPED.items:
		if item.is_available:
			(closet.call("get_tile", item.id) as ClosetItemTile).activated.emit(item.id)
			out["confirm %s" % item.id] = (prompt.get_node("%QuestionLabel") as Label).text
			prompt.cancel()
	_collect_labels(closet, "closet", out)
	# The report card filled with a bonus run (heading = the level name, "+N bonus", percent, time).
	var result: RunResult = RunResult.create(
			&"zombie_run", 1790000000, 120.0, 142, 9, {}, 35, 10, "all", GameConstants.END_REASON_TIMER)
	Router._store_payload({"result": result, "new_best": true})
	var card: Control = ReportScene.instantiate() as Control
	card.process_mode = Node.PROCESS_MODE_DISABLED
	card.set("navigate", _noop_nav)
	card.set("play_sfx", _noop)
	card.set("play_music", _noop)
	card.set("player_data", _player)
	add_child_autofree(card)
	_collect_labels(card, "report", out)
	# The gift's "+100".
	var gift: Control = GiftScene.instantiate() as Control
	gift.process_mode = Node.PROCESS_MODE_DISABLED
	gift.set("navigate", _noop_nav)
	gift.set("play_sfx", _noop)
	gift.set("play_music", _noop)
	gift.set("player_data", _player)
	add_child_autofree(gift)
	_collect_labels(gift, "gift", out)
	# The Progress screen filled (titles, totals, "1 hr 5 min").
	for i: int in 3:
		_player.record_run(RunResult.create(
				&"zombie_run", 1790000000 + i * 86400, 1300.0, 300, 4, {}, 6, 0, "all", GameConstants.END_REASON_TIMER))
	var trends: Control = TrendsScene.instantiate() as Control
	trends.process_mode = Node.PROCESS_MODE_DISABLED
	trends.set("navigate", _noop_nav)
	trends.set("play_sfx", _noop)
	trends.set("play_music", _noop)
	trends.set("player_data", _player)
	add_child_autofree(trends)
	_collect_labels(trends, "trends", out)
	# The name screen as a kid first sees it: the zombie has no name, so %NameLabel is empty (a typed name is
	# user content and never part of the copy check).
	var naming: Control = NameZombieScene.instantiate() as Control
	naming.process_mode = Node.PROCESS_MODE_DISABLED
	naming.set("navigate", _noop_nav)
	naming.set("play_sfx", _noop)
	naming.set("play_music", _noop)
	naming.set("player_data", _player)
	add_child_autofree(naming)
	assert_eq((naming.get_node("%NameLabel") as Label).text, "", "no name leaks into the copy walk")
	_collect_labels(naming, "name", out)
	# Story 11.2: the name screen in new-zombie mode (Back shown) and the picker. The temp zombie has no name, so
	# its card shows the default "Zombie" and no kid's name reaches the copy check.
	Router._store_payload({"new_zombie": true})
	var new_naming: Control = NameZombieScene.instantiate() as Control
	new_naming.process_mode = Node.PROCESS_MODE_DISABLED
	new_naming.set("navigate", _noop_nav)
	new_naming.set("play_sfx", _noop)
	new_naming.set("play_music", _noop)
	new_naming.set("player_data", _player)
	add_child_autofree(new_naming)
	assert_true((new_naming.get_node("%BackButton") as Control).visible, "the walk sees Back")
	_collect_labels(new_naming, "new name", out)
	assert_eq(_player.get_zombie_name(), "", "no name leaks into the copy walk")
	var picker: Control = WhosPlayingScene.instantiate() as Control
	picker.process_mode = Node.PROCESS_MODE_DISABLED
	picker.set("navigate", _noop_nav)
	picker.set("play_sfx", _noop)
	picker.set("play_music", _noop)
	picker.set("player_data", _player)
	add_child_autofree(picker)
	_collect_labels(picker, "picker", out)
	# The conga badge at 13.
	var leader: Node2D = Node2D.new()
	add_child_autofree(leader)
	var line: CongaLine = CongaScene.instantiate() as CongaLine
	line.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(line)
	line.configure(leader, 3)
	for i: int in 13:
		line.join(0.0)
	out["conga badge"] = (line.get_node("%BadgeLabel") as Label).text
	return out


## Keyed by the path from `root`, not the node name: same-named labels must not overwrite each other.
func _collect_labels(node: Node, prefix: String, out: Dictionary[String, String], root: Node = null) -> void:
	if root == null:
		root = node
	if node is Label:
		out["%s %s" % [prefix, root.get_path_to(node)]] = (node as Label).text
	elif node is Button:
		out["%s %s" % [prefix, root.get_path_to(node)]] = (node as Button).text
	for child: Node in node.get_children():
		_collect_labels(child, prefix, out, root)


func _all_strings() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = _scene_strings()
	out.merge(_runtime_strings())
	out.merge(_live_strings())
	return out


# --- rules ---------------------------------------------------------------------------------------------------

func _is_approved(text: String) -> bool:
	if text in APPROVED_COPY:
		return true
	for pattern: String in APPROVED_PATTERNS:
		var regex: RegEx = RegEx.create_from_string(pattern)
		if regex.search(text) != null:
			return true
	return false


func _matches(pattern: String, text: String) -> bool:
	return RegEx.create_from_string(pattern).search(text) != null


func _all_caps_words(text: String) -> Array[String]:
	var out: Array[String] = []
	for m: RegExMatch in RegEx.create_from_string("\\b[A-Z]{2,}\\b").search_all(text):
		if m.get_string() not in ALL_CAPS_ALLOWED:
			out.append(m.get_string())
	return out


# --- tests ---------------------------------------------------------------------------------------------------

func test_the_walk_finds_the_copy() -> void:
	var strings: Dictionary[String, String] = _all_strings()
	assert_gt(strings.size(), 80, "scenes, scripts, data and live screens were all walked")
	var values: Array[String] = []
	values.assign(strings.values())
	for expected: String in ["Click or press any key", "Buy the Pumpkin hat for 100 brains?", "+10 bonus",
			"×13", "Need 40 more", "Zombie Run", "This browser might forget your brains", "+100", "Caps Lock is on",
			"Buy the Wolf-dog for 300 brains?", "Golden crown", "Words per minute", "1 hr 5 min", "Name your zombie!", "Done",
			"Who's playing?", "New zombie", "Back", "Zombie"]:
		assert_has(values, expected, "the walk saw '%s'" % expected)


func test_every_string_is_approved_copy() -> void:
	var strings: Dictionary[String, String] = _all_strings()
	for where: String in strings:
		var text: String = strings[where]
		if text.strip_edges().is_empty():
			continue
		assert_true(_is_approved(text), "%s: '%s' is not approved copy (add it on purpose)" % [where, text])


func test_no_slang_technical_rank_or_shouting() -> void:
	var strings: Dictionary[String, String] = _all_strings()
	for where: String in strings:
		var text: String = strings[where]
		assert_false(_matches(SLANG, text), "%s: zombie slang in a label: '%s'" % [where, text])
		assert_false(_matches(TECHNICAL, text), "%s: technical text: '%s'" % [where, text])
		assert_false(_matches(RANKS, text), "%s: rank / difficulty word: '%s'" % [where, text])
		assert_eq(_all_caps_words(text), [] as Array[String], "%s: all-caps word in '%s'" % [where, text])


## The rules themselves catch what they must (and let the currency word "Brains" through).
func test_the_rules_bite() -> void:
	for slang: String in ["Brainsss", "BRAAAINS", "Uuuh", "Grrr"]:
		assert_true(_matches(SLANG, slang), "slang: %s" % slang)
	assert_false(_matches(SLANG, "Brains Collected"))
	for tech: String in ["Error: null", "res://x.tscn", "Need %d more", "hat_pumpkin", "Invalid save"]:
		assert_true(_matches(TECHNICAL, tech), "technical: %s" % tech)
	assert_false(_matches(TECHNICAL, "Errors"))
	for rank: String in ["Easy mode", "Hard", "Rank 3", "Grade A", "Level 2", "Expert", "Tier 3"]:
		assert_true(_matches(RANKS, rank), "rank: %s" % rank)
	assert_false(_matches(RANKS, "Lesson Time"))
	assert_eq(_all_caps_words("QUIT"), ["QUIT"] as Array[String])
	assert_eq(_all_caps_words("WPM"), [] as Array[String])
	assert_false(_is_approved("Brainsss"), "a new string is not approved by accident")
	# Story 9.3: the confirm question allows one hyphenated part per word, and nothing looser.
	assert_true(_is_approved("Buy the Wolf-dog for 300 brains?"))
	assert_true(_is_approved("Buy the Floating eyeball for 300 brains?"))
	for loose: String in ["Buy the New Year's top hat for 300 brains?", "Buy the Hat 2 for 100 brains?",
			"Buy the Wolf-Dog for 300 brains?", "Buy the Wolf--dog for 300 brains?", "Buy the -dog for 300 brains?",
			"Buy the Wolf-dog- for 300 brains?"]:
		assert_false(_is_approved(loose), "too loose: %s" % loose)
