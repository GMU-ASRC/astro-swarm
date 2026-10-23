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
		"farp9":
			return _pilot_level()
		"farp6":
			return _level_six()
		"farp7":
			return _level_seven()
		"farp8":
			return _level_eight()
	return []

static func _level_one() -> Array:
	return [
		{"id": 1, "text": "Dr. Blob at your service, Commander. That planet in the middle is {planet}, your forward arming and refuelling point, and today it is yours to keep."},
		{"id": 2, "text": "Ten red evaders will come in one after another from random points far out around {planet}, each driving straight at it. Everything you do here is about stopping them."},
		{"id": 3, "text": "Drag inside the blue ring to drop a defender. The direction you drag is the way it ends up facing, so aim it as you place it. You get up to twenty, and a right click takes one away again."},
		{"id": 4, "text": "Every defender runs the same program, and you write it in the workspace. Blocks decide how they move, how far they see and how wide they look. Wide eyes spot evaders sooner, long eyes spot them further out, and you cannot have both."},
		{"id": 5, "text": "Here, spotting is enough. The moment any defender gets an evader inside its vision cone, that evader vanishes. Any evader nobody spots reaches {planet}."},
		{"id": 6, "text": "I am also watching how your defenders move as a group. Their circliness, how well they hold a ring and circle together, is measured the whole time. If they split into smaller mills, I score every mill and average them, and you get that average at the end."},
		{"id": 7, "text": "I will open the workspace for you now. Write your program, come back, place your defenders and press launch. Keep {planet} clean and keep that circle tight. Good luck, Commander."},
	]

static func _level_two() -> Array:
	return [
		{"id": 1, "text": "Back at {planet}, Commander, but this time you do not get to place anything. I have scattered the defenders for you."},
		{"id": 2, "text": "Field anywhere from five up to five hundred of them. They drop at random inside the blue ring, facing whichever way they landed. Press reroll for a different scatter as often as you like."},
		{"id": 3, "text": "Whatever is on screen when you launch is the layout the server benchmarks, so pick a scatter you are willing to be graded on."},
		{"id": 4, "text": "That leaves the algorithm, and only the algorithm. Open the workspace and make them sweep. Turning while moving forward covers far more sky than driving in a straight line."},
		{"id": 5, "text": "Two evaders for every defender you field, one after another, but this time spotting one is not enough. A defender has to touch an evader to capture it, and only then does it disappear. You get a ten second head start before the first one shows up, so use it to get your swarm moving. Capture more than half of them and {planet} holds. Capture every one and there is a bonus in it for you."},
		{"id": 6, "text": "An algorithm that only works on one lucky scatter falls apart on the next. Reroll a few times before you commit. I am scoring circliness here too, mill by mill, so a swarm that breaks into tidy little circles still scores well."},
	]

static func _level_three() -> Array:
	return [
		{"id": 1, "text": "Back on defense, Commander, and this time they are not sending one ship and going home. They come in groups."},
		{"id": 2, "text": "Two waves in all. Each wave sends one evader for every defender you field, all at once, spread around the red ring."},
		{"id": 3, "text": "Pick how many defenders to field, five up to five hundred. They are scattered for you, same as level two, and they all run whatever you write in the workspace."},
		{"id": 4, "text": "The good news is that a defender survives the kill. Touch an evader and it is gone, and your defender is still standing for the second wave."},
		{"id": 5, "text": "A bigger line faces a bigger wave, so more defenders will not make this easier. Every arc of the ring gets tested at once."},
		{"id": 6, "text": "The second wave launches the moment the first is settled. A defender that chased the first wave halfway to the ring is out of position for the next one. Give them a reason to come home."},
		{"id": 7, "text": "Hold both waves and nothing touches {planet}. Out on the server I run the same two waves against every line size, so build something that scales. Watch the ring, Commander."},
	]

static func _level_four() -> Array:
	return [
		{"id": 1, "text": "Back to waves, Commander, one evader at a time this time, each from a fresh bearing on the red ring. Pick five, ten, fifteen or twenty scattered defenders, and one rule that changes everything."},
		{"id": 2, "text": "Here a capture takes both ships. The evader dies and so does the defender that caught it. You are trading bodies now."},
		{"id": 3, "text": "Every defender you field is one kill, and not one more. Two defenders piling onto the same evader is a body wasted and a wave you will not be there for."},
		{"id": 4, "text": "So keep them apart. When sees ally with a turn is worth far more here than it ever was on the earlier levels."},
		{"id": 5, "text": "Every kill thins your line, and the defenders still standing have to cover the sky the dead one was watching. Nothing comes back."},
		{"id": 6, "text": "Five waves here, and the run ends early if the last defender goes. I report how many you destroyed, how many got through, and how many bodies it cost."},
		{"id": 7, "text": "Out on the server I do not stop at five. I keep sending them until your line is gone, so a trade you can afford in the fifth wave may be one you cannot afford in the fifteenth. Spend them wisely, Commander."},
	]

static func _level_five() -> Array:
	return [
		{"id": 1, "text": "No waves today, Commander. They are done trickling in one at a time. Five evaders, all at once, all aimed at {planet}."},
		{"id": 2, "text": "They do not come off the ring either. They come off the edges of the arena, spread right around it, so the ones on the long sides arrive well after the ones above and below."},
		{"id": 3, "text": "Pick five, ten, fifteen or twenty defenders. They are scattered for you, same as always, and they run whatever you write in the workspace."},
		{"id": 4, "text": "Attrition is still on. A capture takes both ships, so a small line has to make every single trade a clean one, and a big line has to keep from wasting bodies on the same evader."},
		{"id": 5, "text": "Chasing far out is how you lose this. An evader you miss on the way out is behind your line, and the body you spent chasing is not coming back."},
		{"id": 6, "text": "Watch the timing instead. They arrive in a stagger, so a line that holds its arcs near {planet} gets to meet them one at a time anyway."},
		{"id": 7, "text": "The run plays out until every one of them is destroyed or has touched {planet}. I count both, and the defenders it cost you. Good luck, Commander."},
	]

static func _pilot_level() -> Array:
	return [
		{"id": 1, "text": "Change of seat, Commander. Today you are the evader, and the planet is the thing you are trying to reach."},
		{"id": 2, "text": "The defenders in your way run the best level two algorithm anyone has submitted, standing exactly where that entry placed them. Their commander's name is up in the top bar."},
		{"id": 3, "text": "Drag anywhere on the red ring to choose where you start. Pick your approach before you launch, because you only get the one."},
		{"id": 4, "text": "Then you fly it yourself. Forward and back drive, left and right turn, and you can remap all of that in settings."},
		{"id": 5, "text": "Being seen is survivable. The first defender that gets you in its cone logs a detection and costs you the clean run, but the run carries on."},
		{"id": 6, "text": "Being touched is not survivable. Any defender that reaches you ends the run then and there."},
		{"id": 7, "text": "You have three minutes on the clock in the top right. Reach the planet and you win, and reaching it having never been seen is the run worth flying for."},
		{"id": 8, "text": "Every attempt is recorded and rendered on the website with your times, detected or not. Good luck, Commander."},
	]

static func _level_six() -> Array:
	return [
		{"id": 1, "text": "Something different today, Commander. No evaders, no defense. Two swarms are out there milling in circles, minding their own business."},
		{"id": 2, "text": "Every one of those agents follows a single rule. It turns one way when it can see another ship, and the other way when it sees nothing at all. That rule on its own is what makes them mill."},
		{"id": 3, "text": "You fly the gold leader. They cannot tell you apart from one of their own, so wherever you go, you bend their turning. That is your only tool here."},
		{"id": 4, "text": "First job is the merge. The two groups count as one swarm when every agent is linked to the rest through its neighbours. Watch the two center markers become one gold marker. Hold them together as one for a single second and you have passed."},
		{"id": 5, "text": "Second job is delivery. Walk that merged mill across the arena until its gold marker sits inside the white ring around the planet."},
		{"id": 6, "text": "Third job is the hard one. Leave. Get well clear and stay clear for a few seconds while the swarm holds together and keeps milling without you."},
		{"id": 7, "text": "The panel on the right keeps score. The loss is how far the swarm center sits from the planet plus how far the mill is from a clean circle. Lower is better, and I keep the lowest you reach."},
		{"id": 8, "text": "Five minutes on the clock. The merge is the pass, but the full delivery is the run worth flying. Be patient with them, Commander. Pull too hard and the ring comes apart in your hands."},
	]

static func _level_seven() -> Array:
	return [
		{"id": 1, "text": "Two planets today, Commander, and you are responsible for both of them. This one is planet A. There is another one out there called planet B, and I have not put a single defender on it."},
		{"id": 2, "text": "Pick ten or twenty five defenders before you start. All of them are parked here around planet A. That is the whole force. Nothing else is coming."},
		{"id": 3, "text": "Both planets get hit by the same number of evaders, half as many as you have defenders. And a capture takes both ships, so every defender is good for one kill. Leave them all here and planet B falls without a fight, and you get graded on both."},
		{"id": 4, "text": "That gold ship is your shuttle. It carries nothing. Every defender out there is already running the algorithm you wrote in the workspace, and the shuttle reads to them as one of their own, so whatever your when sees ally rule does is how they react to you. That is your steering. It has no vision cone of its own, so it never spots anything for you. Watch what your defenders see instead."},
		{"id": 5, "text": "When you want them to stop reacting to you, press Q. The shuttle goes purple and drops off their sensors completely, so they carry on as if you were never there. Press Q again to light it back up."},
		{"id": 6, "text": "The glowing strip along the edge of the arena is a jump gate, the right edge here at planet A and the left edge at planet B. Fly into it and you come out at the other planet straight away. Defenders that drift into it cross too, but they take a couple of seconds to get there."},
		{"id": 7, "text": "You can lead defenders into the gate yourself, or sit inside the blue band around a planet and press E. That drops a marker where you are, and a defender on the other planet turns purple and flies in through the gate to it. It lands facing the way you were pointing, so line yourself up first."},
		{"id": 8, "text": "You have thirty seconds to split them, or press begin assault when the allocation looks right. Then the evaders come for both planets at once, one at a time onto whichever planet they pick, and the fight goes on at a planet even while you are away from it. The gates stay open and E still calls a defender across, so you can move your line to wherever the evaders are landing. Choose well, Commander."},
	]

static func _level_eight() -> Array:
	return [
		{"id": 1, "text": "Three planets this time, Commander. This one is planet A, and it is the hub. Planet B is through the gate on the right edge, and planet C is through the gate on the bottom edge."},
		{"id": 2, "text": "Pick ten, twenty five or fifty defenders before you start. Every one of them starts here around planet A. Planets B and C start empty."},
		{"id": 3, "text": "Each planet gets hit by a third as many evaders as you have defenders, and a capture takes both ships. Every defender is good for one kill, so spread them to where the kills are."},
		{"id": 4, "text": "Your shuttle works the same as before, with no vision cone of its own. Lit, they read it as one of their own and follow your when sees ally rule. Press Q to go dark and slip away without dragging anyone along."},
		{"id": 5, "text": "Fly into a gate and you are through at once. Defenders that drift in follow a couple of seconds later. Planet B sends you back through its left edge, and planet C through its top edge, both straight to planet A."},
		{"id": 6, "text": "Inside the blue band around a planet, press E to call one defender over from whichever other planet holds the most. It flies in through the gate and lands facing the way you were pointing."},
		{"id": 7, "text": "When the window closes, evaders start landing on all three planets at random, and each planet fights with whatever you left there whether you are watching or not. The gates stay open and E still calls a defender across, so keep moving and send help where it is needed. Choose well, Commander."},
	]
