class_name ZombieName
## The zombie name rules (Story 11.1, FR78: a plain-word, length-limited name). Pure and static: no nodes,
## no autoloads. A name is ASCII letters (A-Z, a-z, case kept as typed) and single spaces between words, at
## most GameConstants.ZOMBIE_NAME_MAX_LENGTH characters, with at least one letter. ASCII only: the pixel font
## (Press Start 2P) has no glyphs for accented or non-Latin letters, so those are ignored like any other key.
## append / backspace drive the name screen while typing (a trailing space is allowed there, so "Sam " can
## become "Sam Z"); clean is what PlayerData stores; is_valid is what PlayerData reads back.
## The name is personal data (NFR12): nothing here logs.

const SPACE: String = " "


## True for exactly one ASCII letter, A-Z or a-z. Not locale-aware on purpose: "é" and "ß" are false.
static func is_letter(c: String) -> bool:
	if c.length() != 1:
		return false
	var code: int = c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


## `current` with `c` added, or `current` unchanged when `c` is not a letter or a single space, when the
## result would be longer than the max, or when `c` is a space and `current` is empty, ends in a space, or
## would fill the last slot (a trailing space is stripped on save, so it must not block the 12th letter).
static func append(current: String, c: String) -> String:
	if current.length() >= GameConstants.ZOMBIE_NAME_MAX_LENGTH:
		return current
	if is_letter(c):
		return current + c
	if c == SPACE and not current.is_empty() and not current.ends_with(SPACE) 			and current.length() < GameConstants.ZOMBIE_NAME_MAX_LENGTH - 1:
		return current + c
	return current


## `current` without its last character (an empty name stays empty).
static func backspace(current: String) -> String:
	return current.left(-1) if not current.is_empty() else current


## Only the letters and spaces of `raw`, space runs collapsed to one, no leading or trailing space, cut to
## the max length (and a space the cut leaves at the end dropped). May return "" (then it isn't valid).
static func clean(raw: String) -> String:
	var out: String = ""
	for i: int in raw.length():
		var c: String = raw[i]
		if is_letter(c):
			out += c
		elif c == SPACE and not out.is_empty() and not out.ends_with(SPACE):
			out += c
	out = out.strip_edges()
	return out.left(GameConstants.ZOMBIE_NAME_MAX_LENGTH).strip_edges()


## True for a name that clean() leaves unchanged, 1..max characters long, with at least one letter.
static func is_valid(name: String) -> bool:
	return not name.is_empty() and name == clean(name) and name.length() <= GameConstants.ZOMBIE_NAME_MAX_LENGTH
