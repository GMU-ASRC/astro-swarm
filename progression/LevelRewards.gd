extends RefCounted

const BASE_COINS := 25
const BASE_XP := 40
const COINS_PER_LEVEL_NUMBER := 5
const XP_PER_LEVEL_NUMBER := 10
const FLAWLESS_BONUS_COINS := 15
const FLAWLESS_BONUS_XP := 20

static func coins_for(level_id: String) -> int:
	return BASE_COINS + _steps_past_first(level_id) * COINS_PER_LEVEL_NUMBER

static func xp_for(level_id: String) -> int:
	return BASE_XP + _steps_past_first(level_id) * XP_PER_LEVEL_NUMBER

static func grant(level_id: String, flawless: bool = false) -> Dictionary:
	var reward := {
		"coins": coins_for(level_id),
		"xp": xp_for(level_id),
		"bonus_coins": FLAWLESS_BONUS_COINS if flawless else 0,
		"bonus_xp": FLAWLESS_BONUS_XP if flawless else 0,
	}
	PlayerData.add_coins(reward["coins"] + reward["bonus_coins"])
	PlayerData.add_xp(reward["xp"] + reward["bonus_xp"])
	return reward

static func _steps_past_first(level_id: String) -> int:
	return maxi(LevelInfo.number(level_id) - 1, 0)
