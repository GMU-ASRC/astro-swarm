extends RefCounted

const SEEN_FLAG := "tutorial_seen_lan_match"
const VOICE_DIR := "res://va/lan_match"

static func lines() -> Array:
	return [
		{"id": 1, "visual": "title", "text": "Welcome to a LAN Match, Commander! Two of you, two planets, one arena. Dr. Blob will walk you through it."},
		{"id": 2, "visual": "title", "text": "Your planet has a health bar. Enemy evaders that crash into it take a chunk off. Lose all of it and the match is over."},
		{"id": 3, "visual": "title", "text": "Everything costs astrodust. You start with a little. Mining moons are scattered across the arena, and each one shows how much dust it still holds."},
		{"id": 4, "visual": "title", "text": "Buy collectors in the SHOP, or press B. A collector flies your search algorithm until it touches a moon, fills its hold, and then flies straight home to unload."},
		{"id": 5, "visual": "title", "text": "Defenders wait in your hangar. Drag inside the ring around your planet to deploy one, and the drag direction sets where it faces. Evaders launch from your planet and hunt for the enemy."},
		{"id": 6, "visual": "title", "text": "An evader trades its life for any enemy ship it touches: defenders, collectors, scouts, even other evaders. So guard your collectors too."},
		{"id": 7, "visual": "title", "text": "Open the WORKSPACE, or press TAB, to program collectors, defenders and evaders. Changes reach your ships straight away, even mid match."},
		{"id": 8, "visual": "title", "text": "UPGRADES, or U, make your collectors carry more, mine faster and fly faster. A SCOUT is flown by hand with W A S D and the camera follows it. F toggles following and H jumps home."},
		{"id": 9, "visual": "title", "text": "You get thirty seconds of setup before the match goes live. In Fog of War you only see what your planet and ships can see, so send scouts and collectors out to find the moons. ESCAPE pauses or forfeits. Good luck!"},
	]
