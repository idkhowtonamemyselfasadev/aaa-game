class_name GraphicsQuality
extends Node
## The picture settings: one quality preset (Low, Medium, High, Ultra) that scales the costly
## passes instead of cutting the look, and a render-scale slider that upscales with FSR 2
## below 100 %. High (the default) is the look the slice is tuned in: SDFGI with 4 cascades,
## SSAO/SSIL, SSR, 4K sun shadows. Ultra adds full-res SSAO/SSIL, the finest soft-shadow
## filter and a denser volumetric froxel grid for a 4070-class card; Low keeps the fog, shadows and grade but drops
## GI to the bounce fill, halves the shadow map and the froxel grid. Kept in
## user://settings.cfg [graphics] next to the sound.

const SETTINGS := "user://settings.cfg"
const NAMES := ["Low", "Medium", "High", "Ultra"]
# per preset: sdfgi cascades (0 = off), ssao/ssil/ssr, ssao quality, shadow map, soft filter,
# froxel grid (xy, depth), mesh LOD threshold (px)
const PRESETS := [
	{"sdfgi": 0, "ssao": true, "ssil": false, "ssr": false, "ssao_q": 1, "shadow": 2048, "soft": 1, "fog_xy": 48, "fog_z": 48, "lod": 4.0},
	{"sdfgi": 3, "ssao": true, "ssil": false, "ssr": true, "ssao_q": 1, "shadow": 2048, "soft": 2, "fog_xy": 64, "fog_z": 64, "lod": 2.0},
	{"sdfgi": 4, "ssao": true, "ssil": true, "ssr": true, "ssao_q": 2, "shadow": 4096, "soft": 3, "fog_xy": 64, "fog_z": 64, "lod": 1.0},
	{"sdfgi": 4, "ssao": true, "ssil": true, "ssr": true, "ssao_q": 3, "shadow": 4096, "soft": 4, "fog_xy": 96, "fog_z": 128, "lod": 0.75},
]

var world: Node3D
var level := 2               # index into PRESETS (bots read it)
var render_scale := 1.0      # 0.5..1.0; below 1 the 3D view upscales with FSR 2

func _ready() -> void:
	load_settings()

func set_level(l: int) -> void:
	level = clampi(l, 0, PRESETS.size() - 1)
	apply()

func set_render_scale(s: float) -> void:
	render_scale = clampf(s, 0.5, 1.0)
	apply()

## Software Vulkan (the cloud screenshot box) renders SDFGI black in the shade, so GI stays
## off there whatever the preset; real GPUs follow it.
func gi_supported() -> bool:
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	return not (adapter.contains("llvmpipe") or adapter.contains("lavapipe"))

func apply() -> void:
	var p: Dictionary = PRESETS[level]
	var we := world.get_node_or_null("WorldEnvironment") as WorldEnvironment if world else null
	if we and we.environment:
		var e := we.environment
		var allowed: bool = world.get("sdfgi_allowed") != false
		e.sdfgi_enabled = p.sdfgi > 0 and allowed and gi_supported()
		if p.sdfgi > 0:
			e.sdfgi_cascades = p.sdfgi
		e.ssao_enabled = p.ssao
		e.ssil_enabled = p.ssil
		e.ssr_enabled = p.ssr
		e.ssr_max_steps = 64 if level >= 2 else 32
	RenderingServer.environment_set_ssao_quality(p.ssao_q, level < 3, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(p.ssao_q, level < 3, 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(p.fog_xy, p.fog_z)
	RenderingServer.environment_set_sdfgi_ray_count(
		RenderingServer.ENV_SDFGI_RAY_COUNT_64 if level >= 3 else RenderingServer.ENV_SDFGI_RAY_COUNT_32)
	RenderingServer.directional_shadow_atlas_set_size(p.shadow, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(p.soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(p.soft)
	var vp := get_viewport() if is_inside_tree() else null
	if vp:
		vp.mesh_lod_threshold = p.lod
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if render_scale < 0.995 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = render_scale
		vp.use_taa = render_scale >= 0.995   # FSR 2 does its own temporal AA

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		level = clampi(int(cf.get_value("graphics", "quality", level)), 0, PRESETS.size() - 1)
		render_scale = clampf(float(cf.get_value("graphics", "render_scale", render_scale)), 0.5, 1.0)
	apply()

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS)   # keep other sections
	cf.set_value("graphics", "quality", level)
	cf.set_value("graphics", "render_scale", render_scale)
	cf.save(SETTINGS)
