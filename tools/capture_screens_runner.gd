extends Node
## Dev-only (Story 5.2): the shots for tools/capture_screens.gd. A Node loaded at runtime by the SceneTree
## launcher, so the autoloads (Router, PlayerData, AudioManager, WebPlatform) exist before this script and the
## screens it preloads are compiled. Never run on its own; never shipped (tools/ is export-excluded).
## Emits `done(exit_code)` when every shot is written.

signal done(exit_code: int)

const OUT_DIR: String = "res://_bmad-output/implementation-artifacts/screenshots/5-2/"
const TEMP_SAVE_DIR: String = "user://capture_screens/"
const SIZE: Vector2i = Vector2i(640, 360)
## The hands area and the letter sign in the HUD (sketches/hud-band-2-5.md), for the 3× crops.
const HANDS_REGION: Rect2i = Rect2i(64, 304, 312, 56)
const SIGN_REGION: Rect2i = Rect2i(180, 256, 80, 48)
const Launcher := preload("res://tools/capture_screens.gd")

const ZombieHandsScript := preload("res://scripts/run/zombie_hands.gd")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TitleScene: PackedScene = preload("res://scenes/screens/title.tscn")
const MenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const ReportScene: PackedScene = preload("res://scenes/screens/report_card.tscn")
const GiftScene: PackedScene = preload("res://scenes/screens/welcome_gift.tscn")
const ClosetScene: PackedScene = preload("res://scenes/screens/crypt_closet.tscn")
const RunFrameScene: PackedScene = preload("res://scenes/run/run_frame.tscn")
const HudScene: PackedScene = preload("res://scenes/run/hud.tscn")
const PauseScene: PackedScene = preload("res://scenes/run/pause_panel.tscn")
const CountdownScene: PackedScene = preload("res://scenes/run/countdown.tscn")
const TargetScene: PackedScene = preload("res://scenes/levels/zombie_run/zombie_run_target.tscn")
const VillagerScene: PackedScene = preload("res://scenes/levels/zombie_run/villager.tscn")
const BlockScene: PackedScene = preload("res://scenes/levels/zombie_run/brain_block.tscn")
const CongaScene: PackedScene = preload("res://scenes/levels/zombie_run/conga_line.tscn")
const SHIPPED: Catalogue = preload("res://data/cosmetics/catalogue.tres")

var _mounted: Array[Node] = []
var _written: Array[String] = []


func run() -> void:
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(TEMP_SAVE_DIR)
	_clear_temp_saves()
	await get_tree().process_frame
	if get_tree().root.get_texture().get_image().get_size() != SIZE:
		printerr("capture_screens: the root renders %s, not 640×360 (stretch mode viewport?)"
				% get_tree().root.get_texture().get_image().get_size())
		done.emit(1)
		return
	await _shots_hud()
	await _shots_menu()
	await _shots_pause_and_countdown()
	await _shots_report_and_gift()
	await _shots_closet()
	await _shots_run()
	_clear_temp_saves()
	print("capture_screens: wrote %d files" % _written.size())
	done.emit(0)


# --- plumbing ---------------------------------------------------------------------------------------------------

func _temp_player_data(catalogue: Catalogue = null) -> PlayerDataScript:
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = TEMP_SAVE_DIR
	_mount(save)
	var player: PlayerDataScript = PlayerDataScript.new()
	player.save_service = save
	player.catalogue = catalogue
	_mount(player)
	return player


func _clear_temp_saves() -> void:
	for file_name: String in DirAccess.get_files_at(TEMP_SAVE_DIR):
		DirAccess.remove_absolute(TEMP_SAVE_DIR.path_join(file_name))


func _mount(node: Node) -> Node:
	get_tree().root.add_child(node)
	_mounted.append(node)
	return node


func _unmount_all() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.queue_free()
	_mounted.clear()
	Router.take_payload()
	_clear_temp_saves()


func _noop(_id: StringName) -> void:
	pass


func _noop_nav(_screen: int, _payload: Dictionary) -> void:
	pass


## Waits for the frame to be drawn, then writes <name>.png and <name>-gray.png.
func _capture(file_name: String) -> Image:
	for i: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	_save(image, file_name)
	_save(_gray(image), file_name + "-gray")
	return image


func _save(image: Image, file_name: String) -> void:
	var path: String = ProjectSettings.globalize_path(OUT_DIR + file_name + ".png")
	image.save_png(path)
	_written.append(path)


func _gray(source: Image) -> Image:
	return Launcher.gray(source)


## A region blown up 3× (nearest), colour and grayscale.
func _zoom(image: Image, region: Rect2i, file_name: String) -> void:
	var crop: Image = image.get_region(region)
	crop.resize(region.size.x * 3, region.size.y * 3, Image.INTERPOLATE_NEAREST)
	_save(crop, file_name)
	_save(_gray(crop), file_name + "-gray")


# --- shots ------------------------------------------------------------------------------------------------------

func _hud(target: String) -> Control:
	var hud: Control = HudScene.instantiate() as Control
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	_mount(hud)
	var config: LevelConfig = LevelConfig.new()
	config.duration_s = 120.0
	config.target_mode = LevelConfig.TargetMode.LETTER
	hud.call("setup", config, target)
	hud.call("hide_start_prompt")
	hud.call("set_counts", 42, 3)
	hud.call("update_clock", 30.0, 42)
	return hud


func _shots_hud() -> void:
	# Each hand lit, a pinky, a thumb (space: not a Zombie Run key, so straight to the hands), strong frame.
	var lit: Array[Array] = [["01-hud-f-left-index", "f"], ["02-hud-j-right-index", "j"],
			["03-hud-a-left-pinky", "a"], ["04-hud-p-right-pinky", "p"], ["05-hud-space-thumb", " "]]
	for shot: Array in lit:
		var hud: Control = _hud("f" if shot[1] == " " else shot[1])
		if shot[1] == " ":
			(hud.get_node("%ZombieHands") as ZombieHandsScript).show_char(" ")
		var image: Image = await _capture(shot[0])
		_zoom(image, HANDS_REGION, shot[0] + "-hands-3x")
		_unmount_all()
	# The weak glow frame: half a pulse later.
	var hud_weak: Control = _hud("f")
	var hands: ZombieHandsScript = hud_weak.get_node("%ZombieHands") as ZombieHandsScript
	hands._process(1.0 / (2.0 * ZombieHandsScript.PULSE_HZ) + 0.01)
	var weak: Image = await _capture("06-hud-f-weak-glow-frame")
	_zoom(weak, HANDS_REGION, "06-hud-f-weak-glow-frame-hands-3x")
	_unmount_all()
	# Wrong key: at rest and mid-shake, same letter.
	var hud_rest: Control = _hud("k")
	var rest: Image = await _capture("07-hud-wrong-key-at-rest")
	_zoom(rest, SIGN_REGION, "07-hud-wrong-key-at-rest-sign-3x")
	hud_rest.call("shake_target")
	var shake: Image = await _capture("08-hud-wrong-key-mid-shake")
	_zoom(shake, SIGN_REGION, "08-hud-wrong-key-mid-shake-sign-3x")
	_unmount_all()
	# Caps Lock hint, with the start prompt as a run looks before the first key.
	var hud_caps: Control = HudScene.instantiate() as Control
	hud_caps.process_mode = Node.PROCESS_MODE_DISABLED
	_mount(hud_caps)
	var config: LevelConfig = LevelConfig.new()
	config.duration_s = 120.0
	config.target_mode = LevelConfig.TargetMode.LETTER
	hud_caps.call("setup", config, "d")
	hud_caps.call("set_caps_hint", true)
	await _capture("09-hud-caps-lock-hint")
	_unmount_all()


func _menu(music_on: bool) -> Control:
	var player: PlayerDataScript = _temp_player_data()
	player.add_brains(135)
	player.set_setting(&"music_on", music_on)
	var menu: Control = MenuScene.instantiate() as Control
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	menu.set("navigate", _noop_nav)
	menu.set("is_transitioning", func() -> bool: return false)
	menu.set("player_data", player)
	(menu.get_node("%PetSlot") as PetSlot).player_data = player
	(menu.get_node("%Zombie").get_node("%HatSlot") as HatSlot).player_data = player
	menu.set("toggle_fullscreen", func() -> void: pass)
	menu.set("is_fullscreen", func() -> bool: return false)
	_mount(menu)
	return menu


func _shots_menu() -> void:
	var menu: Control = _menu(true)
	await _capture("10-menu-focus-zombie-run-card")
	var cards: Array[LevelCard] = menu.call("get_cards")
	cards[1].grab_focus()
	await _capture("11-menu-focus-coming-soon-card")
	_unmount_all()
	var menu_off: Control = _menu(false)
	(menu_off.get_node("%SoundToggle") as MenuToggle).get_focus_target().grab_focus()
	var toggles: Image = await _capture("12-menu-focus-toggle-music-off")
	_zoom(toggles, Rect2i(248, 280, 384, 72), "12-menu-focus-toggle-music-off-toggles-3x")
	menu_off.call("_show_storage_notice", false)
	(menu_off.get_node("%ClosetButton") as Control).grab_focus()
	await _capture("13-menu-focus-closet-button-storage-notice")
	_unmount_all()


func _shots_pause_and_countdown() -> void:
	var hud: Control = _hud("f")
	var panel: Control = PauseScene.instantiate() as Control
	_mount(panel)
	panel.call("open", false, true)
	await _capture("14-pause-resume-focused-music-off")
	_unmount_all()
	var hud2: Control = _hud("f")
	var countdown: Control = CountdownScene.instantiate() as Control
	countdown.process_mode = Node.PROCESS_MODE_DISABLED
	_mount(countdown)
	countdown.call("start", GameConstants.COUNTDOWN_FROM, GameConstants.COUNTDOWN_STEP_S)
	await _capture("15-countdown")
	_unmount_all()


func _shots_report_and_gift() -> void:
	var player: PlayerDataScript = _temp_player_data()
	player.set_flag(&"welcome_bonus_claimed", true)
	var result: RunResult = RunResult.create(
			&"zombie_run", 1790000000, 120.0, 142, 9, {}, 35, 10, "all", GameConstants.END_REASON_TIMER)
	Router._store_payload({"result": result, "new_best": true})
	var card: Control = ReportScene.instantiate() as Control
	card.process_mode = Node.PROCESS_MODE_DISABLED
	card.set("navigate", _noop_nav)
	card.set("play_sfx", _noop)
	card.set("play_music", _noop)
	card.set("player_data", player)
	_mount(card)
	for i: int in 7:
		(card.get_node("%%Row%d" % i) as CanvasItem).show()
	(card.get_node("%Stamp") as CanvasItem).show()
	await _capture("16-report-card-stamp-and-bonus")
	_unmount_all()
	var gift_player: PlayerDataScript = _temp_player_data()
	var gift: Control = GiftScene.instantiate() as Control
	gift.process_mode = Node.PROCESS_MODE_DISABLED
	gift.set("navigate", _noop_nav)
	gift.set("play_sfx", _noop)
	gift.set("play_music", _noop)
	gift.set("player_data", gift_player)
	_mount(gift)
	await _capture("17-welcome-gift")
	_unmount_all()


## The shipped catalogue with three more row-1/row-2 hats made available (the pumpkin's art), so one Hats
## page shows all five states: Wearing (pumpkin), Wear (witch, owned), Buy (bunny ears, 100), Can't afford
## (heart headband, 200, with 150 brains), Locked (the rest).
func _five_state_catalogue() -> Catalogue:
	var catalogue: Catalogue = Catalogue.new()
	var pumpkin: CosmeticItem = SHIPPED.get_item(&"hat_pumpkin")
	for source: CosmeticItem in SHIPPED.items:
		var item: CosmeticItem = source.duplicate() as CosmeticItem
		if item.id in [&"hat_witch", &"hat_bunny_ears", &"hat_heart_headband"]:
			item.is_available = true
			item.overlay = pumpkin.overlay
			item.icon = pumpkin.icon
		catalogue.items.append(item)
	return catalogue


func _shots_closet() -> void:
	var catalogue: Catalogue = _five_state_catalogue()
	var player: PlayerDataScript = _temp_player_data(catalogue)
	player.set_flag(&"welcome_bonus_claimed", true)
	player.add_brains(200)
	player.buy_item(catalogue.get_item(&"hat_pumpkin"))
	player.buy_item(catalogue.get_item(&"hat_witch"))
	player.add_brains(150)
	player.equip(&"hat_pumpkin")
	var closet: Control = ClosetScene.instantiate() as Control
	closet.process_mode = Node.PROCESS_MODE_DISABLED
	closet.set("navigate", _noop_nav)
	closet.set("is_transitioning", func() -> bool: return false)
	closet.set("play_sfx", _noop)
	closet.set("play_music", _noop)
	closet.set("player_data", player)
	closet.set("catalogue", catalogue)
	_mount(closet)
	(closet.call("get_tile", &"hat_bunny_ears") as Control).grab_focus()
	await _capture("18-closet-five-states-focus-buy")
	(closet.call("get_tile", &"hat_witch") as Control).grab_focus()
	await _capture("19-closet-five-states-focus-wear")
	var bunny: ClosetItemTile = closet.call("get_tile", &"hat_bunny_ears") as ClosetItemTile
	bunny.grab_focus()
	bunny.activated.emit(&"hat_bunny_ears")
	await _capture("20-closet-confirm-prompt")
	_unmount_all()


func _shots_run() -> void:
	# The real run frame on the real Zombie Run level, before the first key (fixed seed).
	var player: PlayerDataScript = _temp_player_data()
	Router._store_payload({"level_id": &"zombie_run", "seed": 7})
	var frame: Node = RunFrameScene.instantiate()
	frame.process_mode = Node.PROCESS_MODE_DISABLED
	frame.set("navigate", _noop_nav)
	frame.set("pause_tree", func(_paused: bool) -> void: pass)
	frame.set("set_ambience", func(_on: bool) -> void: pass)
	frame.set("play_music", _noop)
	frame.set("duck_music", func(_on: bool) -> void: pass)
	frame.set("play_sfx", _noop)
	frame.set("player_data", player)
	_mount(frame)
	var run: Image = await _capture("21-run-zombie-run-before-first-key")
	_zoom(run, Rect2i(184, 96, 288, 208), "22-run-tags-and-hud-sign-3x")
	_unmount_all()
	WebPlatform.capture_keys = false
	# The in-world pieces side by side on the sky: base target (active, resolved), villager, brain block and
	# a conga line at 13 (the ×13 badge).
	var sky: ColorRect = ColorRect.new()
	sky.color = Color("#8ED0F0")
	sky.size = Vector2(SIZE)
	_mount(sky)
	var pieces: Array[Node2D] = []
	var active: ZombieRunTarget = TargetScene.instantiate() as ZombieRunTarget
	active.setup("w", 0)
	var resolved: ZombieRunTarget = TargetScene.instantiate() as ZombieRunTarget
	resolved.setup("e", 1)
	var villager: Villager = VillagerScene.instantiate() as Villager
	villager.setup("m", 2)
	villager.configure(0.4)
	var block: BrainBlock = BlockScene.instantiate() as BrainBlock
	block.setup("q", 3)
	block.configure(48.0, 1)
	pieces.assign([active, resolved, villager, block])
	for i: int in pieces.size():
		pieces[i].process_mode = Node.PROCESS_MODE_DISABLED
		pieces[i].position = Vector2(80 + 90 * i, 200)
		_mount(pieces[i])
	active.set_active(true)
	resolved.resolve()
	var leader: Node2D = Node2D.new()
	leader.position = Vector2(560, 200)
	_mount(leader)
	var line: CongaLine = CongaScene.instantiate() as CongaLine
	line.process_mode = Node.PROCESS_MODE_DISABLED
	line.position.y = 200.0
	_mount(line)
	line.configure(leader, 3)
	for i: int in 13:
		line.join(leader.position.x)
	for i: int in 120:
		line.step(1.0 / 60.0)
	var parts: Image = await _capture("23-run-in-world-tags-and-badge")
	_zoom(parts, Rect2i(40, 120, 400, 100), "24-run-in-world-tags-3x")
	_zoom(parts, Rect2i(400, 110, 200, 100), "25-run-conga-badge-3x")
	_unmount_all()
