extends RefCounted

const VOICE_DIR := "res://va/base"
const SEEN_FLAG := "tutorial_seen_player_base"
const FINAL_HINT := "CLICK TO CLOSE"

const LINES := [
	{"id": 1, "text": "Welcome to your base, Commander. That world in the middle is {planet}, and everything in orbit around it is yours."},
	{"id": 2, "text": "Top left is your callsign, your rank and your experience bar. Fill the bar and you are promoted. Click your callsign to open your Astro ID, where your badges are kept."},
	{"id": 3, "text": "Top right is your Astro Coin. Win a level and I pay you in coin and experience, every time. Capture every evader on level two and there is a bonus on top."},
	{"id": 4, "text": "Those moons are more than decoration. Press Moons to visit them. Hivemind is where you program your spaceship, block by block, and it is open from the start."},
	{"id": 5, "text": "Rank up and more moons arrive. The first is the Shipyard. Spend coin there on upgrades that raise how fast, how far and how wide your programs may set a ship, and on addons such as Thrusters, which unlock the Throttle block."},
	{"id": 6, "text": "My Entries lists every run you have sent to the server. Come back to it to see how an entry scored and to claim the experience it earned."},
	{"id": 7, "text": "When you are ready, pick a game mode at the bottom and press Play. Start with Levels, Commander. I will meet you there."},
]
