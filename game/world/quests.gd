class_name Quests
extends Node
## The hero's quest log (a child of the Player, beside the Hud). Each quest is a short chain of
## steps; a step is taken by speaking to the right person, whose line for that step replaces
## what they would otherwise say. The Hud shows the active quest's title and objective in the
## top-left corner, and a banner when one begins or ends.
##
## Bread for the Keep (Edda's side thread, Act I): once Edda has introduced herself she asks
## the hero to carry a loaf up to Hesper in the ruined keep -- she sends one up every week and
## has never climbed after it since her husband went up and did not come down. Hesper's
## answer is a message; carried back down, it closes the quest, and Edda's oatcakes put heart
## in the hero (+15 vitality).

signal changed(id: String, stage: int)

const BREAD := "bread"
const BREAD_VIGOR := 15.0
## Per quest: its title, and per stage the objective while at it (stage 0 = not begun; the last
## stage is "done" and has no objective). `talk` maps a stage to [speaker, line, next stage].
const DEFS := {
	BREAD: {
		"title": "Bread for the Keep",
		"objectives": [
			"",
			"Carry Edda's loaf up to Hesper in the ruined keep",
			"Take Hesper's word back down to Edda on the green",
			"",
		],
		"talk": {
			0: ["Edda", "You'll be going up to the keep, I'd guess. Take this loaf to Hesper for me; she'll not come down for it, and I don't go up.", 1],
			1: ["Hesper", "Edda's bread. Forty years she's sent it up and never once climbed after it. Tell her the lid is swept, and nothing has come down.", 2],
			2: ["Edda", "Nothing come down. That's what she told me last year, and the year before. Here, take these oatcakes. Walking that hill wants feeding.", 3],
		},
		"reward": "Edda's oatcakes: vitality +15",
	},
}

var stage := {}                  # id -> int (absent = 0, not begun)
var banner_title := ""           # the Hud's banner: "Quest begun" / "Quest complete"
var banner_line := ""
var banner_t := 0.0              # s left on the banner (the Hud fades it)

func stage_of(id: String) -> int:
	return int(stage.get(id, 0))

func done(id: String) -> bool:
	return stage_of(id) >= DEFS[id]["objectives"].size() - 1

## The quest in progress (begun and not done), or "".
func active() -> String:
	for id in DEFS:
		var s := stage_of(id)
		if s > 0 and not done(id):
			return id
	return ""

func objective(id: String) -> String:
	return DEFS[id]["objectives"][stage_of(id)]

func title(id: String) -> String:
	return DEFS[id]["title"]

## What `who` says for a quest step, taking the step; "" when no quest wants a word from them.
## `ready` is false while the speaker has something to say first (Edda's introduction).
func line_for(who: String, ready := true) -> String:
	if not ready:
		return ""
	for id in DEFS:
		var step = DEFS[id]["talk"].get(stage_of(id))
		if step == null or step[0] != who:
			continue
		_advance(id, int(step[2]))
		return step[1]
	return ""

func _process(delta: float) -> void:
	banner_t = maxf(banner_t - delta, 0.0)

func _advance(id: String, to: int) -> void:
	stage[id] = to
	if to == 1:
		_banner("Quest begun: " + title(id), objective(id))
	elif done(id):
		_banner("Quest complete: " + title(id), DEFS[id]["reward"])
		_reward(id)
	changed.emit(id, to)

func _banner(t: String, l: String) -> void:
	banner_title = t
	banner_line = l
	banner_t = 6.0

func _reward(id: String) -> void:
	var p := get_parent() as Player
	if p == null:
		return
	if id == BREAD:
		p.health_max += BREAD_VIGOR
		p.health = p.health_max
