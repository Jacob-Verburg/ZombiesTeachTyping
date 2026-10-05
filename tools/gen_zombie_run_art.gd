extends SceneTree
## Dev-only: writes the Story 3.6 Zombie Run art (the final MVP set): the zombie's hop, hug and dance, the
## villager's poof, the party-hat zombie's walk, the brain block (idle, bonk), the brain pop, the
## down-arrow, and the Sunny Village Green backdrop (clouds, far, near, ground tiles and ground strip).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_zombie_run_art.gd
## then --import, so the .png.import files are written (Lossless, no mipmaps; Nearest is the project default).
##
## Characters and props follow tools/gen_art_prototypes.gd exactly: ASCII maps, one character per pixel,
## '.' = transparent (keeps what earlier parts painted), '_' = clear to transparent, a legend maps a
## character to a palette NAME. The palette, the legends and the approved maps are read from that tool
## (one source); a part here is [map, first row] or [map, first row, x shift].
## Characters (and the poof) are 32x32 frames, props 16x16 (tile size, style sheet section 3).
##
## The backdrop is drawn from shapes (rects, triangles, discs) at fixed, hard-coded positions: no RNG,
## so a rerun writes the same bytes. Every shape wraps around x (it is drawn at x and x +- 640), so each
## 640 px layer tiles with no seam; the shapes that cross the seam are centred on it (x = 0) on purpose.
## The backdrop is exempt from the ink-outline rule only: palette colours, hard alpha, and never
## candy-yellow (focus) or stamp-red (stamp). The ground strip is composed from ground_tiles.png with a
## hard-coded index map. Rules: docs/art-style-sheet.md; tests: test_art_sprites.gd, test_art_backdrop.gd.

const Proto := preload("res://tools/gen_art_prototypes.gd")

const ZOMBIE_DIR: String = "res://assets/sprites/characters/zombie"
const VILLAGER_DIR: String = "res://assets/sprites/characters/villager"
const PARTY_ZOMBIE_DIR: String = "res://assets/sprites/characters/party_zombie"
const PROPS_DIR: String = "res://assets/sprites/props"
const BACKDROP_DIR: String = "res://assets/sprites/backdrops/sunny_village_green"
const CHARACTER_FRAME: int = 32
const PROP_FRAME: int = 16

# --- player zombie: overlays on Proto.ZOMBIE_UPPER (rows are relative to where the upper body is drawn) ---

## Clears the forward arm (upper row + 14 .. + 18) and closes the shirt's right edge with ink.
const ARM_ERASE: Array[String] = [
	"......................________..",
	".....................k________..",
	".....................k________..",
	"......................________..",
	"......................________..",
]

## Arms raised beside the head, from upper row + 7: sleeve up from the shoulder, green hand on top.
const LEFT_ARM_UP: Array[String] = [
	"....kkkk........................",
	"....kGGk........................",
	"....kGGk........................",
	"....kkkk........................",
	"....kppk........................",
	"....kppk........................",
	"....kppk........................",
	"....kppkkkk.....................",
	"....kpppppp.....................",
	"....kdddddd.....................",
	"....kkkkkkk.....................",
]

const RIGHT_ARM_UP: Array[String] = [
	"........................kkkk....",
	"........................kGGk....",
	"........................kGGk....",
	"........................kkkk....",
	"........................kppk....",
	"........................kppk....",
	"........................kppk....",
	".....................kkkkppk....",
	".....................ppppppk....",
	".....................ddddddk....",
	".....................kkkkkkk....",
]

## Arms hanging at the sides, from upper row + 14.
const LEFT_ARM_HANG: Array[String] = [
	".......kkkk.....................",
	".......kppk.....................",
	".......kppk.....................",
	".......kppk.....................",
	".......kkkk.....................",
	".......kGGk.....................",
	".......kGGk.....................",
	".......kkkk.....................",
]

const RIGHT_ARM_HANG: Array[String] = [
	".....................kkkk.......",
	".....................kppk.......",
	".....................kppk.......",
	".....................kppk.......",
	".....................kkkk.......",
	".....................kGGk.......",
	".....................kGGk.......",
	".....................kkkk.......",
]

## Hug: the far arm reaching forward under the near one, from upper row + 19.
const FAR_ARM_REACH: Array[String] = [
	".....................kkkkkkk....",
	".....................dddGGGk....",
	".....................kkkkkkk....",
]

## Hug squeeze: the near arm bent around the villager (fist curled down), from upper row + 14 ...
const NEAR_ARM_SQUEEZE: Array[String] = [
	".....................kkkkkk.....",
	".....................pppGGk.....",
	".....................kkkGGk.....",
	"........................kk......",
]

## ... and the far arm short and wrapped, from upper row + 19.
const FAR_ARM_SQUEEZE: Array[String] = [
	".....................kkkkk......",
	".....................ddGGk......",
	".....................kkkkk......",
]

## Hop crouch: wide bent legs, 6 rows from row 25 (the upper body sits 2 px lower).
const LEGS_CROUCH: Array[String] = [
	"..........kbbbbbbbbbbk..........",
	".........kBbbbbbbbbbbBk.........",
	"........kBBbbkkkkkkbbBBk........",
	"........kkkkk......kkkkk........",
	"........kGGGGk....kGGGGk........",
	"........kkkkkk....kkkkkk........",
]

## Hop peak: legs tucked together, toes pointed, 8 rows from row 23. Drawn grounded: the tween lifts it.
const LEGS_TUCK: Array[String] = [
	"..........kbbbbbbbbbbk..........",
	"..........kBbbbbbbbbBk..........",
	"...........kBbbbbbbBk...........",
	"...........kBbbkkbbBk...........",
	"...........kkkkkkkkkk...........",
	"...........kGGGkkGGGk...........",
	"............kGGkkGGk............",
	"............kkkkkkkk............",
]

## Hop landing: a wide stance, 7 rows from row 24 (the upper body 1 px lower).
const LEGS_LAND: Array[String] = [
	"..........kbbbbbbbbbbk..........",
	".........kBbbbbbbbbbbBk.........",
	"........kBBbbkkkkkkbbBBk........",
	"........kBBbk......kbBBk........",
	".......kkkkkk......kkkkkk.......",
	".......kgGGGGk....kGGGGgk.......",
	".......kkkkkkk....kkkkkkk.......",
]

# --- villager poof: chalk fill, stone-light shade, ink outline; the cloud rests on row 30 ---

const POOF_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"c": "chalk",
	"s": "stone-light",
}

## A small puff on the ground (from row 22).
const POOF_SMALL: Array[String] = [
	"..............kkkkk.............",
	".............kkccckk............",
	"............kkccccckk...........",
	"............kscccccsk...........",
	"............kscccccsk...........",
	"............ksscccssk...........",
	"............kkssssskk...........",
	".............kkssskk............",
	"..............kkkkk.............",
]

## A big puff over the villager's body (from row 10).
const POOF_BIG: Array[String] = [
	".................kkkkk..........",
	"................kscccsk.........",
	"...........kkkkkscccccsk........",
	"..........kscccscccccccsk.......",
	".........ksccccccccccccsk.......",
	"........kscccccccccccccsk.......",
	"........ksccccccccccccssk.......",
	"........kscccccccscccsssk.......",
	"........ksscccccsssssssk........",
	"........kssscccccccsssk.........",
	"........kksssccccccckkkkk.......",
	".......kscccccccccccccccsk......",
	"......kscccccccccccccccccsk.....",
	".....kscccccccccccccccccccsk....",
	".....kscccccccccccccccccccsk....",
	".....kscccccccccccccccccccsk....",
	".....ksscccccccccccccccccssk....",
	".....kssscccsscccccsscccsssk....",
	"......ksssssssssssssssssssk.....",
	".......ksssssksssssksssssk......",
	"........kkkkk.kkkkk.kkkkk.......",
]

## The big puff breaking up (from row 10).
const POOF_BREAK: Array[String] = [
	"....................kkk.........",
	"...................kccck........",
	"..................kscccsk.......",
	"..................kscccsk.......",
	"..........kkkkk...ksssssk.......",
	".........kkccckk...ksssk........",
	"........kkccccckk...kkk.........",
	"........kscccccsk...............",
	"........kscccccsk...............",
	"........ksscccssk...............",
	"........kkssssskk...............",
	".........kkssskkkk..............",
	"..........kkkkkccck..kkkkk......",
	".............kscccskkkccckk.....",
	".......kkk...kscccskkccccckk....",
	"......kccck..kssssskscccccsk....",
	".....kscccsk..kssskkscccccsk....",
	".....kscccsk...kkk.ksscccssk....",
	".....ksssssk.......kkssssskk....",
	"......ksssk.........kkssskk.....",
	".......kkk...........kkkkk......",
]

## A few tiny puffs, two still on the ground (from row 10).
const POOF_TINY: Array[String] = [
	".............kkk................",
	"............kscsk...............",
	"............ksssk...............",
	"............ksssk...............",
	".............kkk................",
	"................................",
	"................................",
	"................................",
	"................................",
	".......................kkk......",
	"......................kscsk.....",
	"......................ksssk.....",
	"......................ksssk.....",
	".......................kkk......",
	"................................",
	"................................",
	"......kkk..........kkk..........",
	".....kscsk........kscsk.........",
	".....ksssk........ksssk.........",
	".....ksssk........ksssk.........",
	"......kkk..........kkk..........",
]

# --- party-hat zombie walk: the villager's legs (n trousers, N shade, B shoes) in four poses ---

## Clears the villager's standing legs (rows 24-30) before a walk pose is drawn.
const LEGS_CLEAR: Array[String] = [
	"________________________________",
	"________________________________",
	"________________________________",
	"________________________________",
	"________________________________",
	"________________________________",
	"________________________________",
]

## Contact: the near leg (n) forward, the far leg (N) back. Rows 24-30.
const PARTY_WALK_A: Array[String] = [
	"...........knnnnnnnnnnk.........",
	"..........kNNnkkkkkknnnk........",
	".........kNNNk......knnnk.......",
	".........kNNNk......knnnk.......",
	"........kBBBBk......kBBBBk......",
	"........kBBBBk......kBBBBk......",
	"........kkkkkk......kkkkkk......",
]

## Passing: legs together, the far leg shaded.
const PARTY_PASS_A: Array[String] = [
	"...........knnnnnnnnnnk.........",
	"...........kNNNNkknnnnk.........",
	"...........kNNNk..knnnk.........",
	"...........kNNNk..knnnk.........",
	"..........kBBBBk..kBBBBk........",
	"..........kBBBBk..kBBBBk........",
	"..........kkkkkk..kkkkkk........",
]

## Contact with near and far swapped.
const PARTY_WALK_B: Array[String] = [
	"...........knnnnnnnnnnk.........",
	"..........knnnkkkkkkNNNk........",
	".........knnnk......kNNNk.......",
	".........knnnk......kNNNk.......",
	"........kBBBBk......kBBBBk......",
	"........kBBBBk......kBBBBk......",
	"........kkkkkk......kkkkkk......",
]

const PARTY_PASS_B: Array[String] = [
	"...........knnnnnnnnnnk.........",
	"...........knnnnkkNNNNk.........",
	"...........knnnk..kNNNk.........",
	"...........knnnk..kNNNk.........",
	"..........kBBBBk..kBBBBk........",
	"..........kBBBBk..kBBBBk........",
	"..........kkkkkk..kkkkkk........",
]

# --- props: 16x16 ---

## Brain block and brain pop: cartoon pink with a shade band (no anatomy); the used block is stone.
const PROP_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"p": "art-brain-pink",
	"s": "art-brain-shade",
	"w": "chalk",
	"l": "stone-light",
	"n": "stone",
	"y": "candy-yellow",
}

const BLOCK_IDLE_A: Array[String] = [
	"kkkkkkkkkkkkkkkk",
	"kwwpppppppppppsk",
	"kwppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kssssssssssssssk",
	"kssssssssssssssk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kssssssssssssssk",
	"kkkkkkkkkkkkkkkk",
]

## The blink: the corner glint dims and a little twinkle shows on the face.
const BLOCK_IDLE_B: Array[String] = [
	"kkkkkkkkkkkkkkkk",
	"kwppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppwppssk",
	"kppppppppwwwpssk",
	"kpppppppppwpppsk",
	"kpppppppppppppsk",
	"kssssssssssssssk",
	"kssssssssssssssk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kssssssssssssssk",
	"kkkkkkkkkkkkkkkk",
]

## Bonk 1: squashed (still pink), 13 rows tall on the same bottom row.
const BLOCK_SQUASH: Array[String] = [
	"................",
	"................",
	"................",
	"kkkkkkkkkkkkkkkk",
	"kwwpppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kssssssssssssssk",
	"kssssssssssssssk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kpppppppppppppsk",
	"kssssssssssssssk",
	"kkkkkkkkkkkkkkkk",
]

## Bonk 2: rebounds tall and narrow, already grey.
const BLOCK_REBOUND: Array[String] = [
	".kkkkkkkkkkkkkk.",
	".klllllllllllnk.",
	".klllllllllllnk.",
	".klllllllllllnk.",
	".klllllllllllnk.",
	".klllllllllllnk.",
	".klllllllllllnk.",
	".knnnnnnnnnnnnk.",
	".knnnnnnnnnnnnk.",
	".klllllllllllnk.",
	".klllllllllllnk.",
	".klllllllllllnk.",
	".klllllllllllnk.",
	".klllllllllllnk.",
	".knnnnnnnnnnnnk.",
	".kkkkkkkkkkkkkk.",
]

## Bonk 3: settled as the used block (stone-light and stone, no pink). The held last frame.
const BLOCK_USED: Array[String] = [
	"kkkkkkkkkkkkkkkk",
	"klllllllllllllnk",
	"klllllllllllllnk",
	"klllllllllllllnk",
	"klllllllllllllnk",
	"klllllllllllllnk",
	"klllllllllllllnk",
	"knnnnnnnnnnnnnnk",
	"knnnnnnnnnnnnnnk",
	"klllllllllllllnk",
	"klllllllllllllnk",
	"klllllllllllllnk",
	"klllllllllllllnk",
	"klllllllllllllnk",
	"knnnnnnnnnnnnnnk",
	"kkkkkkkkkkkkkkkk",
]

## The cartoon brain from Story 3.2's BrainPop._draw (10 px wide), its bottom ink on row 14.
const BRAIN_POP_A: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"....kkkkkkkk....",
	"...kppppspppk...",
	"...kppppspppk...",
	"...kpsspspppk...",
	"...kppppspssk...",
	"...kppppspppk...",
	"...kppppppppk...",
	"....kkkkkkkk....",
	"................",
]

## The bob: 1 px taller on the same bottom row (a stretch, so the soles rule holds).
const BRAIN_POP_B: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"....kkkkkkkk....",
	"...kppppspppk...",
	"...kppppspppk...",
	"...kpsspspppk...",
	"...kppppspppk...",
	"...kppppspssk...",
	"...kppppspppk...",
	"...kppppppppk...",
	"....kkkkkkkk....",
	"................",
]

## The active-target arrow: candy-yellow, 10 x 7, tip on row 14; the sprite centre is x 8.
const DOWN_ARROW: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"...kkkkkkkkkk...",
	"...kyyyyyyyyk...",
	"...kyyyyyyyyk...",
	"....kyyyyyyk....",
	".....kyyyyk.....",
	"......kyyk......",
	".......kk.......",
	"................",
]

## Sheet path -> size, legend and frames; a frame is a list of parts.
const SHEETS: Dictionary[String, Dictionary] = {
	ZOMBIE_DIR + "/zombie_hop.png": {
		"size": CHARACTER_FRAME,
		"legend": Proto.ZOMBIE_LEGEND,
		"frames": [
			[[LEGS_CROUCH, 25], [Proto.ZOMBIE_UPPER, 3]],
			[[LEGS_TUCK, 23], [Proto.ZOMBIE_UPPER, 1], [ARM_ERASE, 15], [LEFT_ARM_UP, 8], [RIGHT_ARM_UP, 8]],
			[[LEGS_LAND, 24], [Proto.ZOMBIE_UPPER, 2]],
		],
	},
	ZOMBIE_DIR + "/zombie_hug.png": {
		"size": CHARACTER_FRAME,
		"legend": Proto.ZOMBIE_LEGEND,
		"frames": [
			[[Proto.LEGS_STAND, 23], [Proto.ZOMBIE_UPPER, 1], [FAR_ARM_REACH, 20]],
			[[Proto.LEGS_STAND, 23], [Proto.ZOMBIE_UPPER, 1, 1], [ARM_ERASE, 15, 1],
					[NEAR_ARM_SQUEEZE, 15, 1], [FAR_ARM_SQUEEZE, 20, 1]],
			[[Proto.LEGS_STAND, 23], [Proto.ZOMBIE_UPPER, 2], [FAR_ARM_REACH, 21]],
		],
	},
	ZOMBIE_DIR + "/zombie_dance.png": {
		"size": CHARACTER_FRAME,
		"legend": Proto.ZOMBIE_LEGEND,
		"frames": [
			[[Proto.LEGS_STAND, 23], [Proto.ZOMBIE_UPPER, 1], [ARM_ERASE, 15], [LEFT_ARM_UP, 8],
					[RIGHT_ARM_HANG, 15]],
			[[Proto.LEGS_STAND, 23], [Proto.ZOMBIE_UPPER, 1], [ARM_ERASE, 15], [LEFT_ARM_HANG, 15],
					[RIGHT_ARM_UP, 8]],
			[[Proto.PASS_A, 23], [Proto.ZOMBIE_UPPER, 1], [ARM_ERASE, 15], [LEFT_ARM_UP, 8], [RIGHT_ARM_UP, 8]],
			[[Proto.LEGS_STAND, 23], [Proto.ZOMBIE_UPPER, 2], [ARM_ERASE, 16], [LEFT_ARM_HANG, 16],
					[RIGHT_ARM_HANG, 16]],
		],
	},
	VILLAGER_DIR + "/villager_poof.png": {
		"size": CHARACTER_FRAME,
		"legend": POOF_LEGEND,
		"frames": [
			[[POOF_SMALL, 22]],
			[[POOF_BIG, 10]],
			[[POOF_BREAK, 10]],
			[[POOF_TINY, 10]],
		],
	},
	PARTY_ZOMBIE_DIR + "/party_zombie_walk.png": {
		"size": CHARACTER_FRAME,
		"legend": Proto.PARTY_ZOMBIE_LEGEND,
		"frames": [
			[[Proto.VILLAGER_BODY, 4], [Proto.PARTY_HEAD_EDGE, 8], [Proto.PARTY_ARM, 18], [Proto.PARTY_HAT, 1],
					[LEGS_CLEAR, 24], [PARTY_WALK_A, 24]],
			[[Proto.VILLAGER_BODY, 4], [Proto.PARTY_HEAD_EDGE, 8], [Proto.PARTY_ARM, 18],
					[Proto.PARTY_HAT_TILT, 1], [LEGS_CLEAR, 24], [PARTY_PASS_A, 24]],
			[[Proto.VILLAGER_BODY, 4], [Proto.PARTY_HEAD_EDGE, 8], [Proto.PARTY_ARM, 18], [Proto.PARTY_HAT, 1],
					[LEGS_CLEAR, 24], [PARTY_WALK_B, 24]],
			[[Proto.VILLAGER_BODY, 4], [Proto.PARTY_HEAD_EDGE, 8], [Proto.PARTY_ARM, 18],
					[Proto.PARTY_HAT_TILT, 1], [LEGS_CLEAR, 24], [PARTY_PASS_B, 24]],
		],
	},
	PROPS_DIR + "/brain_block_idle.png": {
		"size": PROP_FRAME,
		"legend": PROP_LEGEND,
		"frames": [[[BLOCK_IDLE_A, 0]], [[BLOCK_IDLE_B, 0]]],
	},
	PROPS_DIR + "/brain_block_bonk.png": {
		"size": PROP_FRAME,
		"legend": PROP_LEGEND,
		"frames": [[[BLOCK_SQUASH, 0]], [[BLOCK_REBOUND, 0]], [[BLOCK_USED, 0]]],
	},
	PROPS_DIR + "/brain_pop.png": {
		"size": PROP_FRAME,
		"legend": PROP_LEGEND,
		"frames": [[[BRAIN_POP_A, 0]], [[BRAIN_POP_B, 0]]],
	},
	# One frame: an overlay, not an animation.
	PROPS_DIR + "/down_arrow.png": {
		"size": PROP_FRAME,
		"legend": PROP_LEGEND,
		"frames": [[[DOWN_ARROW, 0]]],
	},
}

# --- backdrop ---

## Every layer is PERIOD wide, so two copies side by side always cover the 640 px screen.
const PERIOD: int = 640
## Layers cover the playfield above the ground line (y 0-192); the ground strip covers y 192-256.
const LAYER_H: int = 192
const GROUND_ROWS: int = 4
const TILE: int = PROP_FRAME

## Ground tiles: grass, grass tuft, grass with a small flower, path. Each edge is the plain base colour,
## so any tile sits next to any other with no seam.
const GROUND_LEGEND: Dictionary[String, String] = {
	"g": "art-grass",
	"d": "zombie-green-dark",
	"G": "zombie-green",
	"p": "bat-purple",
	"o": "pumpkin-light",
	"a": "parchment-shade",
	"f": "ink-faded",
	"w": "wood-light",
}

const TILE_GRASS: Array[String] = [
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"ggggdggggggggggg",
	"ggggdggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggdgggg",
	"gggggggggggdgggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
]

const TILE_TUFT: Array[String] = [
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"ggggggGggGgggggg",
	"gggggGdgGdgGgggg",
	"ggggGgdGdgGdgggg",
	"ggggdGdgdGdggggg",
	"gggggdgdgdgggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"ggdggggggggggggg",
	"ggdggggggggggggg",
	"gggggggggggggggg",
]

const TILE_FLOWER: Array[String] = [
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"ggggggggpggggggg",
	"gggggggpopgggggg",
	"ggggggggpggggggg",
	"ggggggggdggggggg",
	"gggggggddggggggg",
	"ggggggggdggggggg",
	"gggggggggggggggg",
	"gggggggggggggdgg",
	"gggggggggggggdgg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
]

## The path: a faded edge line where the soles stand (the ground line, y 192), dirt and a few pebbles.
const TILE_PATH: Array[String] = [
	"ffffffffffffffff",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaawaaaaaaaaaaaa",
	"aaaaaaaaaaafaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaawaaaaaaaa",
	"aaaaaaawwaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aafaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaawaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
]

const GROUND_TILES: Array = [TILE_GRASS, TILE_TUFT, TILE_FLOWER, TILE_PATH]
const PATH_TILE: int = 3

## Ground strip index map: row 0 is the path, rows 1-3 grass (0 grass, 1 tuft, 2 flower), 40 tiles a row.
const GROUND_MAP: Array[String] = [
	"3333333333333333333333333333333333333333",
	"0010002000100010020001000010200010001002",
	"1000100020001000100002001000100020010001",
	"0020010000100200010001000200010001000100",
]

## Clouds: [centre x, bottom y, puff size]. The first is centred on the seam (x 0) on purpose.
const CLOUDS: Array[Vector3i] = [
	Vector3i(0, 44, 8),
	Vector3i(150, 30, 6),
	Vector3i(300, 58, 7),
	Vector3i(470, 28, 9),
]

## Far hills: the crest line is 146 - 10 cos(2 * 2 pi x / 640) - 6 cos(3 * 2 pi x / 640), a peak at the
## seam (x 0), so x 639 and x 0 sit on the same row.
const HILL_BASE_Y: float = 146.0
## Pale distant hills (chalk-dim, a zombie-green crest): the characters' zombie greens never sit on
## their own colour (readability check, Story 3.6).
const HILL_FILL: String = "chalk-dim"
const HILL_CREST: String = "zombie-green"
const HILL_A_PX: float = 10.0
const HILL_B_PX: float = 6.0
## Distant houses (x) and the windmill (x), stone-light silhouettes standing on the crest.
const FAR_HOUSES: Array[int] = [96, 236, 420]
const FAR_WINDMILL_X: int = 540

## Near layer: two cottages (left edge x), a round tree, a tree centred on the seam, a fence, a pumpkin
## on one of its posts, and the bat bunting across the top. At the start of a run (camera x -224) the
## near layer is offset 528 px, so the post at layer x 592 shows at screen x 64: far left of the zombie
## (screen 224) and clear of the first targets, so it never reads as a hat. It passes behind the conga
## line later, like every near prop.
const COTTAGES: Array[int] = [64, 384]
const COTTAGE_W: int = 48
const TREE_X: int = 260
const FENCE_POST_STEP: int = 32
const FENCE_POST_FIRST: int = 16
const FENCE_POST_TOP: int = 168
const PUMPKIN_POST_X: int = 592
const BUNTING_SPAN: int = 160
const BUNTING_TOP_Y: int = 10
const BUNTING_SAG_PX: float = 8.0
const FLAG_STEP: int = 16


func _init() -> void:
	var errors: Array[Error] = []
	for dir: String in [ZOMBIE_DIR, VILLAGER_DIR, PARTY_ZOMBIE_DIR, PROPS_DIR, BACKDROP_DIR]:
		errors.append(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)))
	for path: String in SHEETS:
		var sheet: Dictionary = SHEETS[path]
		var legend: Dictionary[String, String] = sheet["legend"]
		var image: Image = _sheet_image(sheet["frames"], legend, sheet["size"])
		errors.append(_save(image, path) if image != null else ERR_INVALID_DATA)
	var tiles: Image = _tiles_image()
	errors.append(_save(tiles, BACKDROP_DIR + "/ground_tiles.png") if tiles != null else ERR_INVALID_DATA)
	var strip: Image = _ground_strip(tiles) if tiles != null else null
	errors.append(_save(strip, BACKDROP_DIR + "/ground_strip.png") if strip != null else ERR_INVALID_DATA)
	errors.append(_save(_clouds_image(), BACKDROP_DIR + "/clouds.png"))
	errors.append(_save(_far_image(), BACKDROP_DIR + "/far.png"))
	errors.append(_save(_near_image(), BACKDROP_DIR + "/near.png"))
	# Non-zero exit on any failure, so a bad map, path or cwd doesn't look like success.
	quit(0 if errors.all(func(err: Error) -> bool: return err == OK) else 1)


func _color(color_name: String) -> Color:
	return Color.html(Proto.PALETTE[color_name])


## One horizontal strip, `size` px per frame. Returns null (after push_error) on a bad map.
func _sheet_image(frames: Array, legend: Dictionary[String, String], size: int) -> Image:
	var image: Image = Image.create_empty(frames.size() * size, size, false, Image.FORMAT_RGBA8)
	for i: int in frames.size():
		for part: Array in frames[i]:
			var rows: Array[String] = part[0]
			var top: int = part[1]
			var shift: int = part[2] if part.size() > 2 else 0
			if top < 0 or top + rows.size() > size:
				push_error("frame %d: part from row %d does not fit" % [i, top])
				return null
			for y: int in rows.size():
				var row: String = rows[y]
				if row.length() != size:
					push_error("frame %d row %d: %d chars, want %d" % [i, top + y, row.length(), size])
					return null
				for x: int in size:
					var ch: String = row[x]
					if ch == ".":
						continue
					var px: int = x + shift
					if px < 0 or px >= size:
						push_error("frame %d (%d,%d): '%s' shifted out of the frame" % [i, x, top + y, ch])
						return null
					if ch == "_":
						image.set_pixel(i * size + px, top + y, Color(0, 0, 0, 0))
						continue
					if not legend.has(ch) or not Proto.PALETTE.has(legend[ch]):
						push_error("frame %d (%d,%d): '%s' not in legend/palette" % [i, x, top + y, ch])
						return null
					image.set_pixel(i * size + px, top + y, _color(legend[ch]))
	return image


func _tiles_image() -> Image:
	var frames: Array = []
	for tile: Array in GROUND_TILES:
		frames.append([[tile, 0]])
	return _sheet_image(frames, GROUND_LEGEND, TILE)


## 640 x 64, each 16 x 16 cell copied from ground_tiles.png by GROUND_MAP (no randomness).
func _ground_strip(tiles: Image) -> Image:
	var image: Image = Image.create_empty(PERIOD, GROUND_ROWS * TILE, false, Image.FORMAT_RGBA8)
	if GROUND_MAP.size() != GROUND_ROWS:
		push_error("GROUND_MAP has %d rows, want %d" % [GROUND_MAP.size(), GROUND_ROWS])
		return null
	for row: int in GROUND_ROWS:
		var line: String = GROUND_MAP[row]
		if line.length() != PERIOD / TILE:
			push_error("GROUND_MAP row %d: %d tiles, want %d" % [row, line.length(), PERIOD / TILE])
			return null
		for col: int in line.length():
			var index: int = line[col].to_int()
			if index < 0 or index >= GROUND_TILES.size() or (row == 0) != (index == PATH_TILE):
				push_error("GROUND_MAP (%d,%d): tile %d" % [col, row, index])
				return null
			image.blit_rect(tiles, Rect2i(index * TILE, 0, TILE, TILE), Vector2i(col * TILE, row * TILE))
	return image


# --- shape helpers: every x wraps around PERIOD ---

func _layer() -> Image:
	return Image.create_empty(PERIOD, LAYER_H, false, Image.FORMAT_RGBA8)


func _put(image: Image, x: int, y: int, color_name: String) -> void:
	if y < 0 or y >= image.get_height():
		return
	image.set_pixel(posmod(x, PERIOD), y, _color(color_name))


func _rect(image: Image, x: int, y: int, w: int, h: int, color_name: String) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_put(image, xx, yy, color_name)


## A rect with a 1 px ink border.
func _box(image: Image, x: int, y: int, w: int, h: int, color_name: String) -> void:
	_rect(image, x, y, w, h, "ink")
	_rect(image, x + 1, y + 1, w - 2, h - 2, color_name)


## An even-width disc centred on the pixel boundary at cx (columns cx - h .. cx + h - 1), rows
## cy - r .. cy + r - 1. Centred on x 0, it is mirror-symmetric across the seam.
func _blob(image: Image, cx: int, cy: int, r: int, color_name: String) -> void:
	for dy: int in range(-r, r):
		var yc: float = dy + 0.5
		var h: int = maxi(1, roundi(sqrt(maxf(0.0, r * r - yc * yc))))
		for x: int in range(cx - h, cx + h):
			_put(image, x, cy + dy, color_name)


## A triangle with its apex at (cx, top), widening by 1 px each side per row, down to `bottom`.
func _roof(image: Image, cx: int, top: int, bottom: int, color_name: String) -> void:
	for y: int in range(top, bottom):
		var half: int = y - top + 1
		for x: int in range(cx - half, cx + half):
			_put(image, x, y, color_name)


func _clouds_image() -> Image:
	var image: Image = _layer()
	for cloud: Vector3i in CLOUDS:
		var s: int = cloud.z
		_rect(image, cloud.x - 2 * s, cloud.y - s, 4 * s, s, "art-sky-light")
		_blob(image, cloud.x - s, cloud.y - s, s, "art-sky-light")
		_blob(image, cloud.x + s, cloud.y - s, s, "art-sky-light")
		_blob(image, cloud.x, cloud.y - s - s / 2, s + 2, "art-sky-light")
	return image


func _hill_y(x: int) -> int:
	var t: float = TAU * x / PERIOD
	return roundi(HILL_BASE_Y - HILL_A_PX * cos(2.0 * t) - HILL_B_PX * cos(3.0 * t))


func _far_image() -> Image:
	var image: Image = _layer()
	for x: int in PERIOD:
		var top: int = _hill_y(x)
		_rect(image, x, top, 1, LAYER_H - top, HILL_FILL)
		_put(image, x, top, HILL_CREST)
	for x: int in FAR_HOUSES:
		var ground: int = _hill_y(x) + 2
		_rect(image, x - 3, ground - 4, 6, 4, "stone-light")
		_roof(image, x, ground - 7, ground - 4, "stone-light")
	# The windmill: a tower and four sails crossing at the hub.
	var base: int = _hill_y(FAR_WINDMILL_X) + 2
	var hub: Vector2i = Vector2i(FAR_WINDMILL_X, base - 13)
	_rect(image, FAR_WINDMILL_X - 2, hub.y, 4, base - hub.y, "stone-light")
	for i: int in range(1, 7):
		_put(image, hub.x - i, hub.y - i, "stone-light")
		_put(image, hub.x + i - 1, hub.y - i, "stone-light")
		_put(image, hub.x - i, hub.y + i - 1, "stone-light")
		_put(image, hub.x + i - 1, hub.y + i - 1, "stone-light")
	return image


func _near_image() -> Image:
	var image: Image = _layer()
	_bunting(image)
	for x: int in COTTAGES:
		_cottage(image, x)
	_tree(image, TREE_X, 18, 142, 160)
	_tree(image, 0, 14, 150, 164)
	_fence(image)
	return image


## A sagging ink string from attach point to attach point, bat-purple flags hanging under it.
func _bunting(image: Image) -> void:
	for x: int in PERIOD:
		_put(image, x, _bunting_y(x), "ink")
	for x: int in range(FLAG_STEP / 2, PERIOD, FLAG_STEP):
		var top: int = _bunting_y(x) + 1
		for row: int in 6:
			var half: int = (6 - row) / 2
			_rect(image, x - half, top + row, 2 * half + 1, 1, "bat-purple")
		_put(image, x, top + 6, "dusk")


func _bunting_y(x: int) -> int:
	return BUNTING_TOP_Y + roundi(BUNTING_SAG_PX * sin(PI * posmod(x, BUNTING_SPAN) / BUNTING_SPAN))


## A wood cottage standing on the ground line: chimney, wood-dark roof, wood-light walls, door, window.
func _cottage(image: Image, x: int) -> void:
	var wall_top: int = LAYER_H - 32
	_box(image, x + 32, wall_top - 24, 7, 16, "stone")
	_rect(image, x + 33, wall_top - 23, 5, 1, "stone-light")
	var cx: int = x + COTTAGE_W / 2
	_roof(image, cx, wall_top - 28, wall_top + 1, "ink")
	_roof(image, cx, wall_top - 27, wall_top, "wood-dark")
	for y: int in range(wall_top - 20, wall_top, 5):
		var half: int = y - (wall_top - 27)
		_rect(image, cx - half + 1, y, 2 * half - 2, 1, "wood")
	_box(image, x, wall_top, COTTAGE_W, 32, "wood-light")
	for y: int in range(wall_top + 5, LAYER_H - 1, 5):
		_rect(image, x + 1, y, COTTAGE_W - 2, 1, "wood")
	_box(image, x + 7, wall_top + 12, 10, 20, "wood-dark")
	_put(image, x + 14, wall_top + 22, "pumpkin-light")
	_box(image, x + 27, wall_top + 9, 13, 11, "art-sky-light")
	_rect(image, x + 33, wall_top + 10, 1, 9, "ink")
	_rect(image, x + 28, wall_top + 14, 11, 1, "ink")


## A round tree: wood trunk to the ground, a zombie-green-dark canopy with a zombie-green highlight.
func _tree(image: Image, cx: int, radius: int, canopy_y: int, trunk_top: int) -> void:
	_box(image, cx - 4, trunk_top, 8, LAYER_H - trunk_top, "wood")
	_blob(image, cx, canopy_y, radius + 1, "ink")
	_blob(image, cx, canopy_y, radius, "zombie-green-dark")
	_blob(image, cx, canopy_y - radius / 3, radius / 2, "zombie-green")


## Two rails across the whole width with posts every FENCE_POST_STEP px, not in front of the cottages;
## the pumpkin sits on the post at PUMPKIN_POST_X (a regular fence post, so it is on the fence).
func _fence(image: Image) -> void:
	for x: int in PERIOD:
		if _behind_cottage(x):
			continue
		for rail_y: int in [174, 183]:
			_put(image, x, rail_y, "ink")
			_put(image, x, rail_y + 1, "wood-light")
			_put(image, x, rail_y + 2, "wood-light")
			_put(image, x, rail_y + 3, "ink")
	for x: int in range(FENCE_POST_FIRST, PERIOD, FENCE_POST_STEP):
		if _behind_cottage(x) or _behind_cottage(x + 3):
			continue
		_box(image, x, FENCE_POST_TOP, 4, LAYER_H - FENCE_POST_TOP, "wood")
	var cx: int = PUMPKIN_POST_X + 2
	var cy: int = FENCE_POST_TOP - 6
	_blob(image, cx, cy, 7, "ink")
	_blob(image, cx, cy, 6, "pumpkin")
	_rect(image, cx - 3, cy - 4, 2, 4, "pumpkin-light")
	_rect(image, cx - 1, cy - 8, 2, 2, "zombie-green-dark")


func _behind_cottage(x: int) -> bool:
	for left: int in COTTAGES:
		if x >= left - 1 and x <= left + COTTAGE_W:
			return true
	return false


func _save(image: Image, path: String) -> Error:
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s (%dx%d)" % [path, error_string(err), image.get_width(), image.get_height()])
	return err
