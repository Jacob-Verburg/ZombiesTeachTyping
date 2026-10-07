extends GutTest
## Readability floors (Story 5.2, NFR7): every MVP screen at 640×360 is walked and every Label and Button a
## kid can see must be at least 16 px (the theme font size), the HUD target letter at least 32 px (the
## `{typography.target}` token = font size; Press Start 2P ink: caps 28 px, x-height 20 px), and every
## control a kid can click or focus at least 32 px tall. This is the cross-screen floor; each screen's own
## test keeps owning its layout and fit. Screens without a fit test of their own (pause panel, countdown, the
## confirm prompt with every live item's question) get one here.
## Screens are instanced like tests/integration/test_screen_flow.gd: disabled, recorder seams before add_child,
## a temp-dir PlayerData for anything that writes. Router.go() is never called.

const TEXT_FLOOR: int = 16
const TARGET_FLOOR: int = 32
const PARAGRAPH_FLOOR: int = 24
const CLICK_FLOOR: float = 32.0

const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TitleScene: PackedScene = preload("res://scenes/screens/title.tscn")
const MenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const ReportScene: PackedScene = preload("res://scenes/screens/report_card.tscn")
const GiftScene: PackedScene = preload("res://scenes/screens/welcome_gift.tscn")
const ClosetScene: PackedScene = preload("res://scenes/screens/crypt_closet.tscn")
const HudScene: PackedScene = preload("res://scenes/run/hud.tscn")
const PauseScene: PackedScene = preload("res://scenes/run/pause_panel.tscn")
const CountdownScene: PackedScene = preload("res://scenes/run/countdown.tscn")
const PromptScene: PackedScene = preload("res://scenes/ui/confirm_prompt.tscn")
const CardScene: PackedScene = preload("res://scenes/ui/level_card.tscn")
const TileScene: PackedScene = preload("res://scenes/ui/closet_item_tile.tscn")
const ToggleScene: PackedScene = preload("res://scenes/ui/menu_toggle.tscn")
const CounterScene: PackedScene = preload("res://scenes/ui/brain_counter.tscn")
const TargetScene: PackedScene = preload("res://scenes/levels/zombie_run/zombie_run_target.tscn")
const VillagerScene: PackedScene = preload("res://scenes/levels/zombie_run/villager.tscn")
const BlockScene: PackedScene = preload("res://scenes/levels/zombie_run/brain_block.tscn")
const CongaScene: PackedScene = preload("res://scenes/levels/zombie_run/conga_line.tscn")
const SHIPPED: Catalogue = preload("res://data/cosmetics/catalogue.tres")
const TEST_DIR: String = "user://test_readability/"

var _player: PlayerDataScript


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_player = _temp_player_data()


func after_each() -> void:
	Router.take_payload()
	_clear()
	_player = null


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


## A PlayerData on a temp-dir SaveService, so a screen that writes never reaches the real save.
func _temp_player_data() -> PlayerDataScript:
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = TEST_DIR
	add_child_autofree(save)
	var player: PlayerDataScript = PlayerDataScript.new()
	player.save_service = save
	add_child_autofree(player)
	return player


func _noop_sfx(_id: StringName) -> void:
	pass


func _noop_nav(_screen: int, _payload: Dictionary) -> void:
	pass


# --- screen builders: realistic values, the way each screen's own test fills it -------------------------

func _title() -> Control:
	var title: Control = TitleScene.instantiate() as Control
	title.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(title)
	return title


func _menu() -> Control:
	var menu: Control = MenuScene.instantiate() as Control
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	menu.set("navigate", _noop_nav)
	menu.set("is_transitioning", func() -> bool: return false)
	menu.set("player_data", _player)
	(menu.get_node("%PetSlot") as PetSlot).player_data = _player
	(menu.get_node("%Zombie").get_node("%HatSlot") as HatSlot).player_data = _player
	menu.set("toggle_fullscreen", func() -> void: pass)
	menu.set("is_fullscreen", func() -> bool: return false)
	_player.add_brains(1234)
	add_child_autofree(menu)
	# The FR27 corner note only shows in a non-persistent browser; show it so its size is checked.
	menu.call("_show_storage_notice", false)
	return menu


## The mock's example run with a bonus row and the New best stamp; every row revealed.
func _report_card() -> Control:
	var result: RunResult = RunResult.create(
			&"zombie_run", 1790000000, 120.0, 142, 9, {}, 35, 10, "all", GameConstants.END_REASON_TIMER)
	Router._store_payload({"result": result, "new_best": true})
	var card: Control = ReportScene.instantiate() as Control
	card.process_mode = Node.PROCESS_MODE_DISABLED
	card.set("navigate", _noop_nav)
	card.set("play_sfx", _noop_sfx)
	card.set("play_music", _noop_sfx)
	card.set("player_data", _player)
	add_child_autofree(card)
	for i: int in 7:
		var row: Control = card.get_node_or_null("%%Row%d" % i) as Control
		if row != null:
			row.show()
	(card.get_node("%Stamp") as CanvasItem).show()
	return card


func _gift() -> Control:
	var gift: Control = GiftScene.instantiate() as Control
	gift.process_mode = Node.PROCESS_MODE_DISABLED
	gift.set("navigate", _noop_nav)
	gift.set("play_sfx", _noop_sfx)
	gift.set("play_music", _noop_sfx)
	gift.set("player_data", _player)
	add_child_autofree(gift)
	return gift


func _closet() -> Control:
	var closet: Control = ClosetScene.instantiate() as Control
	closet.process_mode = Node.PROCESS_MODE_DISABLED
	closet.set("navigate", _noop_nav)
	closet.set("is_transitioning", func() -> bool: return false)
	closet.set("play_sfx", _noop_sfx)
	closet.set("play_music", _noop_sfx)
	closet.set("player_data", _player)
	_player.add_brains(9999)
	add_child_autofree(closet)
	return closet


func _hud() -> Control:
	var hud: Control = HudScene.instantiate() as Control
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(hud)
	var config: LevelConfig = LevelConfig.new()
	config.duration_s = 120.0
	config.target_mode = LevelConfig.TargetMode.LETTER
	hud.call("setup", config, "f")
	hud.call("set_counts", 142, 9)
	hud.call("update_clock", 62.0, 142)
	hud.call("set_caps_hint", true)
	return hud


func _pause_panel() -> Control:
	var panel: Control = PauseScene.instantiate() as Control
	add_child_autofree(panel)
	panel.call("open", false, true)
	return panel


func _countdown() -> Control:
	var countdown: Control = CountdownScene.instantiate() as Control
	add_child_autofree(countdown)
	countdown.call("start", GameConstants.COUNTDOWN_FROM, GameConstants.COUNTDOWN_STEP_S)
	return countdown


func _prompt(question: String) -> ConfirmPrompt:
	var prompt: ConfirmPrompt = PromptScene.instantiate() as ConfirmPrompt
	prompt.process_mode = Node.PROCESS_MODE_DISABLED
	prompt.answer_delay_ms = 0
	add_child_autofree(prompt)
	prompt.open(question)
	return prompt


func _widgets() -> Array[Node]:
	var out: Array[Node] = []
	var entry: LevelEntry = LevelEntry.new()
	entry.id = &"zombie_run"
	entry.display_name = "Pitchfork Panic"
	entry.available = true
	var card: LevelCard = CardScene.instantiate() as LevelCard
	card.setup(entry)
	out.append(card)
	var tile: ClosetItemTile = TileScene.instantiate() as ClosetItemTile
	tile.setup(SHIPPED.get_item(&"hat_pumpkin"))
	out.append(tile)
	var toggle: MenuToggle = ToggleScene.instantiate() as MenuToggle
	toggle.kind = MenuToggle.Kind.FULLSCREEN
	out.append(toggle)
	out.append(CounterScene.instantiate())
	for node: Node in out:
		add_child_autofree(node)
	tile.show_state(ClosetItemTile.State.CANT_AFFORD)
	return out


func _playfield() -> Array[Node]:
	var target: ZombieRunTarget = TargetScene.instantiate() as ZombieRunTarget
	target.setup("w", 1)
	var villager: Villager = VillagerScene.instantiate() as Villager
	villager.setup("m", 2)
	villager.configure(0.4)
	var block: BrainBlock = BlockScene.instantiate() as BrainBlock
	block.setup("q", 3)
	block.configure(48.0, 1)
	var out: Array[Node] = [target, villager, block]
	for node: Node in out:
		node.process_mode = Node.PROCESS_MODE_DISABLED
		add_child_autofree(node)
	var leader: Node2D = Node2D.new()
	add_child_autofree(leader)
	var line: CongaLine = CongaScene.instantiate() as CongaLine
	line.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(line)
	line.configure(leader, 3)
	for i: int in 13:
		line.join(0.0)
	out.append(line)
	return out


## Every MVP screen and the run's parts, built and laid out.
func _all_roots() -> Array[Node]:
	var roots: Array[Node] = [_title(), _menu(), _report_card(), _gift(), _closet(), _hud(), _pause_panel(),
			_countdown(), _prompt("Buy the Pumpkin hat for 100 brains?")]
	roots.append_array(_widgets())
	roots.append_array(_playfield())
	return roots


# --- walkers ----------------------------------------------------------------------------------------------

func _collect(node: Node, out: Array[Control]) -> void:
	if node is Label or node is BaseButton or node is ClosetItemTile or node is LevelCard:
		out.append(node as Control)
	for child: Node in node.get_children():
		_collect(child, out)


func _text_nodes(roots: Array[Node]) -> Array[Control]:
	var out: Array[Control] = []
	for root: Node in roots:
		_collect(root, out)
	return out


## A control a kid can click or focus: a BaseButton, Closet tile or level card shown on screen that takes focus
## or the mouse.
func _is_clickable(control: Control) -> bool:
	var is_target: bool = control is BaseButton or control is ClosetItemTile or control is LevelCard
	if not is_target or not control.is_visible_in_tree():
		return false
	return control.focus_mode != Control.FOCUS_NONE or control.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _describe(control: Control) -> String:
	var owner_name: String = control.owner.name if control.owner != null else "?"
	return "%s/%s" % [owner_name, control.name]


# --- tests --------------------------------------------------------------------------------------------------

func test_every_label_and_button_is_at_least_16px() -> void:
	var nodes: Array[Control] = _text_nodes(_all_roots())
	await wait_process_frames(2)
	var checked: int = 0
	for control: Control in nodes:
		if control is Label or (control is Button and not (control as Button).text.is_empty()):
			assert_gte(control.get_theme_font_size(&"font_size"), TEXT_FLOOR, "%s font size" % _describe(control))
			checked += 1
	assert_gt(checked, 60, "the walk found the MVP screens' text")


func test_hud_target_letter_is_at_least_32px() -> void:
	var hud: Control = _hud()
	var target: Label = hud.get_node("%TargetLabel") as Label
	assert_gte(target.get_theme_font_size(&"font_size"), TARGET_FLOOR, "LETTER mode target")
	var config: LevelConfig = LevelConfig.new()
	config.duration_s = 120.0
	config.target_mode = LevelConfig.TargetMode.PARAGRAPH
	hud.call("setup", config, "the cat sat on the mat")
	assert_gte(target.get_theme_font_size(&"font_size"), PARAGRAPH_FLOOR, "PARAGRAPH mode target")


func test_every_clickable_is_at_least_32px_tall() -> void:
	var nodes: Array[Control] = _text_nodes(_all_roots())
	await wait_process_frames(2)
	var checked: int = 0
	for control: Control in nodes:
		if not _is_clickable(control):
			continue
		assert_gte(control.get_global_rect().size.y, CLICK_FLOOR, "%s click target height" % _describe(control))
		checked += 1
	assert_gt(checked, 15, "the walk found the MVP screens' controls")


# --- fit checks for screens without their own ----------------------------------------------------------------

func test_pause_panel_text_fits() -> void:
	var panel: Control = _pause_panel()
	await wait_process_frames(2)
	var nodes: Array[Control] = []
	_collect(panel, nodes)
	for control: Control in nodes:
		_assert_fits(control)


func test_countdown_digits_fit() -> void:
	var countdown: Control = _countdown()
	await wait_process_frames(2)
	for path: String in ["%NumberLabel", "%ShadowLabel"]:
		_assert_fits(countdown.get_node(path) as Control)


## The longest real question is the one with the longest live item name; every live item's question fits.
func test_confirm_prompt_fits_every_live_question() -> void:
	var closet: Control = _closet()
	await wait_process_frames(2)
	var prompt: ConfirmPrompt = closet.get_node("%ConfirmPrompt") as ConfirmPrompt
	var asked: int = 0
	for item: CosmeticItem in SHIPPED.items:
		if not item.is_available:
			continue
		var tile: ClosetItemTile = closet.call("get_tile", item.id) as ClosetItemTile
		tile.activated.emit(item.id)
		assert_true(prompt.is_open(), "%s opens the prompt" % item.id)
		await wait_process_frames(1)
		var nodes: Array[Control] = []
		_collect(prompt, nodes)
		for control: Control in nodes:
			_assert_fits(control)
		prompt.cancel()
		asked += 1
	assert_gt(asked, 1, "every live item was asked about")


func _assert_fits(control: Control) -> void:
	if not control.is_visible_in_tree():
		return
	if control is Label:
		_assert_label_fits(control as Label)
	elif control is Button and not (control as Button).text.is_empty():
		assert_lte(control.get_minimum_size().x, control.size.x, "%s text overflows" % _describe(control))


## Same rule as test_main_menu.gd: one line fits its width; wrapped text has no word wider than the box and
## no more lines than its height holds.
func _assert_label_fits(label: Label) -> void:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	assert_gte(font_size, TEXT_FLOOR, "%s font size" % _describe(label))
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_lte(width, label.size.x, "%s '%s' overflows" % [_describe(label), label.text])
		return
	for word: String in label.text.split(" "):
		var word_width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_lte(word_width, label.size.x, "%s word '%s' overflows" % [_describe(label), word])
	var lines_height: float = label.get_line_count() * label.get_line_height()
	assert_lte(lines_height, label.size.y, "%s wraps taller than its box" % _describe(label))
