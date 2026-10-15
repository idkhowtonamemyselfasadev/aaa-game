class_name AudioMix
extends Node
## The mix: buses built at load (Master > Ambience > Wildlife, Master > SFX, Master > Music)
## so the player can set each layer on its own, plus the space the hero stands in. Inside
## the ruined keep the close sounds -- footfalls on the grit, staff swings and strikes,
## parries -- ring off the stone in a short tight reverb, and the open-air ambience (wind,
## leaves, birds) drops a little and loses its top behind the walls; out on the meadow the
## reverb fades away again. Volumes are 0..1 per bus, kept in user://settings.cfg.

const SETTINGS := "user://settings.cfg"
const BUSES := ["Master", "Music", "Ambience", "Wildlife", "SFX"]
const KEEP_R := 3.6          # keep floor radius (as Foley.surface_at)
const KEEP_FADE := 1.8       # m outside the floor over which the walls stop mattering

var world: Node3D
var volumes := {"Master": 1.0, "Music": 0.8, "Ambience": 0.9, "Wildlife": 1.0, "SFX": 1.0}
var enclosure := 0.0         # 0 open meadow .. 1 inside the keep (bots read it)

var _ruin := Vector3.INF
var _sfx_verb: AudioEffectReverb
var _amb_lp: AudioEffectLowPassFilter

func _ready() -> void:
	build_buses()
	load_settings()
	if world and world.has_node("Flora"):
		_ruin = world.get_node("Flora").ruin_site

## Idempotent: makes any missing bus, wires the sends and the space effects.
func build_buses() -> void:
	for nm: String in BUSES:
		if AudioServer.get_bus_index(nm) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, nm)
	AudioServer.set_bus_send(AudioServer.get_bus_index("Music"), "Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Ambience"), "Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Wildlife"), "Ambience")
	AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "Master")
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var v := AudioEffectReverb.new()
		v.room_size = 0.32        # a roofless stone drum ~7 m across
		v.damping = 0.45
		v.spread = 0.8
		v.predelay_msec = 12.0
		v.predelay_feedback = 0.25
		v.hipass = 0.15
		v.dry = 1.0
		v.wet = 0.0
		AudioServer.add_bus_effect(sfx, v)
	_sfx_verb = AudioServer.get_bus_effect(sfx, 0) as AudioEffectReverb
	var amb := AudioServer.get_bus_index("Ambience")
	if AudioServer.get_bus_effect_count(amb) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(amb, lp)
	_amb_lp = AudioServer.get_bus_effect(amb, 0) as AudioEffectLowPassFilter
	_apply_space()

func _process(delta: float) -> void:
	var target := 0.0
	var p := _listener()
	if _ruin != Vector3.INF and p != Vector3.INF:
		var d := Vector2(p.x - _ruin.x, p.z - _ruin.z).length()
		target = 1.0 - smoothstep(KEEP_R - 0.4, KEEP_R + KEEP_FADE, d)
		target *= 1.0 - smoothstep(4.0, 9.0, p.y - _ruin.y)   # up on the crown it opens out
	enclosure = move_toward(enclosure, target, delta * 1.5)
	_apply_space()

func _listener() -> Vector3:
	if world:
		var pl := world.get_node_or_null("Player") as Node3D
		if pl:
			return pl.global_position
	return Vector3.INF

func _apply_space() -> void:
	if _sfx_verb:
		_sfx_verb.wet = 0.3 * enclosure
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("SFX"), 0, enclosure > 0.01)
	if _amb_lp:
		_amb_lp.cutoff_hz = lerpf(20000.0, 3200.0, enclosure)
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Ambience"), 0, enclosure > 0.01)
	var amb := AudioServer.get_bus_index("Ambience")
	AudioServer.set_bus_volume_db(amb, _db(volumes["Ambience"]) - 4.0 * enclosure)

func set_volume(bus: String, v: float) -> void:
	volumes[bus] = clampf(v, 0.0, 1.0)
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, _db(volumes[bus]))
	AudioServer.set_bus_mute(i, volumes[bus] <= 0.001)
	if bus == "Ambience":
		_apply_space()

func _db(v: float) -> float:
	return linear_to_db(maxf(v, 0.0001))

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		for bus: String in volumes.keys():
			volumes[bus] = float(cf.get_value("audio", bus.to_lower(), volumes[bus]))
	for bus: String in volumes.keys():
		set_volume(bus, volumes[bus])

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS)   # keep other sections
	for bus: String in volumes.keys():
		cf.set_value("audio", bus.to_lower(), volumes[bus])
	cf.save(SETTINGS)
