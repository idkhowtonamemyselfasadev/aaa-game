class_name Music
extends Node
## The score, on the Music bus. One looping player per cue, each with a gain eased toward its
## target so cues crossfade (equal-power, 3 s; combat comes in faster) and only one is ever
## headed for full volume:
##  - "day":    Mystical Theme (Alexandr Zhelanov) out in Harrowmere Vale by daylight;
##  - "night":  Without (Alexandr Zhelanov), quieter, from dusk to first light;
##  - "hearth": near Hesper's cookfire in the keep, Without again, closer and warmer
##              (a theme of its own is still wanted, see AUDIO.md);
##  - "combat": Battle in the Winter (Johan Brodd) the moment a Hollow Soldier stirs or the
##              hero locks on, held for HOLD s after the last enemy settles;
##  - a victory stinger, the last bars of Heroes Theme (Alexandr Zhelanov), when a fight ends
##    with an enemy crumbled; the vale cue waits under it and comes back after.
## Paused cues keep their place, so a theme picks up where it left off. While anyone's line
## is on screen the whole score ducks DUCK_DB. Bots read `cue`, `gains`, `ducked`,
## `stingers`, `fights`.

const DIR := "res://audio/music/"
const TRACKS := {
	"mystical": "vale_day_mystical_theme.ogg",
	"without": "vale_night_without.ogg",
	"battle": "combat_battle_in_the_winter.ogg",
}
const CUES := {                # cue -> [track, trim dB]; hearth and night share a track
	"day": ["mystical", -4.0],
	"night": ["without", -8.0],
	"hearth": ["without", -5.0],
	"combat": ["battle", -3.0],
}
const STINGER := "victory_heroes_theme_end.ogg"
const FADE := 3.0             # s for a full crossfade between vale cues
const FADE_COMBAT := 1.6      # s for the fight to come in
const HOLD := 4.0             # s the combat cue lingers after the last enemy stands down
const NOTICE_R := 32.0        # an enemy farther than this off does not count
const HEARTH_R := 16.0        # m round Hesper's fire where the hearth cue takes over
const DUCK_DB := -6.0

var world: Node3D
var cue := ""                 # the cue now headed for full volume (bots)
var gains := {}               # track -> 0..1 (bots)
var ducked := false
var stingers := 0
var fights := 0

var _players := {}
var _stinger: AudioStreamPlayer
var _stinger_left := 0.0
var _hold := 0.0
var _fight_kills := 0
var _foes := {}               # enemy -> was it stirred last frame
var _duck := 0.0              # 0..1
var _trim := {}               # track -> dB, eased so night -> hearth just swells

func _ready() -> void:
	for c: String in TRACKS:
		var s := load(DIR + TRACKS[c]) as AudioStreamOggVorbis
		s.loop = true
		var pl := AudioStreamPlayer.new()
		pl.name = "Track_" + c
		pl.stream = s
		pl.bus = "Music"
		pl.volume_db = -80.0
		add_child(pl)
		_players[c] = pl
		gains[c] = 0.0
		_trim[c] = -6.0
	_stinger = AudioStreamPlayer.new()
	_stinger.name = "Stinger"
	var st := load(DIR + STINGER) as AudioStreamOggVorbis
	st.loop = false
	_stinger.stream = st
	_stinger.bus = "Music"
	_stinger.volume_db = -3.0
	add_child(_stinger)

func _physics_process(scaled: float) -> void:
	# fades run on the wall clock: the music does not slow down in a perfect-dodge slow-mo
	var delta := scaled / maxf(Engine.time_scale, 0.01)
	var fighting := _fighting(delta)
	if fighting:
		_hold = HOLD
	else:
		_hold = maxf(_hold - delta, 0.0)
	var want := "combat" if _hold > 0.0 else _vale_cue()
	if want == "combat" and cue != "combat":
		fights += 1
		_fight_kills = 0
	elif cue == "combat" and want != "combat" and _fight_kills > 0:
		_stinger.play()
		stingers += 1
		_stinger_left = _stinger.stream.get_length()
	cue = want
	_stinger_left = maxf(_stinger_left - delta, 0.0)
	var talk := _anyone_talking()
	ducked = talk
	_duck = move_toward(_duck, 1.0 if talk else 0.0, delta / 0.6)
	var track: String = CUES[cue][0]
	_trim[track] = move_toward(_trim[track], CUES[cue][1], delta * 2.0)
	for c: String in _players:
		var target := 1.0 if c == track and _stinger_left <= 0.0 else 0.0
		var rate := 1.0 / (FADE_COMBAT if cue == "combat" else FADE)   # the fight cuts in fast both ways
		gains[c] = move_toward(gains[c], target, delta * rate)
		var pl: AudioStreamPlayer = _players[c]
		var g: float = gains[c]
		if g <= 0.0:
			if pl.playing:
				pl.stream_paused = true
			continue
		if not pl.playing or pl.stream_paused:
			if pl.stream_paused:
				pl.stream_paused = false
			else:
				pl.play()
		# equal power: the two sides of a crossfade sum to constant loudness, never both full
		pl.volume_db = linear_to_db(maxf(sin(g * PI * 0.5), 0.0001)) + _trim[c] + DUCK_DB * _duck
	_stinger.volume_db = -3.0 + DUCK_DB * _duck

## True while any living enemy near the hero has stirred (stalking, winding up, striking,
## reeling) or the hero has locked on to one. Counts the ones that crumble mid-fight.
func _fighting(_delta: float) -> bool:
	var pl := world.get_node_or_null("Player") as Node3D if world else null
	if pl == null:
		return false
	var any: bool = "lock_target" in pl and pl.lock_target != null
	for e in get_tree().get_nodes_in_group("enemy"):
		var dead: bool = e.has_method("is_dead") and e.is_dead()
		var stirred := false
		if not dead and "state" in e and e.state != HollowSoldier.IDLE:
			stirred = (e as Node3D).global_position.distance_to(pl.global_position) < NOTICE_R
		if dead and _foes.get(e, false):
			_fight_kills += 1
		_foes[e] = stirred
		any = any or stirred
	return any

func _vale_cue() -> String:
	var pl := world.get_node_or_null("Player") as Node3D if world else null
	var k = world.get("keeper") if world else null
	if pl != null and k != null and k.hearth_at != Vector3.ZERO:
		var d := Vector2(pl.global_position.x - k.hearth_at.x, pl.global_position.z - k.hearth_at.z).length()
		if d < HEARTH_R:
			return "hearth"
	var h: float = world.time_of_day if world and "time_of_day" in world else 12.0
	return "night" if h < 5.5 or h >= 20.5 else "day"

func _anyone_talking() -> bool:
	if world == null:
		return false
	for nm in ["keeper", "villager", "neighbour", "pedlar", "traveller"]:
		var n = world.get(nm)
		if n != null and "talking" in n and n.talking > 0.0:
			return true
	return false
