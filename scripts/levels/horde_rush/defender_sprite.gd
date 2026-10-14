class_name HordeDefenderSprite
extends Node2D
## Horde Rush's defender sprite: one shared script for every house + defender pair (the Farmer 6.6, the
## Knight and the Lifeguard 10.3), a level-local character. Origin at the feet centre (soles on sheet
## row 30, so Body sits at (-16, -31), the character convention); he faces left, toward the field, and
## never flips (he paces up and down the lanes).
## The level drives him from logic only (HordeDefender): play_idle() before the first key and after the
## run ends, play_walk() while the defender runs, play_throw() on every throw. The throw is a one-shot:
## while it plays, play_walk() and play_idle() only note which loop is wanted; when it finishes, that loop
## plays (so a run that ends mid-throw still settles on idle, with nothing calling him afterwards).
## The pair's projectile, hit effect and sounds travel with the defender scene (the four exports, Story
## 10.3): the level reads them once in its _ready; nothing in the sprite uses them.
## Mirrors PlayerZombie's small play API, not its class (no hat, no hop). No _process, no RNG, no await.

const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"
const ANIM_THROW: StringName = &"throw"

## The scene the level flies from the defender's hand to a copy (a Node2D root, %Sprite optional).
@export var projectile_scene: PackedScene
## The one-shot the level spawns under %Effects where a projectile hits (a HordeHitEffect scene).
@export var hit_scene: PackedScene
## The AudioLibrary id played on every throw.
@export var throw_sfx: StringName = &""
## The AudioLibrary id played on every hit (a miss stays silent).
@export var hit_sfx: StringName = &""

var _throwing: bool = false
## The loop the level last asked for; it plays when a throw finishes.
var _wanted: StringName = ANIM_IDLE
## NFR16: each missing animation warns once, then the defender just keeps his last pose.
var _warned: Dictionary[StringName, bool] = {}

@onready var _body: AnimatedSprite2D = $Body


func _ready() -> void:
	_body.animation_finished.connect(_on_animation_finished)
	if _body.sprite_frames == null:
		Log.warn(&"level", "defender has no sprite frames")
		_body.hide()


func play_idle() -> void:
	_play_loop(ANIM_IDLE)


func play_walk() -> void:
	_play_loop(ANIM_WALK)


## Plays the throw from its first frame (a new throw restarts it).
func play_throw() -> void:
	if not _has_animation(ANIM_THROW):
		return
	_throwing = true
	_body.stop()
	_body.play(ANIM_THROW)


func is_throwing() -> bool:
	return _throwing


func get_body() -> AnimatedSprite2D:
	return _body


## Restarts only when the animation changes, so calling it every frame keeps the loop smooth. While a
## throw plays it only records the wish.
func _play_loop(anim: StringName) -> void:
	_wanted = anim
	if _throwing or not _has_animation(anim):
		return
	if _body.animation != anim or not _body.is_playing():
		_body.play(anim)


func _on_animation_finished() -> void:
	if _body.animation == ANIM_THROW:
		_throwing = false
		_play_loop(_wanted)


func _has_animation(anim: StringName) -> bool:
	if _body.sprite_frames != null and _body.sprite_frames.has_animation(anim):
		return true
	if not _warned.has(anim):
		_warned[anim] = true
		Log.warn(&"level", "defender has no %s animation" % anim)
	return false
