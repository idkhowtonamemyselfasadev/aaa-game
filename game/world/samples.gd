class_name Samples
extends RefCounted
## Recorded CC0 / CC-BY sound files (see ASSETS.md) under res://audio/sfx/<group>/, named
## <name>_1.ogg, <name>_2.ogg ... Probed by number with ResourceLoader.exists so it works in
## an exported build too. Callers keep their synthesised stand-in when a set is missing.

const ROOT := "res://audio/sfx/"

## Every numbered variant of `name` in `group`, or [] if there is none.
static func load_set(group: String, name: String) -> Array:
	var out: Array = []
	var i := 1
	while true:
		var p := "%s%s/%s_%d.ogg" % [ROOT, group, name, i]
		if not ResourceLoader.exists(p):
			break
		var s := load(p) as AudioStream
		if s:
			out.append(s)
		i += 1
	return out

## One looping stream (an ogg with loop switched on), or null.
static func load_loop(group: String, name: String) -> AudioStream:
	var p := "%s%s/%s.ogg" % [ROOT, group, name]
	if not ResourceLoader.exists(p):
		return null
	var s := load(p) as AudioStreamOggVorbis
	if s:
		s.loop = true
	return s
