class_name Music
extends Node
## The score, on the Music bus. One looping player per cue, each with a gain eased toward its
## target so cues crossfade (equal-power, 3 s; combat comes in faster) and only one is ever
## headed for full volume:
##  - "day":    out in Harrowmere Vale by daylight, a rotation of three Alexandr Zhelanov
##              pieces (Mystical Theme, Medicine, Decision): as one nears its end the next
##              crossfades in, and the one that finished rewinds for its next turn;
##  - "night":  Without (Alexandr Zhelanov), quieter, from dusk to first light;
##  - "hearth": near Hesper's cookfire in the keep, Lazy Day (FoxSynergy): lute, flute and
##              a warm bass, a little softer after dark ("hearth_night");
##  - "combat": Battle in the Winter (Johan Brodd) the moment a Hollow Soldier stirs or the
##              hero locks on, held for HOLD s after the last enemy settles;
##  - "boss":   Steeps of Destiny (Alexandr Zhelanov) instead of the soldiers' cue while the
##              Ashen Knight is stirred. Each fight starts from the top (the slow build); when
##              the knight surges into a new phase the score drops away under the burst for
##              the surge and slams back in at a harder section of the piece (PHASE_AT), so
##              the phase change is heard as well as seen;
##  - a victory stinger, the last bars of Heroes Theme (Alexandr Zhelanov), when a fight ends
##    with an enemy crumbled; the vale cue waits under it and comes back after.
## Paused cues keep their place, so a theme picks up where it left off. While anyone's line
## is on screen the whole score ducks DUCK_DB. Bots read `cue`, `gains`, `ducked`,
## `stingers`, `fights`.

const DIR := "res://audio/music/"
const TRACKS := {
	"mystical": "vale_day_mystical_theme.ogg",
	"medicine": "vale_day_medicine.ogg",
	"decision": "vale_day_decision.ogg",
	"without": "vale_night_without.ogg",
	"battle": "combat_battle_in_the_winter.ogg",
	"lazyday": "hearth_lazy_day.ogg",
	"steeps": "boss_steeps_of_destiny.ogg",
}
const CUES := {                # cue -> [track, trim dB]; the hearth by night is the same tune, softer
	"day": ["@day", 0.0],     # resolved through DAY_ROTATION
	"night": ["without", -8.0],
	"hearth": ["lazyday", -6.0],
	"hearth_night": ["lazyday", -9.0],
	"combat": ["battle", -3.0],
	"boss": ["steeps", -2.5],
}
const PHASE_AT := [0.0, 35.4, 87.8]   # s into Steeps of Destiny each knight phase comes back in at
const CUT_GAIN := 0.22        # how far the boss cue drops while the knight surges (0..1)
const CUT_FADE := 0.3         # s to drop away; it swells back in over FADE_COMBAT
const DAY_ROTATION := [["mystical", -4.0], ["medicine", -2.5], ["decision", -5.0]]   # [track, trim dB]
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
var day_i := 0                # which DAY_ROTATION piece is the day theme now (bots)
var day_turns := 0            # how many times the day theme has handed over (bots)
var phase_cuts := 0           # knight phase changes the score answered (bots)
var boss_phase := 0           # the phase the boss cue is playing for (bots)

var _players := {}
var _stinger: AudioStreamPlayer
var _stinger_left := 0.0
var _hold := 0.0
var _fight_kills := 0
var _foes := {}               # enemy -> was it stirred last frame
var _duck := 0.0              # 0..1
var _trim := {}               # track -> dB, eased so the hearth tune just settles at dusk
var _boss_fight := false      # a boss is among the stirred enemies (held with the cue)
var _cut := 0.0               # s left of a phase cut (the score held down under a surge)
var _cut_seek := -1.0         # where the boss cue resumes when the cut ends
var _boss: Node               # the boss last seen stirred
var _start_at := {}           # track -> s to start from the next time it plays from stopped

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
	var want := _vale_cue()
	if _hold > 0.0:
		want = "boss" if _boss_fight else "combat"
	var was_fight := cue == "combat" or cue == "boss"
	var is_fight := want == "combat" or want == "boss"
	if want == "boss" and cue != "boss":
		# a fresh fight with the knight starts from the slow build, at its current phase
		var bp: AudioStreamPlayer = _players["steeps"]
		bp.stop()
		gains["steeps"] = 0.0
		_cut = 0.0
		_cut_seek = -1.0
		boss_phase = _boss.phase if _boss != null and is_instance_valid(_boss) and "phase" in _boss else 1
		_start_at["steeps"] = PHASE_AT[clampi(boss_phase - 1, 0, PHASE_AT.size() - 1)]
	if is_fight and not was_fight:
		fights += 1
		_fight_kills = 0
	elif was_fight and not is_fight and _fight_kills > 0:
		_stinger.play()
		stingers += 1
		_stinger_left = _stinger.stream.get_length()
	cue = want
	_stinger_left = maxf(_stinger_left - delta, 0.0)
	var talk := _anyone_talking()
	ducked = talk
	_duck = move_toward(_duck, 1.0 if talk else 0.0, delta / 0.6)
	_rotate_day()
	var track := track_of(cue)
	_trim[track] = move_toward(_trim[track], trim_of(cue), delta * 2.0)
	if _cut > 0.0:
		_cut = maxf(_cut - delta, 0.0)
		if _cut <= 0.0 and _cut_seek >= 0.0:
			var bp: AudioStreamPlayer = _players["steeps"]
			if bp.playing:
				bp.seek(_cut_seek)
			_cut_seek = -1.0
	for c: String in _players:
		var target := 1.0 if c == track and _stinger_left <= 0.0 else 0.0
		var rate := 1.0 / (FADE_COMBAT if cue == "combat" or cue == "boss" else FADE)   # the fight cuts in fast both ways
		if c == "steeps" and _cut > 0.0:
			target = minf(target, CUT_GAIN)
			rate = 1.0 / CUT_FADE
		gains[c] = move_toward(gains[c], target, delta * rate)
		var pl: AudioStreamPlayer = _players[c]
		var g: float = gains[c]
		if g <= 0.0:
			if pl.playing:
				if c != track_of("day") and _in_rotation(c):
					pl.stop()            # a day piece that handed over starts from the top next turn
				else:
					pl.stream_paused = true
			continue
		if not pl.playing or pl.stream_paused:
			if pl.stream_paused:
				pl.stream_paused = false
			else:
				pl.play(_start_at.get(c, 0.0))
				_start_at.erase(c)
		# equal power: the two sides of a crossfade sum to constant loudness, never both full
		pl.volume_db = linear_to_db(maxf(sin(g * PI * 0.5), 0.0001)) + _trim[c] + DUCK_DB * _duck
	_stinger.volume_db = -3.0 + DUCK_DB * _duck

func track_of(c: String) -> String:
	var t: String = CUES[c][0]
	return DAY_ROTATION[day_i][0] if t == "@day" else t

func trim_of(c: String) -> float:
	return DAY_ROTATION[day_i][1] if CUES[c][0] == "@day" else CUES[c][1]

func _in_rotation(t: String) -> bool:
	for r in DAY_ROTATION:
		if r[0] == t:
			return true
	return false

## The day theme hands over to the next piece FADE s before it would loop, so the vale by day
## runs through ~9 minutes of music before anything repeats.
func _rotate_day() -> void:
	if cue != "day":
		return
	var t := track_of("day")
	var pl: AudioStreamPlayer = _players[t]
	if gains[t] < 0.99 or not pl.playing or pl.stream_paused:
		return
	if pl.get_playback_position() >= pl.stream.get_length() - FADE - 0.25:
		day_i = (day_i + 1) % DAY_ROTATION.size()
		day_turns += 1
		_trim[track_of("day")] = trim_of("day")

## True while any living enemy near the hero has stirred (stalking, winding up, striking,
## reeling) or the hero has locked on to one. Counts the ones that crumble mid-fight.
func _fighting(_delta: float) -> bool:
	var pl := world.get_node_or_null("Player") as Node3D if world else null
	if pl == null:
		return false
	var lt = pl.get("lock_target")
	var any: bool = lt != null
	var boss := lt != null and is_instance_valid(lt) and (lt as Node).is_in_group("boss")
	for e in get_tree().get_nodes_in_group("enemy"):
		var dead: bool = e.has_method("is_dead") and e.is_dead()
		var stirred := false
		if not dead and "state" in e and e.state != HollowSoldier.IDLE:
			stirred = (e as Node3D).global_position.distance_to(pl.global_position) < NOTICE_R
		if dead and _foes.get(e, false):
			_fight_kills += 1
		_foes[e] = stirred
		any = any or stirred
		if (e as Node).is_in_group("boss"):
			if not e.is_connected("phase_changed", _on_boss_phase):
				e.phase_changed.connect(_on_boss_phase)
			if stirred:
				boss = true
				_boss = e
	if any:
		_boss_fight = boss
	return any

## The knight surged into a new phase: hold the score down under the burst, then bring it
## back in at the harder section that belongs to the phase.
func _on_boss_phase(p: int) -> void:
	if cue != "boss" or p < 2 or p == boss_phase:
		return
	boss_phase = p
	phase_cuts += 1
	_cut = AshenKnight.SURGE_T / AshenKnight.TEMPO[p - 1]
	var bp: AudioStreamPlayer = _players["steeps"]
	# never jump backwards: a long phase that already reached the section plays on
	var at: float = PHASE_AT[clampi(p - 1, 0, PHASE_AT.size() - 1)]
	_cut_seek = at if not bp.playing or bp.get_playback_position() < at else -1.0

func _vale_cue() -> String:
	var pl := world.get_node_or_null("Player") as Node3D if world else null
	var k = world.get("keeper") if world else null
	var h: float = world.time_of_day if world and "time_of_day" in world else 12.0
	var night := h < 5.5 or h >= 20.5
	if pl != null and k != null and k.hearth_at != Vector3.ZERO:
		var d := Vector2(pl.global_position.x - k.hearth_at.x, pl.global_position.z - k.hearth_at.z).length()
		if d < HEARTH_R:
			return "hearth_night" if night else "hearth"
	return "night" if night else "day"

func _anyone_talking() -> bool:
	if world == null:
		return false
	for nm in ["keeper", "villager", "neighbour", "pedlar", "traveller"]:
		var n = world.get(nm)
		if n != null and "talking" in n and n.talking > 0.0:
			return true
	return false
