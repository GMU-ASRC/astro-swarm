extends RefCounted

const LADDER := [
	"CADET",
	"ENSIGN",
	"LIEUTENANT",
	"LT. COMMANDER",
	"COMMANDER",
	"SWARM CAPTAIN",
	"SQUADRON CAPTAIN",
	"FLEET CAPTAIN",
	"COMMODORE",
	"REAR ADMIRAL",
	"VICE ADMIRAL",
	"ADMIRAL",
	"FLEET ADMIRAL",
]

static func rank_name(level: int) -> String:
	var index: int = maxi(level, 1) - 1
	if index < LADDER.size():
		return LADDER[index]
	var star: int = index - LADDER.size() + 2
	return "%s %s" % [LADDER[LADDER.size() - 1], _roman(star)]

static func next_rank_name(level: int) -> String:
	return rank_name(level + 1)

static func _roman(value: int) -> String:
	var numerals := [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var result := ""
	for pair in numerals:
		while value >= pair[0]:
			result += pair[1]
			value -= pair[0]
	return result
