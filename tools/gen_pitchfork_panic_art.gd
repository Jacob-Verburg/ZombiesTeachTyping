extends SceneTree
## Dev-only: writes the Story 8.6 Pitchfork Panic art: the mob (two base villagers, a pitchfork and a torch,
## each with one clothes recolour), the zombie's dazed sit, the dust cloud, the escape bush, the dizzy star,
## the mob hint, and the Moonlit Village backdrop (clouds and stars, far hills, the near street front, the
## cobble tiles and ground strip, and the static moon).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_pitchfork_panic_art.gd
## then --import, so the .png.import files are written (Lossless, no mipmaps; Nearest is the project default).
##
## Characters, props and effects follow tools/gen_art_prototypes.gd exactly: ASCII maps, one character per
## pixel, '.' = transparent (keeps what earlier parts painted), '_' = clear to transparent, a legend maps a
## character to a palette NAME. The palette, the zombie legend and the approved zombie maps are read from that
## tool and tools/gen_horde_rush_art.gd (one source); a part here is [map, first row] or [map, first row,
## x shift]. Characters are 32x32 frames standing on row 30, props 16x16, effects 48x48 standing on row 46
## (style sheet section 3). The effect and mob-hint maps were laid out from discs with a grown 1 px ink
## outline and are kept here as plain maps, so the tool has no geometry for them.
## The mob recolours are their base maps with a clothes-only legend swap (MOB_CLOTHES_KEYS; _init checks
## every other key matches the base), so the mask and the ink are the base's in every frame.
##
## The backdrop is drawn from shapes at fixed, hard-coded positions: no RNG, so a rerun writes the same
## bytes. Every shape wraps around x (it is drawn at x and x +- 640), so each 640 px layer tiles with no
## seam, and the features that cross the seam are centred on it on purpose. Layers are exempt from the
## ink-outline rule only: palette colours, hard alpha, never candy-yellow (focus) or stamp-red (stamp), and
## art-moon only on the moon. The night readability band: near.png rows 160-191 (where the characters'
## legs and bodies pass) are fully opaque and use none of ink, night, zombie-green, zombie-green-bright,
## bat-purple, art-brain-pink or art-brain-shade, and neither do the ground strip's top 4 rows, so the
## zombie's outline, skin and shirt, the mob and the brains always stand out against the dark.
## Rules: docs/art-style-sheet.md; tests: test_art_sprites.gd, test_art_backdrop.gd.

const Proto := preload("res://tools/gen_art_prototypes.gd")
const HordeRush := preload("res://tools/gen_horde_rush_art.gd")

const ZOMBIE_DIR: String = "res://assets/sprites/characters/zombie"
const MOB_DIR: String = "res://assets/sprites/characters/mob"
const PROPS_DIR: String = "res://assets/sprites/props"
const BACKDROP_DIR: String = "res://assets/sprites/backdrops/moonlit_village"
const CHARACTER_FRAME: int = 32
const PROP_FRAME: int = 16
const EFFECT_FRAME: int = 48

# --- the mob: villagers woken up in nightcaps and pyjamas, running right (toward the zombie) ---

## The legend keys a recolour may change (cap and pyjamas); skin, eyes, hair, tools and slippers stay.
const MOB_CLOTHES_KEYS: Array[String] = ["c", "C", "n", "N"]

## Base A: pale blue pyjamas and nightcap, a pitchfork held straight up (wood-light handle, stone-light
## tines). s/S are the only skin characters (the villager's).
const MOB_PITCH_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"s": "art-skin-light",
	"S": "art-skin-dark",
	"w": "chalk",
	"H": "wood",
	"c": "art-sky-light",
	"C": "art-sky",
	"n": "art-sky-light",
	"N": "art-sky",
	"h": "wood-light",
	"t": "stone-light",
	"B": "wood-dark",
}

## A's recolour: cream pyjamas.
const MOB_PITCH_ALT_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"s": "art-skin-light",
	"S": "art-skin-dark",
	"w": "chalk",
	"H": "wood",
	"c": "parchment",
	"C": "parchment-shade",
	"n": "parchment",
	"N": "parchment-shade",
	"h": "wood-light",
	"t": "stone-light",
	"B": "wood-dark",
}

## Base B: a rounder villager with a moustache, grey pyjamas and a brown nightcap, holding a torch up (wood
## handle, a pumpkin / pumpkin-light flame with a parchment core; never candy-yellow or art-moon).
const MOB_TORCH_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"s": "art-skin-light",
	"S": "art-skin-dark",
	"w": "chalk",
	"H": "wood",
	"c": "wood-light",
	"C": "wood",
	"n": "disabled-fill",
	"N": "ink-faded",
	"h": "wood",
	"f": "pumpkin",
	"F": "pumpkin-light",
	"p": "parchment",
	"B": "wood-dark",
}

## B's recolour: orange pyjamas and a white nightcap.
const MOB_TORCH_ALT_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"s": "art-skin-light",
	"S": "art-skin-dark",
	"w": "chalk",
	"H": "wood",
	"c": "chalk",
	"C": "stone-light",
	"n": "pumpkin-light",
	"N": "pumpkin",
	"h": "wood",
	"f": "pumpkin",
	"F": "pumpkin-light",
	"p": "parchment",
	"B": "wood-dark",
}

## Base A from row 1: the pitchfork upright in the front (right) hand, tines on rows 1-5; a nightcap whose
## tail flops back to a pompom; big goofy eyes and a yelling mouth; the long nightshirt to the hem on row 24.
const PITCH_UPPER: Array[String] = [
	"........................k.k.k...",
	"...kkk.................ktktktk..",
	"..kwwwk................ktktktk..",
	"..kwwwkkkkkkkkkkk......ktttttk..",
	"...kkkccccccccccCkkkkk.kkkhkkk..",
	"......kccccccccccccccCk..khk....",
	"......kkkCCCCCCCCCCCCCk..khk....",
	".........kHsssssssssssk..khk....",
	".........kHskkkkskkkksk..khk....",
	".........kHskwwkskwwksk..khk....",
	".........kHskwkkskwkksk..khk....",
	".........kHskkkkskkkksk..khk....",
	".........kSsssssssSSssk..khk....",
	".........kSssskkkksssSk..khk....",
	"..........kSsskkkkssSk...khk....",
	"...........kkkkkkkkkk....khk....",
	"..........knnnnnnnnnnk...khk....",
	".........kNnnnnnnnnnnkkkkkkk....",
	".........kNnnnnnnnnnnnnnnsssk...",
	".........kNnnnnnnnnnNNNNNsssk...",
	".........kNnnnnnnnnnkkkkkkkkk...",
	".........kNnnnnnnnnnk....khk....",
	".........kNnnnnnnnnnk....khk....",
	".........kkkkkkkkkkkk....khk....",
	".........................kkk....",
]

## Base B from row 4: a stocking nightcap with its tail down the back to a pompom, sleepy half-shut eyes, a
## moustache over a little "o" mouth, a round nightshirt; the front arm raised, the hand on the torch handle
## (rows 13-15); the torch head on rows 7-8. The flame (rows 1-6) is a separate part per frame.
const TORCH_UPPER: Array[String] = [
	"..........kkkkkkkkk.............",
	".........kccccccccCk............",
	"........kccccccccccCk...........",
	".......kcccccccccccCkkkkkkkk....",
	"......kcCCCCCCCCCCCCk.khhhk.....",
	".....kcckHHsssssssssk..khk......",
	"....kcckkHskkkkskkkkk..khk......",
	"....kcckkHskSSkskSSkk..khk......",
	"...kkkkkkHskwkkskwkkk..khk......",
	"..kwwwk.kSskkkkskkkkk.kkkkk.....",
	"..kwwwk.kSsssssSSsssk.ksssk.....",
	"...kkk...kSHHHHHHHSk..ksssk.....",
	"..........kSskkkksSk.knnnk......",
	"..........kkkkkkkkkkkknnnk......",
	".........kNnnnnnnnnnnnnnk.......",
	"........kNnnnnnnnnnnnnnnk.......",
	".......kNnnnnnnnnnnnnnnk........",
	".......kNnnnnnnnnnnnnnnk........",
	".......kNNnnnnnnnnnnnnNk........",
	"........kNNNnnnnnnnnNNk.........",
	".........kkkkkkkkkkkkk..........",
]

## The torch flame from row 1, one shape per frame (the flicker): still, leaning right, tall, leaning left.
const FLAME_A: Array[String] = [
	"........................k.......",
	".......................kfk......",
	"......................kfFfk.....",
	".....................kfFpFfk....",
	".....................kfFpFfk....",
	"......................kfFfk.....",
]

const FLAME_B: Array[String] = [
	".........................k......",
	"........................kfk.....",
	"......................kkfFk.....",
	".....................kfFpFfk....",
	".....................kfFpFfk....",
	"......................kfFfk.....",
]

const FLAME_C: Array[String] = [
	"........................k.......",
	".......................kFk......",
	"......................kfpfk.....",
	".....................kfFpFfk....",
	".....................kfFpFfk....",
	"......................kfFfk.....",
]

const FLAME_D: Array[String] = [
	".......................k........",
	"......................kfk.......",
	"......................kFfkk.....",
	".....................kfFpFfk....",
	".....................kfFpFfk....",
	"......................kfFfk.....",
]

## Run legs from row 25 (both bases): contact (the near leg s forward, the far leg S back), passing, and
## the two with near and far swapped. Soles on row 30 in every frame.
const RUN_CONTACT_A: Array[String] = [
	"..........kSSk...kssk...........",
	".........kSSk.....kssk..........",
	"........kSSk.......kssk.........",
	".......kkkkk.......kkkkkk.......",
	".......kBBBk.......kBBBBBk......",
	".......kkkkk.......kkkkkkk......",
]

const RUN_PASS_A: Array[String] = [
	"...........kSSk.kssk............",
	"...........kSSk.kssk............",
	"...........kSSk.kssk............",
	"..........kkkkk.kkkkkk..........",
	"..........kBBBk.kBBBBBk.........",
	"..........kkkkk.kkkkkkk.........",
]

const RUN_CONTACT_B: Array[String] = [
	"..........kssk...kSSk...........",
	".........kssk.....kSSk..........",
	"........kssk.......kSSk.........",
	".......kkkkk.......kkkkkk.......",
	".......kBBBk.......kBBBBBk......",
	".......kkkkk.......kkkkkkk......",
]

const RUN_PASS_B: Array[String] = [
	"...........kssk.kSSk............",
	"...........kssk.kSSk............",
	"...........kssk.kSSk............",
	"..........kkkkk.kkkkkk..........",
	"..........kBBBk.kBBBBBk.........",
	"..........kkkkk.kkkkkkk.........",
]

# --- the zombie's dazed sit: the melt's sit pose with swirly eyes and its tongue out ---

## ZOMBIE_LEGEND plus the tongue (t). Must mirror ZOMBIE_LEGEND otherwise (_init checks it).
const DAZED_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"G": "zombie-green",
	"L": "zombie-green-bright",
	"g": "zombie-green-dark",
	"w": "chalk",
	"p": "bat-purple",
	"d": "dusk",
	"b": "wood",
	"B": "wood-dark",
	"t": "art-brain-pink",
}
const DAZED_OWN_KEYS: Array[String] = ["t"]
## The head (ZOMBIE_UPPER rows 0-13) sits from this row on the melt's sit pose; its crown stays flat and 12 px
## wide, so a hat seats on it.
const DAZED_HEAD_ROW: int = 9

## Swirly eyes over the head's eye whites (head row + 4), two swirl turns.
const DAZED_EYES_A: Array[String] = [
	"...........www...www............",
	"...........kkw...wkk............",
	"...........www...www............",
]

const DAZED_EYES_B: Array[String] = [
	"...........wkw...www............",
	"...........wkw...wkw............",
	"...........www...wkw............",
]

## The tongue lolling out of the grin (head row + 11).
const DAZED_TONGUE: Array[String] = [
	"........kggGGkkkttkkGGgk........",
	".........kggGGGkttkGggk.........",
]

# --- props: 16x16 ---

## A small 5-point star, parchment with a parchment-shade side, ink outline; at most 8 px wide. Never
## candy-yellow (focus only).
const STAR_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"p": "parchment",
	"S": "parchment-shade",
}

## From row 6: the star, then its twinkle (smaller, the shade on the other side); bottoms on row 12.
const STAR_A: Array[String] = [
	"......k.........",
	".....kpk........",
	"...kkkpkkk......",
	"...kpppppk......",
	"....kppSk.......",
	"....kpkSk.......",
	"....kk.kk.......",
]

const STAR_B: Array[String] = [
	"................",
	"......k.........",
	".....kpk........",
	"...kkpppkk......",
	"....kpSpk.......",
	"....kpkSk.......",
	"....kk.kk.......",
]

## The mob hint (32x32): two pitchfork tips and two torches poking in from the left screen edge, their
## handles down to row 30 (the ground); the flames flicker and the tools bob 1 px between the frames.
const HINT_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"t": "stone-light",
	"h": "wood-light",
	"f": "pumpkin",
	"F": "pumpkin-light",
	"p": "parchment",
}

# --- effects: 48x48, standing on row 46 ---

## The dust cloud: a cartoon scuffle of chalk puffs shaded stone-light, ink action lines and tiny chalk
## sparks (no limbs, nothing hurt).
const DUST_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"c": "chalk",
	"s": "stone-light",
}

## The escape bush: an art-grass dome with a zombie-green-dark base and leaf marks, a few bat-purple and
## pumpkin berries so it is not a zombie-green blob; frames 1-2 rustle (clumps shifted, leaves popping off).
const BUSH_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"g": "art-grass",
	"d": "zombie-green-dark",
	"b": "bat-purple",
	"o": "pumpkin",
}

# --- generated maps (laid out once from discs with a grown ink outline; edit them as maps) ---

const DUST_0_ROW: int = 12
const DUST_0: Array[String] = [
	"........................k.......................",
	".......................kck......................",
	"........................k.......................",
	"................................................",
	"................................................",
	"................................................",
	"...........................kkkkkk...............",
	"................kkkkkk...kksssssskk.............",
	"..............kksssssskkksccccccsssk............",
	".............ksccccccssssccccccccsssk....k......",
	"............ksccccccccssccccccccccsssk..kck.....",
	"...........ksccccccccccccccccccccccsssk..k......",
	"..........kscccccccccccccccccccccccsssk.........",
	".....k....kscccccccccccccccccccccccssssk........",
	"....kck..ksscccccccccckcccccccccccccsssk........",
	".....k...kscccccccccccckcccccccccccssssk........",
	".........kssccccccckcccckccccccccccssssk........",
	".........ksscccccckccccccccccccccccssssk........",
	".........kssccccckccccccccccccccccsssssk........",
	"........kssccccckccccccccccccccccccssssk........",
	".......ksccccccccccccccccccccccckccccsssk.......",
	"......ksccccccccccccccccccccccckccccccsssk......",
	"......kscccccccccccccccccccccckcccccccsssk......",
	".....kssccccccccccccccccccccckccccccccssssk.....",
	".....ksccccccccccccccccccccccccccccccccsssk.....",
	".....kssccccccccccccccccccccccccccccccssssk.....",
	".....kssccccccccccccccccccccccccccccccssssk.....",
	"....ksccccccccccccccccccccccccccccccccccsssk....",
	"....kscccccccccccsccccccccccscccccccccccsssk....",
	"....ksccccsccccsssssccccccsssssccccsccccsssk....",
	"....kssssssssssssssssssssssssssssssssssssssk....",
	"....kssssssssssssssssssssssssssssssssssssssk....",
	"....kssssssssssssssssssssssssssssssssssssssk....",
	".....kssssssssssskkkksssssskkkksssssssssssk.....",
	"......kkkkkkkkkkk....kkkkkk....kkkkkkkkkkk......",
]

const DUST_1_ROW: int = 11
const DUST_1: Array[String] = [
	".................k..............................",
	"................kck.............................",
	".................k..............................",
	"................................................",
	"................................................",
	"................................................",
	".................kkkkkkkk.......................",
	"...............kksssssssskk.....................",
	"..............ksccccccccsssk....................",
	".............ksccccccccccsssk...................",
	"....k.......ksccccccccccccssskkkkk..............",
	"...kck......kscccccccccccckssssssskk............",
	"....k......kscccccccccccckcsccccssssk...........",
	"...........ksccccccccccckcccccccccsssk..........",
	"...........ksccccccccccccccccccccccsssk.........",
	"...........ksccccccccccccccccccccccsssk...k.....",
	"..........kksccccccccccccccccccccccssssk.kck....",
	"........kksssscccccccccccccccccccckcsssk..k.....",
	".......kscccccccccccccccccccccccckcssssk........",
	"......kscccccccccccccccccccccccckccssssk........",
	".....kscccccccccccccccccccccccckcccssssk........",
	"....ksccccccccccccccccccccccccccccsssssk........",
	"....kscccccccccccccccccccccccccccccccsssk.......",
	"...ksscccccccckcccccccccccccccccccccccsssk......",
	"...kscccccccccckcccccccccccccccccccccccsssk.....",
	"...ksscccccccccckccccccccccccccccccccccsssk.....",
	"...kssccccccccccckcccccccccccccccccccccsssk.....",
	"...ksscccccccccccccccccccccccccccccccccssssk....",
	"...ksccccccccccccssccccccccccccccccccccccsssk...",
	"...kscccccccccccssssccccccccsscccccccccccsssk...",
	"...ksccccccccccssssssccccccssssccccccccccsssk...",
	"...kssssssssssssssssssssssssssssssssssssssssk...",
	"...kssssssssssssssssssssssssssssssssssssssssk...",
	"...ksssssssssssssskkssssssssssssssssssssssssk...",
	"....kssssssssssskk..kksssssskkkssssssssssssk....",
	".....kkkkkkkkkkk......kkkkkk...kkkkkkkkkkkk.....",
]

const DUST_2_ROW: int = 10
const DUST_2: Array[String] = [
	"..............................k.................",
	".............................kck................",
	"..............................k.................",
	"................................................",
	"................................................",
	"..........................kkkkkk........k.......",
	"........................kksssssskk.....kck......",
	"......................kksccccccssskk....k.......",
	".....................ksccccccccccsssk...........",
	"....................ksccccccccccccsssk..........",
	"....................kscccccccccckcsssk..........",
	"...............kkkkkscccccccccckcccsssk.........",
	".............kkssssssccccccccckccccsssk.........",
	"............kssccccssccccccccccccccssssk........",
	"...........kscccccccccccccccccccccccsssk........",
	"..........kscccccccccccccccccccccccssssk........",
	"..........kscccccccccccccccccccccccssssk........",
	".........ksscccccccccccccccccccccccssssk........",
	".........kscccccccccccccccccccccccsssssk........",
	"......k..ksscccccccccccccccccccccccsssk.........",
	".....kck.kssccccccccckccccccccccccccsssk........",
	"......k..ksscccccccckccccccccccccccccsssk.......",
	".........kssscccccckccccccccccccccccccsssk......",
	".........ksccccccckcccccccckccccccccccsssk......",
	"........kscccccccccccccccccckcccccccccssssk.....",
	".......kscccccccccccccccccccckcccccccccsssk.....",
	".......ksccccccccccccccccccccckcccccccssssk.....",
	"......kkscccccccccccccccccccccccccccccssssk.....",
	".....kssscccccccccccccccccccccccccccccsssssk....",
	"....kscccccccccccccccccccccccccccccccccccsssk...",
	"....kscccccccccccccccccccccsccccccccsccccsssk...",
	"....ksccccsccccccssccccccssssccccccssccccsssk...",
	"....ksssssssssssssssssssssssssssssssssssssssk...",
	"....ksssssssssssssssssssssssssssssssssssssssk...",
	"....ksssssssssssssssssssssssssssssssssssssssk...",
	".....ksssssssssssssksssssskkkksssssskssssssk....",
	"......kkkkkkkkkkkkk.kkkkkk....kkkkkk.kkkkkk.....",
]

const DUST_3_ROW: int = 13
const DUST_3: Array[String] = [
	"............k...................................",
	"...........kck..................................",
	"............k...................................",
	"................................................",
	"................................................",
	"................................................",
	"................kkkkkkkk.kkkkkkkk...............",
	"...............kssssssssksssssssskk.............",
	"..............ksccccccssccccccccsssk............",
	".............ksccccccccccccccccccsssk...........",
	"............ksccccccccckccccccccccsssk.....k....",
	"...........ksccccccccckcccccccccccsssk....kck...",
	"...........kscccccccckcccccccccccccsssk....k....",
	"...........ksccccccccccccccccccccccsssk.........",
	"...k.......ksccccccccccccccccccccccsssk.........",
	"..kck......ksccccccccccccccccccccccsssk.........",
	"...k......kksscccccccccccccccccccccsssk.........",
	".........ksssssccccccccccccccckcccssssk.........",
	"........ksccccccccccccccccccccckccccsssk........",
	".......ksccccccccccccccccccccccckccccsssk.......",
	"......kscccccccccckcccccccccccccckccccsssk......",
	".....kscccccccccckcccccccccccccccccccccsssk.....",
	".....ksccccccccckccccccccccccccccccccccsssk.....",
	".....kscccccccckcccccccccccccccccccccccsssk.....",
	".....ksccccccccccccccccccccccccccccccccsssk.....",
	"....kssccccccccccccccccccccccccccccccccsssk.....",
	"...kscccccccccccccccccccccccccccccccccccsssk....",
	"...kscccccccccccccccccccccccccccccccccccsssk....",
	"...ksccccsccccccssccccccccccssccccccccccsssk....",
	"...kssssssssssssssssccccccsssssssssssssssssk....",
	"...ksssssssssssssssssssssssssssssssssssssssk....",
	"...ksssssssssssssssssssssssssssssssssssssssk....",
	"....ksssssssssssssksssssssssskssssssssssssk.....",
	".....kkkkkkkkkkkkk.kkkkkkkkkk.kkkkkkkkkkkk......",
]

const BUSH_0_ROW: int = 12
const BUSH_0: Array[String] = [
	".....................kkkkkk.....................",
	"...................kkggggggkk...................",
	"..................kggggggggggk..................",
	".................kggggggggggggk.................",
	"................kggggggggggggggk................",
	"...............kggggdggggggggdggk...............",
	"...............kggggggggggggggggk...............",
	"..............kggggggggggggogggggk..............",
	"............kkggggggggggggggggggggkk............",
	"...........kdggggggggdggggggggdgggggk...........",
	"..........kggggggggggggggggggggggggggk..........",
	".........kggggggggggggggggggggggggggggk.........",
	"........kggggggggggggggggggggggggggggggk........",
	"........kggggdggggggggdggggggggdgggggggk........",
	".......kggggggggggggggggggggggggggggggggk.......",
	".......kggggggggggggggbgggggggggggggggggk.......",
	".......kggggggggggggggggggggggggggggggggk.......",
	".......kggggggdggggggggdggggggggdgggggggk.......",
	"......kggggggggggggggggggggggggggggggggggk......",
	".....kggggggggggggggggggggggggggggggggggggk.....",
	"....kggggggggggggggggggggggggggggggggggggggk....",
	"...kggdggggggggdggggggggdgggggoggdggggggggdgk...",
	"...kggggggggggggggggggggggggggggggggggggggggk...",
	"..kggggggggggggbgggggggggggggggggggggggggggggk..",
	"..kggggggggggggggggggggggggggggggggggggggggggk..",
	"..kggggdggggggggdggggggggdggggggggdggggggggdgk..",
	"..kggggggggggggggggggggggggggggggggggggggggggk..",
	"..kggggggggggggggggggggggggggggggggbgggggggggk..",
	"..kggggggggogggggggggggggggggggggggggggggggggk..",
	"...kddddddddddddddddddddddddddddddddddddddddk...",
	"...kddddddddddddddddddddddddddddddddddddddddk...",
	"....kddddddddddddddddddddddddddddddddddddddk....",
	".....kddddddddddddddddddddddddddddddddddddk.....",
	"......kddddddddddddddddddddddddddddddddddk......",
	".......kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk.......",
]

const BUSH_1_ROW: int = 6
const BUSH_1: Array[String] = [
	"..................................kk............",
	".................................kggk...........",
	"..................................kk............",
	"................................................",
	"................................................",
	"................................................",
	"...........k..........kkkkkk....................",
	"..........kgk.......kkggggggkk..................",
	".........kgk.......kggggggggggk.................",
	"..........k.......kggggggggggggk................",
	".................kggggggggggggggk...............",
	"................kggggdggggggggdggk..............",
	"................kggggggggggggggggk..............",
	".............kkkggggggggggggogggggk.............",
	"...........kkgggggggggggggggggggggk.............",
	"..........kggdggggggggdggggggggdgggk............",
	".........kggggggggggggggggggggggggggk...........",
	"........kggggggggggggggggggggggggggggk..........",
	".......kggggggggggggggggggggggggggggggk.........",
	".......kggggdggggggggdggggggggdgggggggk.........",
	"......kggggggggggggggggggggggggggggggggk........",
	"......kggggggggggggggbgggggggggggggggggk........",
	"......kggggggggggggggggggggggggggggggggk........",
	"......kggggggdggggggggdggggggggdgggggggkk.......",
	"......kggggggggggggggggggggggggggggggggggk......",
	".....kggggggggggggggggggggggggggggggggggggk.....",
	"....kggggggggggggggggggggggggggggggggggggggk....",
	"...kggdggggggggdggggggggdgggggoggdggggggggdgk...",
	"...kggggggggggggggggggggggggggggggggggggggggk...",
	"..kggggggggggggbgggggggggggggggggggggggggggggk..",
	"..kggggggggggggggggggggggggggggggggggggggggggk..",
	"..kggggdggggggggdggggggggdggggggggdggggggggdgk..",
	"..kggggggggggggggggggggggggggggggggggggggggggk..",
	"..kggggggggggggggggggggggggggggggggbgggggggggk..",
	"..kggggggggogggggggggggggggggggggggggggggggggk..",
	"...kddddddddddddddddddddddddddddddddddddddddk...",
	"...kddddddddddddddddddddddddddddddddddddddddk...",
	"....kddddddddddddddddddddddddddddddddddddddk....",
	".....kddddddddddddddddddddddddddddddddddddk.....",
	"......kddddddddddddddddddddddddddddddddddk......",
	".......kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk.......",
]

const BUSH_2_ROW: int = 5
const BUSH_2: Array[String] = [
	"...........kk...................................",
	"..........kggk..................................",
	"...........kk...................................",
	"................................................",
	"................................................",
	"................................................",
	"................................................",
	"....................kkkkkk......................",
	"..................kkggggggkk...........k........",
	".................kggggggggggk.........kgk.......",
	"................kggggggggggggk.......kgk........",
	"...............kggggggggggggggk.......k.........",
	"..............kggggdggggggggdggk................",
	"..............kggggggggggggggggk................",
	".............kggggggggggggogggggkkk.............",
	".............kgggggggggggggggggggggkk...........",
	"............kgggggggdggggggggdgggggggk..........",
	"...........kggggggggggggggggggggggggggk.........",
	"..........kggggggggggggggggggggggggggggk........",
	".........kggggggggggggggggggggggggggggggk.......",
	".........kggggdggggggggdggggggggdgggggggk.......",
	"........kggggggggggggggggggggggggggggggggk......",
	"........kggggggggggggggbgggggggggggggggggk......",
	"........kggggggggggggggggggggggggggggggggk......",
	".......kkggggggdggggggggdggggggggdgggggggk......",
	"......kggggggggggggggggggggggggggggggggggk......",
	".....kggggggggggggggggggggggggggggggggggggk.....",
	"....kggggggggggggggggggggggggggggggggggggggk....",
	"...kggdggggggggdggggggggdgggggoggdggggggggdgk...",
	"...kggggggggggggggggggggggggggggggggggggggggk...",
	"..kggggggggggggbgggggggggggggggggggggggggggggk..",
	"..kggggggggggggggggggggggggggggggggggggggggggk..",
	"..kggggdggggggggdggggggggdggggggggdggggggggdgk..",
	"..kggggggggggggggggggggggggggggggggggggggggggk..",
	"..kggggggggggggggggggggggggggggggggbgggggggggk..",
	"..kggggggggogggggggggggggggggggggggggggggggggk..",
	"...kddddddddddddddddddddddddddddddddddddddddk...",
	"...kddddddddddddddddddddddddddddddddddddddddk...",
	"....kddddddddddddddddddddddddddddddddddddddk....",
	".....kddddddddddddddddddddddddddddddddddddk.....",
	"......kddddddddddddddddddddddddddddddddddk......",
	".......kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk.......",
]

const HINT_0_ROW: int = 3
const HINT_0: Array[String] = [
	"...........k....................",
	"..........kfk...................",
	".........kfFfk.............k....",
	"........kfFpFfk...........kFk...",
	"..k.k.k.kfFpFfk..........kfpfk..",
	".ktktktk.kfFfk..........kfFpFfk.",
	".ktktktkkkkkkkk.........kfFpFfk.",
	".ktttttk.khhhk...........kfFfk..",
	".kkkhkkk..khk....k.k.k..kkkkkkk.",
	"...khk....khk...ktktktk..khhhk..",
	"...khk....khk...ktktktk...khk...",
	"...khk....khk...ktttttk...khk...",
	"...khk....khk...kkkhkkk...khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...kkk....kkk.....kkk.....kkk...",
]

const HINT_1_ROW: int = 2
const HINT_1: Array[String] = [
	"............k...................",
	"...........kfk..................",
	".........kkfFk..................",
	"........kfFpFfk.................",
	"........kfFpFfk...........k.....",
	".........kfFfk...........kfk....",
	"..k.k.k.kkkkkkk..........kFfkk..",
	".ktktktk.khhhk..........kfFpFfk.",
	".ktktktk..khk....k.k.k..kfFpFfk.",
	".ktttttk..khk...ktktktk..kfFfk..",
	".kkkhkkk..khk...ktktktk.kkkkkkk.",
	"...khk....khk...ktttttk..khhhk..",
	"...khk....khk...kkkhkkk...khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...khk....khk.....khk.....khk...",
	"...kkk....kkk.....kkk.....kkk...",
]

## Sheet path -> size, legend and frames; a frame is a list of parts. A var, not a const: the dazed frames
## slice the zombie's upper map (head only).
var sheets: Dictionary[String, Dictionary] = {
	MOB_DIR + "/mob_pitch_run.png": {
		"size": CHARACTER_FRAME,
		"legend": MOB_PITCH_LEGEND,
		"frames": _pitch_frames(),
	},
	MOB_DIR + "/mob_pitch_alt_run.png": {
		"size": CHARACTER_FRAME,
		"legend": MOB_PITCH_ALT_LEGEND,
		"frames": _pitch_frames(),
	},
	MOB_DIR + "/mob_torch_run.png": {
		"size": CHARACTER_FRAME,
		"legend": MOB_TORCH_LEGEND,
		"frames": _torch_frames(),
	},
	MOB_DIR + "/mob_torch_alt_run.png": {
		"size": CHARACTER_FRAME,
		"legend": MOB_TORCH_ALT_LEGEND,
		"frames": _torch_frames(),
	},
	ZOMBIE_DIR + "/zombie_dazed.png": {
		"size": CHARACTER_FRAME,
		"legend": DAZED_LEGEND,
		"frames": [
			[[Proto.ZOMBIE_UPPER.slice(0, 14), DAZED_HEAD_ROW], [DAZED_EYES_A, DAZED_HEAD_ROW + 4],
					[DAZED_TONGUE, DAZED_HEAD_ROW + 11], [HordeRush.MELT_SIT, 23]],
			[[Proto.ZOMBIE_UPPER.slice(0, 14), DAZED_HEAD_ROW, 1], [DAZED_EYES_B, DAZED_HEAD_ROW + 4, 1],
					[DAZED_TONGUE, DAZED_HEAD_ROW + 11, 1], [HordeRush.MELT_SIT, 23]],
		],
	},
	PROPS_DIR + "/dizzy_star.png": {
		"size": PROP_FRAME,
		"legend": STAR_LEGEND,
		"frames": [[[STAR_A, 6]], [[STAR_B, 6]]],
	},
	PROPS_DIR + "/mob_hint.png": {
		"size": CHARACTER_FRAME,
		"legend": HINT_LEGEND,
		"frames": [[[HINT_0, HINT_0_ROW]], [[HINT_1, HINT_1_ROW]]],
	},
	PROPS_DIR + "/dust_cloud.png": {
		"size": EFFECT_FRAME,
		"legend": DUST_LEGEND,
		"frames": [[[DUST_0, DUST_0_ROW]], [[DUST_1, DUST_1_ROW]], [[DUST_2, DUST_2_ROW]],
				[[DUST_3, DUST_3_ROW]]],
	},
	PROPS_DIR + "/escape_bush.png": {
		"size": EFFECT_FRAME,
		"legend": BUSH_LEGEND,
		"frames": [[[BUSH_0, BUSH_0_ROW]], [[BUSH_1, BUSH_1_ROW]], [[BUSH_2, BUSH_2_ROW]]],
	},
}

# --- backdrop ---

## Every layer is PERIOD wide, so two copies side by side always cover the 640 px screen.
const PERIOD: int = 640
## Layers cover the playfield above the ground line (y 0-192); the ground strip covers y 192-256.
const LAYER_H: int = 192
const GROUND_ROWS: int = 4
const TILE: int = PROP_FRAME
## The night readability band in near.png: fully opaque, none of the character colours (header).
const BAND_TOP: int = 160
## Stars stay below this row: the clouds layer scrolls, and the pause button sits top-right (y <= 40).
const STAR_TOP_Y: int = 44
const STAR_BOTTOM_Y: int = 132
const STAR_COUNT: int = 46

## Ground tiles: cobble, cobble with moss, cobble with a crack, a puddle with a moon glint (chalk: art-moon
## is the moon's alone). Every tile has a wood-dark grout border, so any tile sits beside or under any other.
const GROUND_LEGEND: Dictionary[String, String] = {
	"m": "wood-dark",
	"s": "ink-faded",
	"h": "parchment-shade",
	"d": "zombie-green-dark",
	"n": "ink-muted",
	"w": "dusk",
	"l": "chalk",
}

const TILE_COBBLE: Array[String] = [
	"mmmmmmmmmmmmmmmm",
	"mhhhhhhhmhhhhhhm",
	"mhssssssmhsssssm",
	"mhssssssmhsssssm",
	"mhssssssmhsssssm",
	"mhssssssmhsssssm",
	"mhssssssmhsssssm",
	"mmmmmmmmmmmmmmmm",
	"mhhhhmhhhhhhhhhm",
	"mhsssmhssssssssm",
	"mhsssmhssssssssm",
	"mhsssmhssssssssm",
	"mhsssmhssssssssm",
	"mhsssmhssssssssm",
	"mhsssmhssssssssm",
	"mmmmmmmmmmmmmmmm",
]

const TILE_MOSS: Array[String] = [
	"mmmmmmmmmmmmmmmm",
	"mhhhhhhhmhhhhhhm",
	"mhssssssmhsssssm",
	"mhssssssdhsssssm",
	"mhssssddddsssssm",
	"mhssssssdhsssssm",
	"mhssssssmhsssssm",
	"mmmmmmmmmmmmmmmm",
	"mhhhhmhhhhhhhhhm",
	"mhsssmhssssssssm",
	"mhsssmhssssssdsm",
	"mhssddhssssssddm",
	"mhsssmhsssssddsm",
	"mhsssmhssssssssm",
	"mhsssmhssssssssm",
	"mmmmmmmmmmmmmmmm",
]

const TILE_CRACK: Array[String] = [
	"mmmmmmmmmmmmmmmm",
	"mhhhhhhhmhhhhhhm",
	"mhssssssmhsssssm",
	"mhsssnssmhsssssm",
	"mhssssnsmhsssssm",
	"mhssnnssmhsssssm",
	"mhsssssnmhsssssm",
	"mmmmmmmmmmmmmmmm",
	"mhhhhmhhhhhhhhhm",
	"mhsssmhssssssssm",
	"mhsssmhssssnsssm",
	"mhsssmhsssnssssm",
	"mhsssmhssssnnssm",
	"mhsssmhssssssnsm",
	"mhsssmhssssssssm",
	"mmmmmmmmmmmmmmmm",
]

const TILE_PUDDLE: Array[String] = [
	"mmmmmmmmmmmmmmmm",
	"mhhhhhhhmhhhhhhm",
	"mhssssssmhsssssm",
	"mhssswwwwwwssssm",
	"mhswwwwwwwwwwssm",
	"mhwwwwlwwwwwwwsm",
	"mhwwwwwwwwwwwwsm",
	"mmwwwwwwwwwlwwmm",
	"mhwwwwwwwwwwwwhm",
	"mhswwwwwwwwwwssm",
	"mhsswwwwwwwwsssm",
	"mhsssmhssssssssm",
	"mhsssmhssssssssm",
	"mhsssmhssssssssm",
	"mhsssmhssssssssm",
	"mmmmmmmmmmmmmmmm",
]

const GROUND_TILES: Array = [TILE_COBBLE, TILE_MOSS, TILE_CRACK, TILE_PUDDLE]
## The tiles the walking path (row 0) may use: plain and cracked cobble.
const PATH_TILES: String = "02"

## Ground strip index map: row 0 is the walking path (cobble and crack), rows 1-3 every tile, 40 tiles a row.
const GROUND_MAP: Array[String] = [
	"0000200000000200000000002000000000200000",
	"0100030020001000200100300010002001000300",
	"0010200103000020010000201003000100200010",
	"2001000100200300010020000100200030001002",
]

## Night clouds (dusk): [centre x, bottom y, puff size]. The first is centred on the seam (x 0) on purpose.
const CLOUDS: Array[Vector3i] = [
	Vector3i(0, 74, 7),
	Vector3i(170, 56, 5),
	Vector3i(330, 88, 6),
	Vector3i(500, 62, 8),
]

## Far hills: the crest line is 150 - 8 cos(2 * 2 pi x / 640) - 5 cos(3 * 2 pi x / 640), a peak at the seam
## (x 0), so x 639 and x 0 sit on the same row. Dusk hills with an ink-muted crest.
const HILL_BASE_Y: float = 150.0
const HILL_A_PX: float = 8.0
const HILL_B_PX: float = 5.0
## Far houses (centre x): ink-muted silhouettes with pumpkin-light windows, standing on the crest.
const FAR_HOUSES: Array[int] = [64, 140, 300, 420, 610]
const FAR_CHURCH_X: int = 228
const FAR_WINDMILL_X: int = 530
## Friendly bats over the hills: [centre x, y]. Bat-purple with chalk eyes.
const BATS: Array[Vector2i] = [Vector2i(104, 82), Vector2i(372, 64), Vector2i(468, 100)]

## Near layer: cottages behind the garden wall (left edge x), the lamp post (x), and the jack-o'-lanterns on two
## window sills (centre x). The first cottage is centred on the seam on purpose. A lantern on the wall top (bottom
## row 159) would line up just over the zombie's crown (row 162) whenever the scroll put it behind the head and
## read as a hat (the Zombie Run lesson), so they sit on sills (bottom row LANTERN_BOTTOM), about 28 px higher.
const COTTAGES: Array[int] = [-32, 216, 448]
const COTTAGE_W: int = 64
const COTTAGE_WALL_TOP: int = 112
const LAMP_X: int = 150
const LAMP_TOP: int = 116
const LANTERNS: Array[int] = [233, 495]
const LANTERN_BOTTOM: int = 133
## The garden wall: capstones from BAND_TOP, stone blocks below (BLOCK_H rows, BLOCK_W wide, every other
## course offset by half a block).
const CAP_H: int = 4
const BLOCK_H: int = 7
const BLOCK_W: int = 20

## The moon: one 48x48 frame, a disc of art-moon with a friendly sleepy face in parchment-shade and an ink edge.
const MOON_SIZE: int = 48
const MOON_R: float = 21.0


func _init() -> void:
	var errors: Array[Error] = [
		_check_recolour(MOB_PITCH_ALT_LEGEND, MOB_PITCH_LEGEND, MOB_CLOTHES_KEYS, "MOB_PITCH_ALT_LEGEND"),
		_check_recolour(MOB_TORCH_ALT_LEGEND, MOB_TORCH_LEGEND, MOB_CLOTHES_KEYS, "MOB_TORCH_ALT_LEGEND"),
		_check_recolour(DAZED_LEGEND, Proto.ZOMBIE_LEGEND, DAZED_OWN_KEYS, "DAZED_LEGEND"),
	]
	for dir: String in [ZOMBIE_DIR, MOB_DIR, PROPS_DIR, BACKDROP_DIR]:
		errors.append(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)))
	for path: String in sheets:
		var sheet: Dictionary = sheets[path]
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
	errors.append(_save(_moon_image(), BACKDROP_DIR + "/moon.png"))
	# Non-zero exit on any failure, so a bad map, path or cwd doesn't look like success.
	quit(0 if errors.all(func(err: Error) -> bool: return err == OK) else 1)


## Base A's run: contact, passing, and the swaps (the pitchfork never moves: it is held straight up).
static func _pitch_frames() -> Array:
	return [
		[[PITCH_UPPER, 1], [RUN_CONTACT_A, 25]],
		[[PITCH_UPPER, 1], [RUN_PASS_A, 25]],
		[[PITCH_UPPER, 1], [RUN_CONTACT_B, 25]],
		[[PITCH_UPPER, 1], [RUN_PASS_B, 25]],
	]


## Base B's run: the same legs, and the flame changes shape every frame (the flicker).
static func _torch_frames() -> Array:
	return [
		[[TORCH_UPPER, 4], [FLAME_A, 1], [RUN_CONTACT_A, 25]],
		[[TORCH_UPPER, 4], [FLAME_B, 1], [RUN_PASS_A, 25]],
		[[TORCH_UPPER, 4], [FLAME_C, 1], [RUN_CONTACT_B, 25]],
		[[TORCH_UPPER, 4], [FLAME_D, 1], [RUN_PASS_B, 25]],
	]


## A recolour legend: every key it doesn't own is the base's, and it uses no key the base lacks.
func _check_recolour(legend: Dictionary[String, String], base: Dictionary[String, String],
		own: Array[String], label: String) -> Error:
	for ch: String in base:
		if ch in own:
			continue
		if legend.get(ch, "") != base[ch]:
			push_error("%s '%s' does not mirror its base" % [label, ch])
			return ERR_INVALID_DATA
	for ch: String in legend:
		if not base.has(ch) and not ch in own:
			push_error("%s adds '%s'" % [label, ch])
			return ERR_INVALID_DATA
	return OK


func _color(color_name: String) -> Color:
	return Color.html(Proto.PALETTE[color_name])


## One horizontal strip, `size` px per frame. Returns null (after push_error) on a bad map.
func _sheet_image(frames: Array, legend: Dictionary[String, String], size: int) -> Image:
	var image: Image = Image.create_empty(frames.size() * size, size, false, Image.FORMAT_RGBA8)
	for i: int in frames.size():
		for part: Array in frames[i]:
			var rows: Array = part[0]
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
			if index < 0 or index >= GROUND_TILES.size() or (row == 0 and not PATH_TILES.contains(line[col])):
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
	image.set_pixel(posmod(x, image.get_width()), y, _color(color_name))


func _rect(image: Image, x: int, y: int, w: int, h: int, color_name: String) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_put(image, xx, yy, color_name)


## A rect with a 1 px border in `edge`.
func _box(image: Image, x: int, y: int, w: int, h: int, color_name: String, edge: String = "ink") -> void:
	_rect(image, x, y, w, h, edge)
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


## Night clouds (dusk puffs) and chalk stars; transparent elsewhere (the Sky colour shows).
func _clouds_image() -> Image:
	var image: Image = _layer()
	# Stars at fixed, spread positions (a fixed stride, no RNG); every fourth one twinkles (a chalk-dim cross).
	for i: int in STAR_COUNT:
		var x: int = (i * 139 + 23) % PERIOD
		var y: int = STAR_TOP_Y + (i * 53) % (STAR_BOTTOM_Y - STAR_TOP_Y)
		_put(image, x, y, "chalk")
		if i % 4 == 0:
			for step: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				_put(image, x + step.x, y + step.y, "chalk-dim")
	for cloud: Vector3i in CLOUDS:
		var s: int = cloud.z
		_rect(image, cloud.x - 2 * s, cloud.y - s, 4 * s, s, "dusk")
		_blob(image, cloud.x - s, cloud.y - s, s, "dusk")
		_blob(image, cloud.x + s, cloud.y - s, s, "dusk")
		_blob(image, cloud.x, cloud.y - s - s / 2, s + 2, "dusk")
	return image


func _hill_y(x: int) -> int:
	var t: float = TAU * x / PERIOD
	return roundi(HILL_BASE_Y - HILL_A_PX * cos(2.0 * t) - HILL_B_PX * cos(3.0 * t))


## Dusk hills, ink-muted houses with lit windows, a church spire and a windmill on the crest, and bats.
func _far_image() -> Image:
	var image: Image = _layer()
	for x: int in PERIOD:
		var top: int = _hill_y(x)
		_rect(image, x, top, 1, LAYER_H - top, "dusk")
		_put(image, x, top, "ink-muted")
	for x: int in FAR_HOUSES:
		var ground: int = _hill_y(x) + 3
		_rect(image, x - 7, ground - 10, 14, 10, "ink-muted")
		_roof(image, x, ground - 16, ground - 10, "ink-muted")
		_rect(image, x - 4, ground - 7, 2, 2, "pumpkin-light")
		_rect(image, x + 2, ground - 7, 2, 2, "pumpkin-light")
	# The church: a tall nave, a spire, a round lit window.
	var church_ground: int = _hill_y(FAR_CHURCH_X) + 3
	_rect(image, FAR_CHURCH_X - 9, church_ground - 14, 18, 14, "ink-muted")
	_roof(image, FAR_CHURCH_X - 3, church_ground - 20, church_ground - 14, "ink-muted")
	_rect(image, FAR_CHURCH_X + 3, church_ground - 26, 5, 12, "ink-muted")
	_roof(image, FAR_CHURCH_X + 5, church_ground - 34, church_ground - 26, "ink-muted")
	_rect(image, FAR_CHURCH_X + 5, church_ground - 22, 1, 2, "pumpkin-light")
	_rect(image, FAR_CHURCH_X - 5, church_ground - 9, 3, 3, "pumpkin-light")
	# The windmill: a tower and four sails crossing at the hub.
	var base: int = _hill_y(FAR_WINDMILL_X) + 3
	var hub: Vector2i = Vector2i(FAR_WINDMILL_X, base - 15)
	_rect(image, FAR_WINDMILL_X - 3, hub.y, 6, base - hub.y, "ink-muted")
	_rect(image, FAR_WINDMILL_X - 1, base - 6, 2, 2, "pumpkin-light")
	for i: int in range(1, 8):
		_put(image, hub.x - i, hub.y - i, "ink-muted")
		_put(image, hub.x + i - 1, hub.y - i, "ink-muted")
		_put(image, hub.x - i, hub.y + i - 1, "ink-muted")
		_put(image, hub.x + i - 1, hub.y + i - 1, "ink-muted")
	for bat: Vector2i in BATS:
		_bat(image, bat.x, bat.y)
	return image


## A friendly bat, 9 x 4: round body, two wings up, two chalk eyes.
func _bat(image: Image, cx: int, cy: int) -> void:
	_rect(image, cx - 1, cy - 1, 3, 3, "bat-purple")
	_rect(image, cx - 4, cy - 2, 3, 1, "bat-purple")
	_rect(image, cx + 2, cy - 2, 3, 1, "bat-purple")
	_rect(image, cx - 3, cy - 1, 2, 1, "bat-purple")
	_rect(image, cx + 2, cy - 1, 2, 1, "bat-purple")
	_put(image, cx - 1, cy - 2, "bat-purple")
	_put(image, cx + 1, cy - 2, "bat-purple")
	_put(image, cx - 1, cy, "chalk")
	_put(image, cx + 1, cy, "chalk")


## The village street front: cottages behind a garden wall, a lamp post, jack-o'-lanterns on window sills.
## Rows BAND_TOP-191 are the readability band (header): the wall covers every column there.
func _near_image() -> Image:
	var image: Image = _layer()
	for x: int in COTTAGES:
		_cottage(image, x)
	_wall(image)
	_lamp_post(image, LAMP_X)
	for x: int in LANTERNS:
		_jack_o_lantern(image, x, LANTERN_BOTTOM)
	return image


## A cottage: a stone chimney, a wood-dark roof with wood shingle lines, ink-muted walls with two lit
## windows; its lower part is hidden behind the garden wall.
func _cottage(image: Image, x: int) -> void:
	var wall_top: int = COTTAGE_WALL_TOP
	_box(image, x + 42, wall_top - 26, 8, 18, "stone")
	_rect(image, x + 43, wall_top - 25, 6, 1, "stone-light")
	var cx: int = x + COTTAGE_W / 2
	_roof(image, cx, wall_top - 31, wall_top + 1, "ink")
	_roof(image, cx, wall_top - 30, wall_top, "wood-dark")
	for y: int in range(wall_top - 24, wall_top, 5):
		var half: int = y - (wall_top - 30)
		_rect(image, cx - half + 1, y, 2 * half - 2, 1, "wood")
	_box(image, x, wall_top, COTTAGE_W, BAND_TOP - wall_top, "ink-muted")
	for wx: int in [x + 10, x + 40]:
		_box(image, wx, wall_top + 10, 14, 12, "pumpkin-light", "wood-dark")
		_rect(image, wx + 7, wall_top + 11, 1, 10, "wood-dark")
		_rect(image, wx + 1, wall_top + 16, 12, 1, "wood-dark")
		_rect(image, wx - 1, wall_top + 22, 16, 2, "stone")


## The lamp post: an ink-muted post down to the ground (ink-muted is allowed in the band) and a lantern with
## pumpkin-light glass under a little roof. No glow: the light is the glass colour.
func _lamp_post(image: Image, x: int) -> void:
	_rect(image, x - 1, LAMP_TOP + 10, 3, LAYER_H - LAMP_TOP - 10, "ink-muted")
	_rect(image, x - 3, LAYER_H - 4, 7, 4, "ink-muted")
	_box(image, x - 4, LAMP_TOP, 9, 10, "pumpkin-light")
	_rect(image, x, LAMP_TOP + 1, 1, 8, "ink")
	_roof(image, x, LAMP_TOP - 5, LAMP_TOP, "ink")
	_put(image, x, LAMP_TOP - 6, "ink")


## The garden wall over the whole band: stone-light capstones, then stone blocks with ink-faded mortar.
func _wall(image: Image) -> void:
	_rect(image, 0, BAND_TOP, PERIOD, CAP_H, "stone-light")
	_rect(image, 0, BAND_TOP + CAP_H - 1, PERIOD, 1, "stone")
	for x: int in range(0, PERIOD, 32):
		_put(image, x, BAND_TOP + 1, "stone")
	_rect(image, 0, BAND_TOP + CAP_H, PERIOD, LAYER_H - BAND_TOP - CAP_H, "stone")
	var course: int = 0
	for y: int in range(BAND_TOP + CAP_H, LAYER_H, BLOCK_H):
		_rect(image, 0, y + BLOCK_H - 1, PERIOD, 1, "ink-faded")
		var offset: int = (course % 2) * (BLOCK_W / 2)
		for x: int in range(offset, PERIOD + offset, BLOCK_W):
			_rect(image, x, y, 1, mini(BLOCK_H - 1, LAYER_H - y), "ink-faded")
			_rect(image, x + 1, y, BLOCK_W - 2, 1, "stone-light")
		course += 1


## A friendly jack-o'-lantern (14 x 14) sitting on a window sill, its bottom ink row on `bottom`: pumpkin with
## a pumpkin-light shine, a wood-dark smiling face and a green stem.
func _jack_o_lantern(image: Image, cx: int, bottom: int) -> void:
	var cy: int = bottom - 6
	_blob(image, cx, cy, 7, "ink")
	_blob(image, cx, cy, 6, "pumpkin")
	_rect(image, cx - 4, cy - 4, 2, 3, "pumpkin-light")
	_rect(image, cx - 1, cy - 9, 2, 3, "ink")
	_rect(image, cx - 1, cy - 8, 1, 2, "zombie-green-dark")
	# Eyes (little triangles) and a smile.
	for side: int in [-3, 1]:
		_rect(image, cx + side, cy - 2, 2, 1, "wood-dark")
		_put(image, cx + side + (1 if side < 0 else 0), cy - 3, "wood-dark")
	_rect(image, cx - 3, cy + 1, 6, 1, "wood-dark")
	_put(image, cx - 4, cy, "wood-dark")
	_put(image, cx + 3, cy, "wood-dark")
	_put(image, cx - 1, cy + 2, "wood-dark")


## The moon: an art-moon disc with an ink edge and a sleepy smiling face (closed eyes, a smile, a crater).
func _moon_image() -> Image:
	var image: Image = Image.create_empty(MOON_SIZE, MOON_SIZE, false, Image.FORMAT_RGBA8)
	var c: float = MOON_SIZE / 2.0
	for y: int in MOON_SIZE:
		for x: int in MOON_SIZE:
			var d: float = Vector2(x + 0.5 - c, y + 0.5 - c).length()
			if d <= MOON_R:
				image.set_pixel(x, y, _color("art-moon"))
			elif d <= MOON_R + 1.0:
				image.set_pixel(x, y, _color("ink"))
	# Closed happy eyes: little arches.
	for ex: int in [16, 28]:
		_moon_px(image, ex, 20)
		_moon_px(image, ex + 1, 19)
		_moon_px(image, ex + 2, 19)
		_moon_px(image, ex + 3, 20)
	# The smile.
	for x: int in range(19, 30):
		_moon_px(image, x, 30 if x > 19 and x < 29 else 29)
	_moon_px(image, 20, 31)
	# Two craters.
	for p: Vector2i in [Vector2i(12, 27), Vector2i(13, 27), Vector2i(12, 28), Vector2i(33, 12), Vector2i(34, 12),
			Vector2i(33, 13), Vector2i(34, 13), Vector2i(35, 13)]:
		_moon_px(image, p.x, p.y)
	return image


func _moon_px(image: Image, x: int, y: int) -> void:
	image.set_pixel(x, y, _color("parchment-shade"))


func _save(image: Image, path: String) -> Error:
	if image == null:
		return ERR_INVALID_DATA
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s (%dx%d)" % [path, error_string(err), image.get_width(), image.get_height()])
	return err
