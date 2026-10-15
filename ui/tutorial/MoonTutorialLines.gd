extends RefCounted

static func for_moon(moon_id: String) -> Array:
	match moon_id:
		"shipyard":
			return _shipyard()
		"genome":
			return _genome()
	return []

static func _shipyard() -> Array:
	return [
		{"id": 1, "text": "Welcome to the Shipyard, Commander. Every ship that leaves {planet} is fitted out right here."},
		{"id": 2, "text": "Upgrades raise what your ship can do, how fast it flies, how sharp it turns, and how far and how wide it sees. Each one costs Astro Coin."},
		{"id": 3, "text": "Addons unlock new blocks in the workspace. Buy one and its block shows up in your palette, ready to program."},
		{"id": 4, "text": "Win levels to earn coin, then come back and spend it. A better ship gives your algorithm more to work with."},
	]

static func _genome() -> Array:
	return [
		{"id": 1, "text": "This is the Genome moon, Commander. Every algorithm you write is a genome, and this is where they all live."},
		{"id": 2, "text": "One genome is active at a time. That is the one your ships run in every level, and the one the workspace edits."},
		{"id": 3, "text": "Press new to start a genome from scratch, or duplicate one you like and change the copy. Your original stays safe."},
		{"id": 4, "text": "Rename them so you remember what each one does, and delete the ones that did not work out."},
		{"id": 5, "text": "Press edit on any genome to open it in the workspace. Save as new in the workspace branches a copy without leaving."},
		{"id": 6, "text": "In a level you can switch the genome your defenders fly from the top bar. Picking one before launch is free, but once the run starts you only get three switches."},
		{"id": 7, "text": "Spend Astro Coin on the upgrade up top to earn more switches per level. A well timed switch can turn a losing run around."},
		{"id": 8, "text": "Keep your best ideas here. Soon you will field different species of ship, and each one will fly its own genome."},
	]
