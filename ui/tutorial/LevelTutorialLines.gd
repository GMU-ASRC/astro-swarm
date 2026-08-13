extends RefCounted

static func for_level(level_id: String) -> Array:
	match level_id:
		"farp1":
			return _level_one()
		"farp2":
			return _level_two()
		"farp3":
			return _level_three()
		"farp4":
			return _level_four()
		"farp5":
			return _level_five()
		"farp6":
			return _level_six()
	return []

static func _level_one() -> Array:
	return [
		{"id": 1, "text": "Dr. Blob at your service, Commander. That planet in the middle is a forward arming and refuelling point, and today it is yours to keep."},
		{"id": 2, "text": "One red evader will come in off the outer ring and drive straight at the planet. Everything you do here is about stopping it."},
		{"id": 3, "text": "Drag inside the blue ring to drop a defender. The direction you drag is the way it ends up facing, so aim it as you place it. You get up to six, and a right click takes one away again."},
		{"id": 4, "text": "Every defender runs the same program, and you write it in the workspace. Blocks decide how they move, how far they see and how wide they look. Wide eyes find the evader sooner, long eyes find it further out, and you cannot have both."},
		{"id": 5, "text": "Detection is the first moment any defender gets the evader inside its vision cone. That is a sighting and nothing more. It does not stop anything."},
		{"id": 6, "text": "Capture is a defender actually touching the evader, and that is what ends the run in your favour. So give them a reason to charge once they see something."},
		{"id": 7, "text": "When the layout looks right, press launch and watch it play out. Every launch is sent up automatically and my machines run it a hundred times over on the server. Good luck, Commander."},
	]

static func _level_two() -> Array:
	return [
		{"id": 1, "text": "Same planet, Commander, but this time you do not get to place anything. I have scattered the defenders for you."},
		{"id": 2, "text": "Five of them, dropped at random inside the blue ring and facing whichever way they landed. Press reroll for a different scatter as often as you like."},
		{"id": 3, "text": "Whatever is on screen when you submit is the layout the server benchmarks, so pick a scatter you are willing to be graded on."},
		{"id": 4, "text": "That leaves the algorithm, and only the algorithm. Open the workspace and make them sweep. Turning while moving forward covers far more sky than driving in a straight line."},
		{"id": 5, "text": "Seeing the evader still does not stop it. Add a rule that turns a sighting into a chase, or you will watch it sail past a defender that spotted it."},
		{"id": 6, "text": "An algorithm that only works on one lucky scatter falls apart on the next. Reroll a few times before you commit."},
		{"id": 7, "text": "The best entry submitted here becomes the opponent in level five, layout and all. Beat everyone and other commanders will be flying against your work."},
	]

static func _level_three() -> Array:
	return [
		{"id": 1, "text": "Back on defence, Commander, and this time they are not sending one ship. Three evaders are inbound off the same red ring."},
		{"id": 2, "text": "Your five defenders are scattered for you, same as level two, and they all run whatever you write in the workspace. No placing by hand here."},
		{"id": 3, "text": "The good news is that a defender survives the kill. Touch an evader and it is gone, and your defender carries straight on to the next one."},
		{"id": 4, "text": "The bad news is that one evader touching the planet ends it. Destroying two out of three is still a breach, so there is no partial credit."},
		{"id": 5, "text": "The WAVE button decides how they arrive. Sequential sends the next only after the last is gone, which gives your line time to reset. Simultaneous sends all three together and punishes any arc you left uncovered."},
		{"id": 6, "text": "Chase harder than you did in level two. A defender that sits still might stop the first evader and never see the second."},
		{"id": 7, "text": "Every launch goes up to the server on its own now, and my machines run the whole thing again over a hundred waves. Watch the ring, Commander."},
	]

static func _level_four() -> Array:
	return [
		{"id": 1, "text": "Same three evaders, Commander, same scattered line. One rule changes, and it changes everything."},
		{"id": 2, "text": "Here a capture takes both ships. The evader dies and so does the defender that caught it. You are trading bodies now."},
		{"id": 3, "text": "Five defenders, three evaders. The arithmetic works, but only if every trade is a clean one. Two defenders piling onto the same evader is a body wasted."},
		{"id": 4, "text": "So keep them apart. When sees ally with a turn is worth far more here than it ever was on the earlier levels."},
		{"id": 5, "text": "Every kill thins your line, and the defenders still standing have to cover the sky the dead one was watching. Expect it to get harder as the wave goes on."},
		{"id": 6, "text": "Run out of defenders with evaders still inbound and it is over, same as letting one reach the planet."},
		{"id": 7, "text": "Simultaneous is brutal on this one. Three trades at once can strip most of your line in a heartbeat, so learn it on sequential first."},
		{"id": 8, "text": "Every run is submitted for you. Spend them wisely, Commander."},
	]

static func _level_five() -> Array:
	return [
		{"id": 1, "text": "Change of seat, Commander. Today you are the evader, and the planet is the thing you are trying to reach."},
		{"id": 2, "text": "The defenders in your way run the best level two algorithm anyone has submitted, standing exactly where that entry placed them. Their commander's name is up in the top bar."},
		{"id": 3, "text": "Drag anywhere on the red ring to choose where you start. Pick your approach before you launch, because you only get the one."},
		{"id": 4, "text": "Then you fly it yourself. Forward and back drive, left and right turn, and you can remap all of that in settings."},
		{"id": 5, "text": "Being seen is survivable. The first defender that gets you in its cone logs a detection and costs you the clean run, but the run carries on."},
		{"id": 6, "text": "Being touched is not survivable. Any defender that reaches you ends the run then and there."},
		{"id": 7, "text": "You have three minutes on the clock in the top right. Reach the planet and you win, and reaching it having never been seen is the run worth flying for."},
		{"id": 8, "text": "Every attempt is recorded and rendered on the website with your times, detected or not. Submit it either way. Good luck, Commander."},
	]

static func _level_six() -> Array:
	return [
		{"id": 1, "text": "Something different today, Commander. No evaders, no defence. Two swarms are out there milling in circles, minding their own business."},
		{"id": 2, "text": "Every one of those agents follows a single rule. It turns one way when it can see another ship, and the other way when it sees nothing at all. That rule on its own is what makes them mill."},
		{"id": 3, "text": "You fly the gold leader. They cannot tell you apart from one of their own, so wherever you go, you bend their turning. That is your only tool here."},
		{"id": 4, "text": "First job is the merge. The two groups count as one swarm when every agent is linked to the rest through its neighbours. Watch the two center markers become one gold marker."},
		{"id": 5, "text": "Second job is delivery. Walk that merged mill across the arena until its gold marker sits inside the white ring around the planet."},
		{"id": 6, "text": "Third job is the hard one. Leave. Get well clear and stay clear for a few seconds while the swarm holds together and keeps milling without you."},
		{"id": 7, "text": "The panel on the right keeps score. The loss is how far the swarm center sits from the planet plus how far the mill is from a clean circle. Lower is better, and I keep the lowest you reach."},
		{"id": 8, "text": "Five minutes on the clock. Be patient with them, Commander. Pull too hard and the ring comes apart in your hands."},
	]
