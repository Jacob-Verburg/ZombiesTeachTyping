extends SceneTree
## Dev-only: writes the cosmetics art: the Story 4.3 Pumpkin hat overlay and the Cute ghost pet's idle float,
## the Story 9.1 hats (Witch, Bunny ears, Santa, Leprechaun, Heart headband, Top hat, Pirate, Crown) and the
## Story 9.2 pets' idles (Black cat, Spider, Orange cat, Bat, Crow, Wolf-dog, Floating eyeball, Brain buddy).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_cosmetics_art.gd
## then --import, so the .png.import files are written (Lossless, no mipmaps; Nearest is the project default).
##
## Same method as tools/gen_zombie_run_art.gd: ASCII maps, one character per pixel, '.' = transparent, a
## legend maps a character to a palette NAME (the palette is read from tools/gen_art_prototypes.gd). A part
## is [map, first row]; every row of a part has the part's width, which must be EVEN, and the part is placed
## at x (32 - width) / 2, so it is centred on column 16 (an odd width can't have symmetric extents about 16).
## Hats (docs/art-style-sheet.md section 3): a 32x32 one-frame overlay whose seat (the bottom-centre of the
## brim) is pixel (16, 30): lowest opaque row 30, symmetric extents about x 16, row 31 empty. HatSlot puts
## the seat on the head point. A hat map's last row is its bottom ink row (row 30), its top row is >= 12
## (HAT_MAX_RISE 18: a 1.5x Horde Rush copy in lane 0 must keep its hat on screen), and it has an even
## number of rows, so the Closet icon (the cropped overlay) centres exactly in 32x32.
## Pets are horizontal strips of 32x32 frames drawn from the feet like characters: the soles (a floater's
## shadow) on row 30 in every frame, so an idle moves the body and never the lowest row; 2-6 frames, no two
## identical; every frame PET_MIN_HEIGHT-PET_MAX_HEIGHT (12-22) px tall and at most PET_MAX_WIDTH (28) wide.
## _pet_sheet_ok checks these before a sheet is written.
## Rules: docs/art-style-sheet.md; tests: test_art_sprites.gd.

const Proto := preload("res://tools/gen_art_prototypes.gd")

const HATS_DIR: String = "res://assets/sprites/cosmetics/hats"
const PETS_DIR: String = "res://assets/sprites/cosmetics/pets"
const FRAME: int = 32

## Shared by every hat. Never candy-yellow (focus only), stamp-red (the stamp only) or art-moon (the moon).
const HAT_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"o": "pumpkin",
	"l": "pumpkin-light",
	"w": "wood-dark",
	"g": "zombie-green-dark",
	"b": "zombie-green-bright",
	"G": "art-grass",
	"p": "bat-purple",
	"d": "dusk",
	"c": "chalk",
	"s": "stone-light",
	"t": "stone",
	"m": "ink-muted",
	"P": "art-brain-pink",
	"R": "art-brain-shade",
}

## Pumpkin hat from row 19 (12 rows, so its top is 11 px above the seat): a stem with a leaf, a round
## pumpkin with a highlight down the left, two dot eyes and a small smile (cute, no teeth). The bottom ink
## row (row 30) is the brim the seat sits on; rows 24-28 are the widest (14 px, covering the 12 px crown).
const PUMPKIN_HAT: Array[String] = [
	"......kk.kk...",
	".....kwwkggk..",
	"...kkkwwkkkk..",
	"..kllooooook..",
	".kllooooooook.",
	"kllooooooooook",
	"klookooookoook",
	"klookooookoook",
	"kloookookooook",
	"koooookkoooook",
	".kooooooooook.",
	"..kkkkkkkkkk..",
]

## Witch hat from row 13 (18 rows, 20 wide, rise 17): a bat-purple cone with a dusk shade down the right, its
## tip bent over to the right, a pumpkin band with a pumpkin-light buckle and a wide brim (dusk underside).
const WITCH_HAT: Array[String] = [
	"..............kk....",
	".............kppk...",
	"...........kkpdk....",
	"..........kppdk.....",
	".........kppdk......",
	"........kpppdk......",
	".......kppppdk......",
	".......kppppddk.....",
	"......kpppppddk.....",
	"......kpppppddk.....",
	".....kppppppdddk....",
	".....kppppppdddk....",
	"....koooolloooook...",
	"....kooookklooook...",
	"..kkkpppppppddddkk..",
	".kppppppppppppppddk.",
	"kddddddddddddddddddk",
	".kkkkkkkkkkkkkkkkkk.",
]

## Bunny ears from row 13 (18 rows, 16 wide, rise 17): two chalk ears (stone-light shade, art-brain-pink
## inside) on a pink band; the right ear tips over. Each ear has its own ink outline, the gap between them
## is transparent.
const BUNNY_EARS: Array[String] = [
	"...kk...........",
	"..kcck..........",
	".kcccsk.........",
	".kcPPsk.....kk..",
	".kcPPsk....kcck.",
	".kcPPsk...kcccsk",
	".kcPPsk...kcPPsk",
	".kcPPsk..kcPPsk.",
	".kcPPsk..kcPPsk.",
	".kcPPsk..kcPPsk.",
	".kcPPsk..kcPPsk.",
	".kcPPsk..kcPPsk.",
	".kcPPsk..kcPPsk.",
	".kcccsk..kcccsk.",
	".kccsskkkkccssk.",
	"kPPPPPPPPPPPPPPk",
	"kRRRRRRRRRRRRRRk",
	".kkkkkkkkkkkkkk.",
]

## Santa hat from row 15 (16 rows, 18 wide, rise 15): an art-brain-shade cap (art-brain-pink highlight on the
## left, never stamp-red) flopping to the right onto a chalk pom-pom, over a chalk fur trim.
const SANTA_HAT: Array[String] = [
	".....kkkk.........",
	"....kPRRRkkk......",
	"...kPRRRRRRRkk....",
	"...kPRRRRRRRRRk...",
	"..kPRRRRRRkkRRRk..",
	"..kPRRRRRRk.kRRk..",
	"..kPRRRRRRkkcccck.",
	".kPRRRRRRRkkccssk.",
	".kPRRRRRRRRkccssk.",
	".kPRRRRRRRRkkssk..",
	".kPRRRRRRRRRkkk...",
	".kPRRRRRRRRRRkkkk.",
	"kcccccccccccccccck",
	"kcccccccccccccccck",
	"kssssssssssssssssk",
	".kkkkkkkkkkkkkkkk.",
]

## Leprechaun hat from row 17 (14 rows, 16 wide, rise 13): a short art-grass top hat (zombie-green-dark shade,
## zombie-green-bright highlight; the ink outline keeps it apart from the green skin), a wood-dark band with
## a pumpkin-light square buckle, a flat brim.
const LEPRECHAUN_HAT: Array[String] = [
	"...kkkkkkkkkk...",
	"..kbGGGGGGGggk..",
	"..kbGGGGGGGggk..",
	"...kkkkkkkkkk...",
	"...kbGGGGGggk...",
	"...kbGGGGGggk...",
	"...kbGGGGGggk...",
	"...kbGGGGGggk...",
	"...kwwllllwwk...",
	"...kwwlkklwwk...",
	".kkkbGGllGggkkk.",
	"kbGGGGGGGGGGGggk",
	"kggggggggggggggk",
	".kkkkkkkkkkkkkk.",
]

## Valentine heart headband from row 15 (16 rows, 16 wide, rise 15): a thin art-brain-shade band on the
## crown with two pink hearts (chalk glint) bobbing on ink-only zigzag springs (ink needs no neighbours).
const HEART_HEADBAND: Array[String] = [
	".kk.kk..........",
	"kPPkPPk...kk.kk.",
	"kcPPPRk..kPPkPPk",
	".kPPRk...kcPPPRk",
	"..kRk.....kPPRk.",
	"...k.......kRk..",
	"...k........k...",
	"....k......k....",
	"...k......k.....",
	"....k......k....",
	"...k......k.....",
	"....k......k....",
	"...k......k.....",
	".kkkkkkkkkkkkkk.",
	"kRRRRRRRRRRRRRRk",
	".kkkkkkkkkkkkkk.",
]

## The hat seat row, and how far a hat may rise above it (style sheet section 3).
const HAT_SEAT_ROW: int = 30
const HAT_MAX_RISE: int = 18

## New Year's top hat from row 15 (16 rows, 16 wide, rise 15): an ink-muted top hat with a stone highlight
## stripe (so it never turns into an ink blob on night), a chalk band, confetti dots (pumpkin-light,
## art-brain-pink, zombie-green-bright).
const TOP_HAT: Array[String] = [
	"...kkkkkkkkkk...",
	"..ktmmmmmmmmmk..",
	"..ktmmmmmmmmmk..",
	"..ktmmlmmmmPmk..",
	"..ktmmmmmmmmmk..",
	"..ktmmmmbmmmmk..",
	"..ktmPmmmmmmmk..",
	"..ktmmmmmmlmmk..",
	"..ktmmmmmmmmmk..",
	"..kcccccccccck..",
	"..kssssssssssk..",
	"..ktmmmmmmmmmk..",
	".kktmmmmmmmmmkk.",
	"ktmmmmmmmmmmmmmk",
	"kmmmmmmmmmmmmmmk",
	".kkkkkkkkkkkkkk.",
]

## Pirate hat from row 19 (12 rows, 20 wide, rise 11): an ink-muted bicorne with pumpkin-light trim, the
## brim tips turned up, a chalk diamond badge. No skull and crossbones (style sheet section 5: no bones).
const PIRATE_HAT: Array[String] = [
	"........kkkk........",
	".kk...kktmmmkk...kk.",
	"kllk.ktmmmmmmmk.kllk",
	"klllktmmmmmmmmmklllk",
	"kllltmmmmccmmmmmmllk",
	"kllmmmmmccccmmmmmllk",
	"klmmmmmmmccmmmmmmmlk",
	"klmmmmmmmmmmmmmmmmlk",
	"kllllllllllllllllllk",
	".kmmmmmmmmmmmmmmmmk.",
	"..kmmmmmmmmmmmmmmk..",
	"...kkkkkkkkkkkkkk...",
]

## Golden crown from row 19 (12 rows, 16 wide, rise 11): five pumpkin-light points (pumpkin shade, chalk
## glints; gold without candy-yellow), a bat-purple / art-brain-pink / bat-purple gem row.
const CROWN: Array[String] = [
	".......kk.......",
	"....kkkcckkk....",
	".kkkclkllkclkkk.",
	"kclkllkllkllkclk",
	"kllkllkllkllkllk",
	"kllllllllllllllk",
	"kllppllPPllpplok",
	"kllppllPPllpplok",
	"kllllllllllllllk",
	"kcllllllllllllok",
	"kooooooooooooook",
	".kkkkkkkkkkkkkk.",
]
## Story 9.1 hat file name (= its catalogue id) -> [map, first row].
const NEW_HATS: Dictionary[String, Array] = {
	"hat_witch": [WITCH_HAT, 13],
	"hat_bunny_ears": [BUNNY_EARS, 13],
	"hat_santa": [SANTA_HAT, 15],
	"hat_leprechaun": [LEPRECHAUN_HAT, 17],
	"hat_heart_headband": [HEART_HEADBAND, 15],
	"hat_top_hat": [TOP_HAT, 15],
	"hat_pirate": [PIRATE_HAT, 19],
	"hat_crown": [CROWN, 19],
}

const GHOST_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"c": "chalk",
	"s": "stone-light",
	"p": "art-brain-pink",
}

## Ghost head from its top row: the dome, dot eyes, pink cheeks and a tiny mouth (10 rows). The right
## column is the stone-light shade.
const GHOST_HEAD: Array[String] = [
	"....kkkkkk....",
	"..kkcccccckk..",
	".kcccccccccsk.",
	"kcccccccccccsk",
	"kcccccccccccsk",
	"kccckcccckccsk",
	"kccckcccckccsk",
	"kccpccccccpcsk",
	"kccccckkccccsk",
	"kcccccccccccsk",
]
## One body row: the filler between the head and the tail, so the head can bob 1 px while the tail tips
## stay on row 30.
const GHOST_BODY_ROW: String = "kcccccccccccsk"
## The wavy tail, rows 28-30; the ink tips on row 30 are the ghost's soles. A and B are the wave's two
## phases.
const GHOST_TAIL_A: Array[String] = [
	"kcccccccccccsk",
	"kccckkcckkccsk",
	"kkkk..kk..kkkk",
]
const GHOST_TAIL_B: Array[String] = [
	"kcccccccccccsk",
	"kcckcccccckcsk",
	"kkk.kkkkkk.kkk",
]
const GHOST_TAIL_TOP: int = 28
## The head's top row per frame: up, down, up, down (the 1 px float). With the tails A, B, B, A no two
## frames match.
const GHOST_TOPS: Array[int] = [12, 13, 12, 13]

## Shared by every Story 9.2 pet (the Orange cat swaps its fur with ORANGE_CAT_LEGEND). Never candy-yellow
## (focus only), stamp-red (the stamp only) or art-moon (the moon).
const PET_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"c": "chalk",
	"s": "stone-light",
	"t": "stone",
	"m": "ink-muted",
	"d": "dusk",
	"x": "ink-muted",
	"p": "bat-purple",
	"l": "pumpkin-light",
	"P": "art-brain-pink",
	"R": "art-brain-shade",
	"g": "zombie-green",
}
## The Orange cat is the Black cat's maps with the fur recoloured: m fur, d shade, x stripes (ink-muted, so
## invisible, on the Black cat).
const ORANGE_CAT_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"c": "chalk",
	"m": "pumpkin",
	"d": "wood-light",
	"x": "wood",
	"P": "art-brain-pink",
}
## The size of a pet in every frame (opaque extents): clearly a pet beside the 32 px zombie (about 30 tall),
## with a gap inside its 32 px frame (style sheet section 3, Pets). test_art_sprites.gd checks the same.
const PET_MIN_HEIGHT: int = 12
const PET_MAX_HEIGHT: int = 22
const PET_MAX_WIDTH: int = 28
## Pets stand like characters: the soles (or a floater's shadow) on row 30 in every frame, so PetSlot's
## (-16, -31) offset puts them on the node origin.
const PET_SOLES_ROW: int = 30
## Animation limits (style sheet section 3): 2-6 frames.
const PET_MIN_FRAMES: int = 2
const PET_MAX_FRAMES: int = 6
## A floater's shadow on row 30 (Bat, Floating eyeball): a 10 px ink dash, centred, so the soles rule holds
## while the body hovers above it.
const FLOAT_SHADOW: Array[String] = ["kkkkkkkkkk"]

## Cats (Black and Orange, 18 wide, 17-18 x 18): sitting, facing the viewer, the tail curling up on the
## right. Ears from row 13 (pink inside); the flick bends the right ear out.
const CAT_EARS: Array[String] = [
	".k........k.......",
	"kPk......kPk......",
	"kPmkkkkkkmPk......",
]

const CAT_EARS_FLICK: Array[String] = [
	".k................",
	"kPk......kkk......",
	"kPmkkkkkkmPPk.....",
]

## The head from row 16 (ink eyes with a chalk glint, a pink nose, a small mouth) and the body: a chalk
## bib, x stripes on the sides, paws, the bottom ink on row 30 (the soles).
const CAT_BODY: Array[String] = [
	"kmmmxmmxmmmk......",
	"kmckmmmmckdk......",
	"kmkkmmmmkkdk......",
	"kmmmmPPmmmdk......",
	"kmmmkmmkmmdk......",
	".kmmmkkmmdk.......",
	"..kmmccmmdk.......",
	".kmmccccmmdk......",
	".kxmccccmxdk......",
	"kmmmmccmmmdk......",
	"kxmmmmmmmxdk......",
	"kmmmmmmmmmdk......",
	"kmmkmmkmmkdk......",
	"kmmkmmkmmkdk......",
	".kkkkkkkkkk.......",
]

## The tail from row 20, its base on row 30 beside the body: A curls left, B is straight, C curls right.
const CAT_TAIL_A: Array[String] = [
	".............kkk..",
	"............kmmmk.",
	"............kkmmk.",
	".............kmmk.",
	".............kmmk.",
	".............kmmk.",
	".............kmmk.",
	"...........kkkmmk.",
	"...........kmmmmk.",
	"...........kmmmmk.",
	"...........kkkkkk.",
]

const CAT_TAIL_B: Array[String] = [
	"..............kk..",
	".............kmmk.",
	".............kmmk.",
	".............kmmk.",
	".............kmmk.",
	".............kmmk.",
	".............kmmk.",
	"...........kkkmmk.",
	"...........kmmmmk.",
	"...........kmmmmk.",
	"...........kkkkkk.",
]

const CAT_TAIL_C: Array[String] = [
	"..............kkk.",
	".............kmmmk",
	".............kmmkk",
	".............kmmk.",
	".............kmmk.",
	".............kmmk.",
	".............kmmk.",
	"...........kkkmmk.",
	"...........kmmmmk.",
	"...........kmmmmk.",
	"...........kkkkkk.",
]

## The Black cat's blink: the eye rows (17, 18) with the eyes shut.
const CAT_BLINK: Array[String] = [
	"kmmmmmmmmmdk......",
	"kmkkmmmmkkdk......",
]

## Spider (22 wide, 22 x 13-14, the smallest): a round bat-purple body (dusk shade), big chalk eyes, pink
## cheeks and a smile, bobbing 1 px (top row 17/18), drawn over its legs.
const SPIDER_BODY: Array[String] = [
	"........kkkkkk........",
	"......kkppppppkk......",
	".....kppppppppppk.....",
	"....kpcccppppcccdk....",
	"....kpcckppppkccdk....",
	"....kpcckppppkccdk....",
	"....kpPpkppppkpPdk....",
	".....kpppkkkkppdk.....",
	"......kkpppppdkk......",
	"........kkkkkk........",
]

## Six short, chunky bat-purple legs from row 21 (filled, so they read on night): two bent up on each side
## and two front feet on row 30. The tap lifts the front feet 1 px; the outer legs keep row 30.
const SPIDER_LEGS: Array[String] = [
	"kkkk..............kkkk",
	"kppp..............pppk",
	"kpkkk............kkkpk",
	"kpkkkkkk......kkkkkkpk",
	"kpkpppp........ppppkpk",
	"kpkpkkk........kkkpkpk",
	"kkkpk..kpk..kpk..kpkkk",
	"..kpk..kpk..kpk..kpk..",
	"..kpk..kpk..kpk..kpk..",
	"..kkk..kkk..kkk..kkk..",
]

const SPIDER_TAP: Array[String] = [
	"kkkk..............kkkk",
	"kppp..............pppk",
	"kpkkk............kkkpk",
	"kpkkkkkk......kkkkkkpk",
	"kpkpppp........ppppkpk",
	"kpkpkkkkpk..kpkkkkpkpk",
	"kkkpk..kpk..kpk..kpkkk",
	"..kpk..kpk..kpk..kpk..",
	"..kpk..kkk..kkk..kpk..",
	"..kkk............kkk..",
]

## Bat (28 wide, 28 x 14-15): a round bat-purple body (dusk shade), pointy ears, glint eyes, pink cheeks
## and a smile (no fangs), tiny feet. It hovers over FLOAT_SHADOW, bobbing 1 px while its wings flap up,
## mid, down, mid.
const BAT_BODY: Array[String] = [
	"........kk........kk........",
	"........kpk......kpk........",
	"........kppkkkkkkppk........",
	".......kppppppppppppk.......",
	".......kppckppppckpdk.......",
	".......kppkkppppkkpdk.......",
	".......kppPpkppkpPpdk.......",
	".......kpppppkkpppddk.......",
	"........kpppppppppdk........",
	".........kkkkkkkkkk.........",
	"...........kk..kk...........",
]

const BAT_WINGS_UP: Array[String] = [
	"kk........................kk",
	"kpkk....................kkpk",
	"kpppkkk..............kkkpppk",
	"kpppppp..............ppppppk",
	"kpppppp..............ppppppk",
	"kpkppkp..............pkppkpk",
	"kk.kk.k..............k.kk.kk",
]

const BAT_WINGS_MID: Array[String] = [
	"..kkkkk..............kkkkk..",
	".kppppp..............pppppk.",
	"kpppppp..............ppppppk",
	"kpkppkp..............pkppkpk",
	"kk.kk.k..............k.kk.kk",
]

const BAT_WINGS_DOWN: Array[String] = [
	"....kkk..............kkk....",
	"..kkppp..............pppkk..",
	".kppppp..............pppppk.",
	"kpppppk..............kpppppk",
	"kpkppk................kppkpk",
	"kk.kk..................kk.kk",
]

## Crow (20 wide, 20 x 16-17): a plump ink-muted ball facing left (toward the zombie on the menu), a chalk
## eye glint, a pumpkin-light beak, a stone wing patch, a tail on the right. It bobs down 1 px onto
## squatted legs, blinks, and flicks its tail up.
const CROW_BODY: Array[String] = [
	"......kkkkkk........",
	"....kkmmmmmmkk......",
	"...kmmmmmmmmmmk.....",
	"..kmmckmmmmmmmmk....",
	"kkkmmkkmmmmmmmmmk...",
	"klllkmmmmmmmmmmmmk..",
	"kkkkmmmmmtttmmmmmk..",
	"...kmmmmttttmmmmmkkk",
	"...kmmmmtttttmmmmmmk",
	"...kmmmmmttttmmmmkk.",
	"....kmmmmmmmmmmmk...",
	".....kmmmmmmmmmk....",
	"......kkkkkkkkk.....",
]

const CROW_BLINK: Array[String] = [
	"..kmmmmmmmmmmmmk....",
]

const CROW_TAIL_UP: Array[String] = [
	".................kk.",
	"................kmmk",
	"...kmmmmtttttmmmmmmk",
]

## Ink legs and pumpkin-light feet on row 30: standing (from row 27) and squatted (from row 28).
const CROW_LEGS: Array[String] = [
	"........k...k.......",
	".......kkk.kkk......",
	"......kllk.kllk.....",
	"......kkkk.kkkk.....",
]

const CROW_SQUAT: Array[String] = [
	".......kkk.kkk......",
	"......kllk.kllk.....",
	"......kkkk.kkkk.....",
]

## Wolf-dog (22 wide, up to 22 x 19, the largest): a sitting puppy, not a wolf. A stone-light head with soft
## floppy stone ears, ink eyes, a chalk muzzle, a nose and a smile; the pink tongue pants in and out.
const PUP_HEAD: Array[String] = [
	"...kkkkkkkkkk.........",
	".kkksssssssskkk.......",
	"kttksssssssskttk......",
	"kttkskksskkskttk......",
	"kttkskksskkskttk......",
	"kttkscckkccskttk......",
	"kttksccccccskttk......",
	".ktksckcckcsktk.......",
	".kkkkcckkcckkkk.......",
	"....kkkkkkkk..........",
]

const PUP_TONGUE: Array[String] = [
	"......kPPk............",
	"......kPPk............",
	".......kk.............",
]

## The body from row 22: a chalk chest, a stone shade, chalk paws, the bottom ink on row 30.
const PUP_BODY: Array[String] = [
	"...kssccccsskk........",
	"..ksssccccssstk.......",
	"..ksssccccssstk.......",
	"..kssssccsssstk.......",
	".kssssssssssstk.......",
	".kssskssssksstk.......",
	".kccckssssksctk.......",
	".kccckkkkkkcck........",
	".kkkkk....kkkk........",
]

## The wagging tail from row 22: up, diagonal, flat, diagonal.
const PUP_TAIL_UP: Array[String] = [
	"...............kk.....",
	"..............kssk....",
	"..............kssk....",
	"..............kssk....",
	"..............kssk....",
	"..............kssk....",
	"..............kkkk....",
]

const PUP_TAIL_DIAG: Array[String] = [
	"..................kk..",
	".................kssk.",
	"................kssk..",
	"...............kssk...",
	"..............kssk....",
	"..............kssk....",
	"..............kkkk....",
]

const PUP_TAIL_FLAT: Array[String] = [
	"......................",
	"......................",
	"......................",
	"................kkkkk.",
	"..............kksssssk",
	"..............ksssskk.",
	"..............kkkkk...",
]

## Floating eyeball (20 wide, 20 x 16-17): a friendly one-eyed creature, never a body part. A round chalk
## ball (stone-light shade) with one big zombie-green iris, an ink pupil and a glint, pink cheeks and a
## smile; no veins, no red, no stalk. Tiny bat-purple wings flap while it bobs over FLOAT_SHADOW.
const EYE_BALL: Array[String] = [
	".......kkkkkk.......",
	".....kkcccccckk.....",
	"....kcccccccccsk....",
	"....kcccggggccsk....",
	"...kcccggggggccsk...",
	"...kcccgckkggccsk...",
	"...kcccggkkggccsk...",
	"...kcccggggggccsk...",
	"...kccccggggcccsk...",
	"...kcccccccccccsk...",
	"...kcPcckcckcPcsk...",
	"....kcccckkcsssk....",
	".....kkccccsskk.....",
	".......kkkkkk.......",
]

## The blink: the iris rows become a happy closed eye.
const EYE_BLINK: Array[String] = [
	"....kcccccccccsk....",
	"...kcccccccccccsk...",
	"...kccckcccckccsk...",
	"...kcccckkkkcccsk...",
	"...kcccccccccccsk...",
	"...kcccccccccccsk...",
]

const EYE_WINGS_UP: Array[String] = [
	"k..................k",
	"kk................kk",
	"kpk..............kpk",
	"kpp..............ppk",
	"kkk..............kkk",
]

const EYE_WINGS_MID: Array[String] = [
	"kkk..............kkk",
	"kpp..............ppk",
	"kkk..............kkk",
]

const EYE_WINGS_DOWN: Array[String] = [
	"kkk..............kkk",
	"kpp..............ppk",
	"kpk..............kpk",
	"kk................kk",
	"k..................k",
]

## Brain buddy (16 wide, 16 x 13-14): the game's cartoon brain (art-brain-pink with an art-brain-shade
## fissure and folds, like the brain pop), dot eyes and a smile, walking in place on two zombie-green
## feet: one foot lifts as the body bobs up 1 px.
const BRAIN_BODY: Array[String] = [
	"...kkkkkkkkkk...",
	"..kPPPPRPPPPPk..",
	".kPPPPPRPPPPPPk.",
	"kPRRPPPRPPPPPPPk",
	"kPPPPPPRPPPPRRRk",
	"kPPPkPPPPPPkPPRk",
	"kPPPkPPPPPPkPPRk",
	"kPPPPPkPPkPPPPRk",
	".kPPPPPkkPPPPRk.",
	"..kkkkkkkkkkkk..",
]

const BRAIN_BLINK: Array[String] = [
	"kPPPPPPPPPPPPPRk",
]

const BRAIN_FEET_DOWN: Array[String] = [
	"...kgk....kgk...",
	"..kggk....kggk..",
	"..kkkk....kkkk..",
]

const BRAIN_FEET_LEFT_UP: Array[String] = [
	"...kgk....kgk...",
	"..kggk....kgk...",
	"..kkkk....kggk..",
	"..........kkkk..",
]

const BRAIN_FEET_RIGHT_UP: Array[String] = [
	"...kgk....kgk...",
	"...kgk....kggk..",
	"..kggk....kkkk..",
	"..kkkk..........",
]

## Story 9.2 pet sheet name (pet_<id without the prefix>_idle) -> [frames, legend]. A frame is a list of
## parts [map, first row] drawn in order: a later part covers an earlier one ('.' never erases).
const NEW_PETS: Dictionary[String, Array] = {
	"pet_black_cat_idle": [[
		[[CAT_EARS, 13], [CAT_BODY, 16], [CAT_TAIL_A, 20]],
		[[CAT_EARS, 13], [CAT_BODY, 16], [CAT_TAIL_B, 20]],
		[[CAT_EARS, 13], [CAT_BODY, 16], [CAT_TAIL_C, 20]],
		[[CAT_EARS, 13], [CAT_BODY, 16], [CAT_TAIL_B, 20], [CAT_BLINK, 17]],
	], PET_LEGEND],
	"pet_spider_idle": [[
		[[SPIDER_LEGS, 21], [SPIDER_BODY, 17]],
		[[SPIDER_LEGS, 21], [SPIDER_BODY, 18]],
		[[SPIDER_TAP, 21], [SPIDER_BODY, 17]],
		[[SPIDER_TAP, 21], [SPIDER_BODY, 18]],
	], PET_LEGEND],
	"pet_orange_cat_idle": [[
		[[CAT_EARS, 13], [CAT_BODY, 16], [CAT_TAIL_A, 20]],
		[[CAT_EARS, 13], [CAT_BODY, 16], [CAT_TAIL_B, 20]],
		[[CAT_EARS, 13], [CAT_BODY, 16], [CAT_TAIL_C, 20]],
		[[CAT_EARS_FLICK, 13], [CAT_BODY, 16], [CAT_TAIL_B, 20]],
	], ORANGE_CAT_LEGEND],
	"pet_bat_idle": [[
		[[BAT_WINGS_UP, 16], [BAT_BODY, 16], [FLOAT_SHADOW, 30]],
		[[BAT_WINGS_MID, 20], [BAT_BODY, 17], [FLOAT_SHADOW, 30]],
		[[BAT_WINGS_DOWN, 20], [BAT_BODY, 17], [FLOAT_SHADOW, 30]],
		[[BAT_WINGS_MID, 19], [BAT_BODY, 16], [FLOAT_SHADOW, 30]],
	], PET_LEGEND],
	"pet_crow_idle": [[
		[[CROW_BODY, 14], [CROW_LEGS, 27]],
		[[CROW_BODY, 15], [CROW_SQUAT, 28]],
		[[CROW_BODY, 14], [CROW_LEGS, 27], [CROW_BLINK, 17]],
		[[CROW_BODY, 15], [CROW_SQUAT, 28], [CROW_TAIL_UP, 20]],
	], PET_LEGEND],
	"pet_wolf_dog_idle": [[
		[[PUP_TAIL_UP, 22], [PUP_BODY, 22], [PUP_HEAD, 12], [PUP_TONGUE, 20]],
		[[PUP_TAIL_DIAG, 22], [PUP_BODY, 22], [PUP_HEAD, 12], [PUP_TONGUE, 20]],
		[[PUP_TAIL_FLAT, 22], [PUP_BODY, 22], [PUP_HEAD, 12], [PUP_TONGUE, 20]],
		[[PUP_TAIL_DIAG, 22], [PUP_BODY, 22], [PUP_HEAD, 12]],
	], PET_LEGEND],
	"pet_eyeball_idle": [[
		[[EYE_WINGS_UP, 16], [EYE_BALL, 14], [FLOAT_SHADOW, 30]],
		[[EYE_WINGS_MID, 19], [EYE_BALL, 14], [FLOAT_SHADOW, 30]],
		[[EYE_WINGS_DOWN, 20], [EYE_BALL, 15], [FLOAT_SHADOW, 30]],
		[[EYE_WINGS_MID, 20], [EYE_BALL, 15], [EYE_BLINK, 18], [FLOAT_SHADOW, 30]],
	], PET_LEGEND],
	"pet_brain_buddy_idle": [[
		[[BRAIN_FEET_LEFT_UP, 27], [BRAIN_BODY, 17]],
		[[BRAIN_FEET_DOWN, 28], [BRAIN_BODY, 18]],
		[[BRAIN_FEET_RIGHT_UP, 27], [BRAIN_BODY, 17]],
		[[BRAIN_FEET_DOWN, 28], [BRAIN_BODY, 18], [BRAIN_BLINK, 23]],
	], PET_LEGEND],
}


func _init() -> void:
	var errors: Array[Error] = []
	for dir: String in [HATS_DIR, PETS_DIR]:
		errors.append(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)))
	var hat: Image = _sheet_image([[[PUMPKIN_HAT, 19]]], HAT_LEGEND)
	errors.append(_save(hat, HATS_DIR + "/hat_pumpkin.png") if hat != null else ERR_INVALID_DATA)
	for hat_name: String in NEW_HATS:
		var new_hat: Image = null
		if _hat_part_ok(hat_name, NEW_HATS[hat_name]):
			new_hat = _sheet_image([[NEW_HATS[hat_name]]], HAT_LEGEND)
		errors.append(_save(new_hat, "%s/%s.png" % [HATS_DIR, hat_name]) if new_hat != null else ERR_INVALID_DATA)
	var ghost: Image = _sheet_image(_ghost_frames(), GHOST_LEGEND)
	if ghost != null and not _pet_sheet_ok("pet_cute_ghost_idle", ghost):
		ghost = null
	errors.append(_save(ghost, PETS_DIR + "/pet_cute_ghost_idle.png") if ghost != null else ERR_INVALID_DATA)
	for pet_name: String in NEW_PETS:
		var pet: Image = _sheet_image(NEW_PETS[pet_name][0], NEW_PETS[pet_name][1])
		if pet != null and not _pet_sheet_ok(pet_name, pet):
			pet = null
		errors.append(_save(pet, "%s/%s.png" % [PETS_DIR, pet_name]) if pet != null else ERR_INVALID_DATA)
	# Non-zero exit on any failure, so a bad map, path or cwd doesn't look like success.
	quit(0 if errors.all(func(err: Error) -> bool: return err == OK) else 1)


## The four idle frames: head at GHOST_TOPS[i], body rows down to the tail, tails A, B, B, A.
func _ghost_frames() -> Array:
	var tails: Array = [GHOST_TAIL_A, GHOST_TAIL_B, GHOST_TAIL_B, GHOST_TAIL_A]
	var frames: Array = []
	for i: int in GHOST_TOPS.size():
		var top: int = GHOST_TOPS[i]
		var body_top: int = top + GHOST_HEAD.size()
		var body: Array[String] = []
		for _row: int in GHOST_TAIL_TOP - body_top:
			body.append(GHOST_BODY_ROW)
		frames.append([[GHOST_HEAD, top], [body, body_top], [tails[i], GHOST_TAIL_TOP]])
	return frames


func _color(color_name: String) -> Color:
	return Color.html(Proto.PALETTE[color_name])


## The documented hat rules (header comment): the last map row is row 30, the top row is >= 12, an even
## row count and a non-empty first row. push_error and false on a bad map, so it never writes a PNG.
func _hat_part_ok(hat_name: String, part: Array) -> bool:
	var rows: Array = part[0]
	var top: int = part[1]
	if rows.is_empty() or (rows[0] as String).is_empty():
		push_error("%s: empty map" % hat_name)
		return false
	if top + rows.size() - 1 != HAT_SEAT_ROW or top < HAT_SEAT_ROW - HAT_MAX_RISE or rows.size() % 2 != 0:
		push_error("%s: want the last row on %d, top row >= %d and an even row count (top %d, %d rows)" % [
				hat_name, HAT_SEAT_ROW, HAT_SEAT_ROW - HAT_MAX_RISE, top, rows.size()])
		return false
	return true


## The documented pet rules (header comment): PET_MIN_FRAMES-PET_MAX_FRAMES frames, no two identical, and
## in every frame the lowest opaque row is PET_SOLES_ROW, the height is PET_MIN_HEIGHT-PET_MAX_HEIGHT and
## the width at most PET_MAX_WIDTH. push_error and false on a bad sheet, so it never writes a PNG.
func _pet_sheet_ok(pet_name: String, sheet: Image) -> bool:
	var count: int = sheet.get_width() / FRAME
	if count < PET_MIN_FRAMES or count > PET_MAX_FRAMES:
		push_error("%s: %d frames, want %d-%d" % [pet_name, count, PET_MIN_FRAMES, PET_MAX_FRAMES])
		return false
	var seen: Array[PackedByteArray] = []
	for i: int in count:
		var frame: Image = sheet.get_region(Rect2i(i * FRAME, 0, FRAME, FRAME))
		var used: Rect2i = frame.get_used_rect()
		if used.end.y - 1 != PET_SOLES_ROW or used.size.y < PET_MIN_HEIGHT or used.size.y > PET_MAX_HEIGHT \
				or used.size.x > PET_MAX_WIDTH:
			push_error("%s frame %d: used rect %s, want the soles on row %d, %d-%d tall, <= %d wide" % [
					pet_name, i, used, PET_SOLES_ROW, PET_MIN_HEIGHT, PET_MAX_HEIGHT, PET_MAX_WIDTH])
			return false
		if seen.has(frame.get_data()):
			push_error("%s frame %d repeats an earlier frame" % [pet_name, i])
			return false
		seen.append(frame.get_data())
	return true


## One horizontal strip of FRAME x FRAME frames, each part centred on column 16 (its rows share one even
## width). Returns null (after push_error) on a bad map.
func _sheet_image(frames: Array, legend: Dictionary[String, String]) -> Image:
	var image: Image = Image.create_empty(frames.size() * FRAME, FRAME, false, Image.FORMAT_RGBA8)
	for i: int in frames.size():
		for part: Array in frames[i]:
			var rows: Array = part[0]
			var top: int = part[1]
			if top < 0 or top + rows.size() > FRAME or rows.is_empty():
				push_error("frame %d: part from row %d does not fit" % [i, top])
				return null
			var width: int = (rows[0] as String).length()
			if width % 2 != 0 or width > FRAME:
				push_error("frame %d row %d: width %d, want an even width <= %d" % [i, top, width, FRAME])
				return null
			var left: int = (FRAME - width) / 2
			for y: int in rows.size():
				var row: String = rows[y]
				if row.length() != width:
					push_error("frame %d row %d: %d chars, want %d" % [i, top + y, row.length(), width])
					return null
				for x: int in width:
					var ch: String = row[x]
					if ch == ".":
						continue
					if not legend.has(ch) or not Proto.PALETTE.has(legend[ch]):
						push_error("frame %d (%d,%d): '%s' not in legend/palette" % [i, x, top + y, ch])
						return null
					image.set_pixel(i * FRAME + left + x, top + y, _color(legend[ch]))
	return image


func _save(image: Image, path: String) -> Error:
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s (%dx%d)" % [path, error_string(err), image.get_width(), image.get_height()])
	return err
