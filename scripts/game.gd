extends Node3D
## Head Bus: drive a double-decker along an endless two-lane road (traffic keeps
## left). Your lane is x = -1.75 (same-direction traffic), the oncoming lane is
## x = +1.75, petrol-station slip roads open up on the left. The bus always moves
## forward (-Z); the player only steers. Money is earned faster the faster you go.

const LANE_OURS := -1.75
const LANE_ONC := 1.75
const BUS_HX := 1.25
const BUS_HZ := 5.25
const ROAD_LIMIT := 2.3
const STATION_X := -7.7
const STATION_LEN := 120.0
const STATION_SPEED := 0.5
## Looking fully up adds this fraction of cruise speed; fully down removes this much.
const MAX_BOOST := 0.4
const MAX_SLOW := 0.6
const C_TO_X := 3.5
const CHUNK := 40.0
const SAVE_PATH := "user://save.cfg"
const UPGRADE_COSTS := [60, 150, 320, 650, 1100]
const UPGRADES := {
	"steer": {"name": "Power Steering", "desc": "Your bus slides sideways faster.", "max": 5},
	"armour": {"name": "Bull Bars", "desc": "Survive one more crash.", "max": 4},
	"fare": {"name": "Fare Box", "desc": "+20% money from everything.", "max": 5},
	"magnet": {"name": "Coin Magnet", "desc": "Grab coins from further away.", "max": 4},
}
const CAR_TYPES := ["sedan", "sedan", "hatch", "hatch", "suv", "van", "taxi", "truck"]

enum State { MENU, COUNTDOWN, PLAYING, PAUSED, OVER }
enum Kind { CAR, BLOCK, CONE, POTHOLE, COIN }


class Ent:
	var node: Node3D
	var kind: int
	var hx: float
	var hz: float
	## -1 drives away from the camera (your direction), +1 oncoming, 0 parked.
	var dir := 0
	var base_speed := 0.0
	var speed := 0.0
	var hit := false
	var passed := false
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var life := 0.0


var state := State.MENU
var save := {
	"money": 0, "best": 0, "mode": SteerInput.Mode.KEYS, "sens": 1.0, "flip": false,
	"up": {"steer": 0, "armour": 0, "fare": 0, "magnet": 0},
}
var steer := SteerInput.new()
var rng := RandomNumberGenerator.new()
var ui: GameUI
var sfx: Sfx
var cam: Camera3D
var bus: Node3D
var bus_mesh: MeshInstance3D
var ground: MeshInstance3D
var ents: Array[Ent] = []
var chunks := {}
## Active petrol stations: {"z0": entry z, "node": Node3D}.
var stations: Array[Dictionary] = []
var mobile := false

var spd := 0.0
var cruise := 14.0
var dist := 0.0
var run_money := 0.0
var level := 1
var hp := 2
var hp_max := 2
var invuln := 0.0
var target_x := LANE_OURS
var lat_vel := 0.0
var shake := 0.0
var bump := 0.0
var combo := 0
var combo_t := 0.0
var near_misses := 0
var coins := 0
var countdown_t := 0.0
var sensor_wait := 0.0
var run_mode := SteerInput.Mode.KEYS
var next_same_z := 0.0
var next_onc_t := 0.0
var next_obs_z := 0.0
var next_coin_z := 0.0
var next_station_z := 0.0
var touch_active := false
var touch_c := 0.0
var keys_held := false
var cam_x := LANE_OURS


func _ready() -> void:
	rng.randomize()
	mobile = OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
	if mobile:
		save.mode = SteerInput.Mode.TILT
	_load()
	_build_world()
	sfx = Sfx.new()
	add_child(sfx)
	ui = GameUI.new()
	add_child(ui)
	for id in UPGRADES:
		ui.add_upgrade_row(id, UPGRADES[id].name, UPGRADES[id].desc)
	ui.play_pressed.connect(_start_run)
	ui.retry_pressed.connect(_start_run)
	ui.garage_pressed.connect(_to_menu)
	ui.buy_pressed.connect(_buy)
	ui.mode_selected.connect(_select_mode)
	ui.sens_changed.connect(func(v): save.sens = v; steer.sens = v; _save())
	ui.flip_changed.connect(func(v): save.flip = v; steer.flip = v; _save())
	ui.pause_pressed.connect(_toggle_pause)
	ui.resume_pressed.connect(_toggle_pause)
	ui.recalibrate_pressed.connect(func(): steer.calibrate(); ui.popup("Centred", GameUI.GOOD))
	steer.sens = save.sens
	steer.flip = save.flip
	_select_mode(int(save.mode))
	get_window().size_changed.connect(_fit_window)
	_fit_window()
	_to_menu()


# --- World setup ------------------------------------------------------------

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color("3f86d6")
	psm.sky_horizon_color = Color("cfe6f5")
	psm.ground_horizon_color = Color("cfe6f5")
	psm.ground_bottom_color = Color("6a8f5a")
	sky.sky_material = psm
	env.sky = sky
	# Sky ambient is far too bright in the Compatibility renderer; a flat colour reads better.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.6)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("cfe6f5")
	env.fog_depth_begin = 90.0
	env.fog_depth_end = 280.0
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = not mobile
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)

	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("78ad55")
	gm.roughness = 1.0
	pm.material = gm
	ground.mesh = pm
	ground.position.y = -0.03
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	bus = Node3D.new()
	add_child(bus)
	bus_mesh = MeshInstance3D.new()
	bus_mesh.mesh = Models.mesh("bus")
	bus.add_child(bus_mesh)
	for side in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = "HEAD BUS"
		l.font_size = 64
		l.outline_size = 0
		l.modulate = Color("f1e3c4")
		l.pixel_size = 0.006
		l.position = Vector3(side * 1.27, 0.95, 0.6)
		l.rotation_degrees.y = 90.0 * side
		bus_mesh.add_child(l)

	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 500.0
	add_child(cam)
	cam.make_current()


func _reset_world() -> void:
	for e in ents:
		e.node.queue_free()
	ents.clear()
	for s in stations:
		(s.node as Node3D).queue_free()
	stations.clear()
	for i in chunks:
		(chunks[i] as Node3D).queue_free()
	chunks.clear()
	bus.position = Vector3(LANE_OURS, 0, 0)
	bus_mesh.rotation = Vector3.ZERO
	bus_mesh.visible = true
	target_x = LANE_OURS
	cam_x = LANE_OURS
	next_same_z = -45.0
	next_onc_t = 1.5
	next_obs_z = -260.0
	next_coin_z = -60.0
	next_station_z = -380.0
	_update_stations()
	_update_chunks()


# --- Flow -------------------------------------------------------------------

func _to_menu() -> void:
	state = State.MENU
	_reset_world()
	spd = 9.0
	ui.show_screen("menu")
	ui.refresh_menu(save, UPGRADES, UPGRADE_COSTS)
	steer.set_preview(steer.mode == SteerInput.Mode.HEAD)


func _select_mode(m: int) -> void:
	save.mode = m
	steer.mode = m as SteerInput.Mode
	steer.start()
	_save()
	if ui:
		ui.refresh_menu(save, UPGRADES, UPGRADE_COSTS)


func _start_run() -> void:
	_reset_world()
	state = State.COUNTDOWN
	run_mode = int(save.mode)
	steer.mode = run_mode as SteerInput.Mode
	steer.start()
	countdown_t = 3.0
	sensor_wait = 0.0
	spd = 0.0
	dist = 0.0
	run_money = 0.0
	level = 1
	cruise = _cruise_for(1)
	hp_max = 2 + int(save.up.armour)
	hp = hp_max
	invuln = 0.0
	combo = 0
	near_misses = 0
	coins = 0
	touch_active = false
	ui.show_screen("hud")
	ui.show_recalibrate(steer.uses_sensor())
	ui.set_hint("")
	ui.set_status("")
	sfx.engine(0.0)


func _toggle_pause() -> void:
	if state == State.PLAYING or state == State.COUNTDOWN:
		state = State.PAUSED
		ui.show_screen("pause")
		sfx.engine(-1.0)
	elif state == State.PAUSED:
		state = State.COUNTDOWN
		countdown_t = 2.0
		ui.show_screen("hud")


func _game_over() -> void:
	state = State.OVER
	bus_mesh.visible = true
	var earned := int(run_money)
	save.money = int(save.money) + earned
	var record := dist > float(save.best)
	if record:
		save.best = int(dist)
	_save()
	sfx.engine(-1.0)
	ui.set_hint("")
	ui.set_status("")
	ui.set_countdown("")
	ui.set_hud(run_money, dist, level, 0.0, maxi(hp, 0), hp_max)
	ui.speed_lbl.modulate = Color.WHITE
	ui.show_over("NEW RECORD!" if record else "CRASHED!",
		"%d m   ·   Level %d\nEarned $%d\n%d close calls   ·   %d coins\nBest %d m   ·   Bank $%d"
		% [int(dist), level, earned, near_misses, coins, int(save.best), int(save.money)])


func _buy(id: String) -> void:
	var lvl: int = save.up[id]
	if lvl >= UPGRADES[id].max or int(save.money) < UPGRADE_COSTS[lvl]:
		return
	save.money = int(save.money) - UPGRADE_COSTS[lvl]
	save.up[id] = lvl + 1
	_save()
	sfx.play("level")
	ui.refresh_menu(save, UPGRADES, UPGRADE_COSTS)


# --- Frame update -----------------------------------------------------------

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	match state:
		State.MENU:
			_menu_update(dt)
		State.COUNTDOWN:
			_countdown_update(dt)
		State.PLAYING:
			_play_update(dt)
		State.OVER:
			spd = move_toward(spd, 0.0, 12.0 * dt)
			bus.position.z -= spd * dt
			_update_ents(dt, false)
	if state != State.PAUSED:
		_update_chunks()
		_update_camera(dt)


func _menu_update(dt: float) -> void:
	bus.position.z -= spd * dt
	bus.position.x = move_toward(bus.position.x, LANE_OURS, 2.0 * dt)
	next_onc_t -= dt
	if next_onc_t <= 0.0:
		_spawn_oncoming()
		next_onc_t = rng.randf_range(2.0, 4.0)
	_update_stations()
	_update_ents(dt, false)
	ui.set_sensor_message(steer.message(), steer.state() == "ready")


func _countdown_update(dt: float) -> void:
	_update_ents(dt, false)
	var st := steer.state()
	if steer.uses_sensor() and st != "ready":
		sensor_wait += dt
		var msg := steer.message()
		if st == "error" or sensor_wait > 12.0:
			# Fall back to keys/touch so the run can still be played.
			steer.mode = SteerInput.Mode.KEYS
			ui.popup("Using keys / touch", GameUI.ACCENT)
			ui.set_status(msg)
			ui.show_recalibrate(false)
		else:
			ui.set_countdown(msg)
		return
	countdown_t -= dt
	var prompt := ""
	if steer.mode == SteerInput.Mode.HEAD:
		prompt = "Look straight at the screen\n"
	elif steer.mode == SteerInput.Mode.TILT:
		prompt = "Hold your device level\n"
	ui.set_countdown(prompt + str(ceili(countdown_t)))
	ui.set_bar(steer.control(), _bus_c(), false)
	if countdown_t <= 0.0:
		steer.calibrate()
		target_x = bus.position.x
		state = State.PLAYING
		ui.set_countdown("")
		ui.popup("GO!", GameUI.GOOD)


func _play_update(dt: float) -> void:
	invuln = maxf(invuln - dt, 0.0)
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	var new_level := 1 + int(dist / 450.0)
	if new_level != level:
		level = new_level
		cruise = _cruise_for(level)
		ui.popup("LEVEL %d" % level, GameUI.ACCENT)
		sfx.play("level")

	# Steering: the bus chases the target position, capped at the steering speed,
	# so slow head movement gives a slow drift and fast movement a quick swerve.
	var ctrl := steer.control()
	var bx := bus.position.x
	var kdir := int(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) \
		- int(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
	if kdir != 0:
		target_x = bx + kdir * 3.0
		keys_held = true
	elif keys_held:
		target_x = bx
		keys_held = false
	elif touch_active:
		target_x = LANE_OURS + touch_c * C_TO_X
	elif not is_nan(ctrl):
		target_x = LANE_OURS + ctrl * C_TO_X
	var lim_l := _left_limit(bus.position.z - 2.0)
	var steer_speed := 5.0 + int(save.up.steer) * 1.2
	var nx := move_toward(bx, clampf(target_x, lim_l, ROAD_LIMIT), steer_speed * dt)
	nx = maxf(nx, lim_l)
	lat_vel = lerpf(lat_vel, (nx - bx) / dt, 10.0 * dt)
	bus.position.x = nx

	# Speed: look up to speed up (to 140% of cruise), down to slow (to 40%);
	# up/down keys do the same. Capped in the petrol station, brake behind traffic.
	var thr := steer.throttle()
	var kthr := int(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)) \
		- int(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S))
	if kthr != 0:
		thr = kthr
	elif is_nan(thr):
		thr = 0.0
	var desired := cruise * (1.0 + thr * (MAX_BOOST if thr > 0.0 else MAX_SLOW))
	var in_station := nx < -3.7
	if in_station:
		desired = minf(desired, cruise * STATION_SPEED)
	for e in ents:
		if e.hit or e.dir != -1:
			continue
		var ex := e.node.position.x
		if absf(ex - nx) > e.hx + BUS_HX - 0.25:
			continue
		var gap := (bus.position.z - BUS_HZ) - (e.node.position.z + e.hz)
		if gap < -1.0 or gap > 8.0 + spd * 0.7:
			continue
		desired = minf(desired, e.speed + maxf(gap - 3.0, 0.0) * 0.9)
	spd = move_toward(spd, maxf(desired, 0.0), (16.0 if desired < spd else 5.0) * dt)
	bus.position.z -= spd * dt
	dist += spd * dt
	run_money += 0.0025 * spd * spd * dt * _fare()
	ui.speed_lbl.modulate = GameUI.GOOD if thr > 0.05 else (GameUI.ACCENT if thr < -0.05 else Color.WHITE)

	_update_stations()
	_spawn_traffic(dt)
	_update_ents(dt, true)
	if state != State.PLAYING:
		return

	# Hit flash and road bumps.
	bus_mesh.visible = invuln <= 0.0 or fmod(invuln, 0.2) < 0.12
	bump = move_toward(bump, 0.0, dt)
	sfx.engine(spd / 30.0)

	var station_open := lim_l < -ROAD_LIMIT - 0.1
	var hint := ""
	if in_station:
		hint = "PETROL STATION - half speed, half the fares"
	elif station_open:
		hint = "Lean LEFT to pull into the petrol station"
	else:
		for s in stations:
			var ahead: float = bus.position.z - float(s.z0)
			if ahead > 0.0 and ahead < 180.0:
				hint = "Petrol station ahead - skip the traffic"
	ui.set_hint(hint)
	var status := ""
	if steer.uses_sensor() and steer.state() != "ready":
		status = steer.message()
	ui.set_status(status)
	ui.set_hud(run_money, dist, level, spd * 3.6, hp, hp_max)
	ui.set_bar(ctrl if not touch_active else touch_c, _bus_c(), station_open)


## Portrait screens get a portrait base resolution so the UI stays readable.
func _fit_window() -> void:
	var s := get_window().size
	get_window().content_scale_size = Vector2i(720, 1280) if s.y > s.x else Vector2i(1280, 720)


func _bus_c() -> float:
	return (bus.position.x - LANE_OURS) / C_TO_X


func _cruise_for(lvl: int) -> float:
	return minf(14.0 + (lvl - 1) * 1.8, 32.0)


func _fare() -> float:
	return 1.0 + 0.2 * int(save.up.fare)


func _density() -> float:
	return maxf(0.42, 1.0 - (level - 1) * 0.07)


## Leftmost x the bus centre may reach at z (wider beside a petrol station).
func _left_limit(z: float) -> float:
	for s in stations:
		var d: float = float(s.z0) - z
		if d < 0.0 or d > STATION_LEN:
			continue
		if d < 20.0:
			return lerpf(-ROAD_LIMIT, STATION_X, d / 20.0)
		if d < 100.0:
			return STATION_X
		return lerpf(STATION_X, -ROAD_LIMIT, (d - 100.0) / 20.0)
	return -ROAD_LIMIT


func _update_camera(dt: float) -> void:
	var aspect := get_viewport().get_visible_rect().size.aspect()
	# Keep roughly 60 degrees of horizontal view, so portrait phones still see both lanes.
	cam.fov = clampf(rad_to_deg(2.0 * atan(tan(deg_to_rad(30.0)) / aspect)), 62.0, 100.0)
	cam_x = lerpf(cam_x, bus.position.x, 4.0 * dt)
	shake = move_toward(shake, 0.0, dt * 1.8)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.35
	var bz := bus.position.z
	cam.position = Vector3(cam_x * 0.75, 9.6 + bump * 0.4, bz + 14.5) + jitter
	cam.look_at(Vector3(cam_x * 0.85, 0.0, bz - 24.0))
	bus_mesh.rotation.y = -lat_vel * 0.035
	bus_mesh.rotation.z = -lat_vel * 0.012
	bus_mesh.position.y = absf(sin(bump * 30.0)) * bump * 0.5


# --- Spawning ---------------------------------------------------------------

func _spawn_traffic(dt: float) -> void:
	var bz := bus.position.z
	while next_same_z > bz - 210.0:
		_spawn_same(next_same_z)
		next_same_z -= rng.randf_range(55.0, 100.0) * _density()
	next_onc_t -= dt
	if next_onc_t <= 0.0:
		_spawn_oncoming()
		next_onc_t = rng.randf_range(1.3, 3.4) * _density()
	while next_obs_z > bz - 200.0:
		if level >= 2:
			_spawn_obstacle(next_obs_z)
		next_obs_z -= rng.randf_range(110.0, 200.0) * _density()
	while next_coin_z > bz - 190.0:
		_spawn_coins(next_coin_z)
		next_coin_z -= rng.randf_range(70.0, 130.0)


func _new_ent(kind: int, key: String, pos: Vector3, half: Vector2, dir := 0, speed := 0.0) -> Ent:
	var e := Ent.new()
	var mi := MeshInstance3D.new()
	mi.mesh = Models.mesh(key)
	mi.position = pos
	if dir == 1:
		mi.rotation.y = PI
	if kind == Kind.POTHOLE or kind == Kind.COIN:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	e.node = mi
	e.kind = kind
	e.hx = half.x
	e.hz = half.y
	e.dir = dir
	e.base_speed = speed
	e.speed = speed
	ents.append(e)
	return e


func _lane_clear(x: float, z: float, room: float) -> bool:
	for e in ents:
		if e.hit or e.kind == Kind.COIN:
			continue
		if absf(e.node.position.x - x) < 2.2 and absf(e.node.position.z - z) < room + e.hz:
			return false
	return true


func _car_key(type: String) -> String:
	return "car:%s:%d" % [type, rng.randi_range(0, Models.CAR_COLOURS.size() - 1)]


func _pick_type() -> String:
	var t: String = CAR_TYPES[rng.randi_range(0, CAR_TYPES.size() - 1)]
	if level >= 3 and rng.randf() < 0.15:
		t = "truck"
	return t


func _spawn_same(z: float) -> void:
	var x := LANE_OURS + rng.randf_range(-0.2, 0.2)
	if not _lane_clear(x, z, 14.0):
		return
	var t := _pick_type()
	var speed := cruise * rng.randf_range(0.45, 0.72)
	if t == "truck":
		speed = cruise * 0.42
	_new_ent(Kind.CAR, _car_key(t), Vector3(x, 0, z), Models.CAR_SIZE[t], -1, speed)


func _spawn_oncoming() -> void:
	var z := bus.position.z - 240.0
	var x := LANE_ONC + rng.randf_range(-0.2, 0.2)
	if not _lane_clear(x, z, 16.0):
		return
	var t := _pick_type()
	var speed := rng.randf_range(11.0, 16.0) + level * 0.6
	_new_ent(Kind.CAR, _car_key(t), Vector3(x, 0, z), Models.CAR_SIZE[t], 1, speed)


func _spawn_obstacle(z: float) -> void:
	var ours := rng.randf() < 0.65
	var lane := LANE_OURS if ours else LANE_ONC
	# Toward the bus is +Z for your lane; oncoming traffic approaches from -Z.
	var toward := 1.0 if ours else -1.0
	if not _lane_clear(lane, z, 20.0):
		return
	var roll := rng.randi_range(0, mini(level, 5))
	match roll:
		0, 1:
			for i in 4:
				var cx := lane + (-1.3 + i * 0.8) * toward
				_new_ent(Kind.CONE, "cone", Vector3(cx, 0, z + i * 3.0 * toward), Vector2(0.25, 0.25))
		2:
			var px := rng.randf_range(-2.4, 2.4)
			_new_ent(Kind.POTHOLE, "pothole", Vector3(px, 0, z), Vector2(0.6, 0.7))
		3, 4:
			_spawn_roadworks(lane, z, toward)
		_:
			var t := rng.randi_range(0, Models.CAR_COLOURS.size() - 1)
			var car := _new_ent(Kind.BLOCK, "broken:%d" % t, Vector3(lane, 0, z), Models.CAR_SIZE.sedan)
			if not ours:
				car.node.rotation.y = PI
			_new_ent(Kind.CONE, "triangle", Vector3(lane, 0, z + 9.0 * toward), Vector2(0.35, 0.2))


func _spawn_roadworks(lane: float, z: float, toward: float) -> void:
	var b := _new_ent(Kind.BLOCK, "barrier", Vector3(lane, 0, z), Vector2(1.45, 0.35))
	if toward < 0.0:
		b.node.rotation.y = PI
	for i in 3:
		_new_ent(Kind.CONE, "cone", Vector3(lane - 1.2 + i * 1.2, 0, z + (3.0 + i * 1.5) * toward), Vector2(0.25, 0.25))


func _spawn_coins(z: float) -> void:
	var pattern := rng.randi_range(0, 2)
	var x0 := LANE_OURS if rng.randf() < 0.6 else LANE_ONC
	for i in 6:
		var x := x0
		if pattern == 1:
			x = lerpf(LANE_OURS, LANE_ONC, i / 5.0)
		elif pattern == 2:
			x = lerpf(LANE_ONC, LANE_OURS, i / 5.0)
		var e := _new_ent(Kind.COIN, "coin", Vector3(x, 1.2, z - i * 4.0), Vector2(0.5, 0.5))
		e.node.rotation.y = i * 0.4


func _update_stations() -> void:
	var bz := bus.position.z
	# Placed beyond the scenery horizon so chunks never put props on the forecourt.
	if next_station_z > bz - 400.0:
		var node := MeshInstance3D.new()
		node.mesh = Models.mesh("station")
		node.position.z = next_station_z
		add_child(node)
		var fuel := Label3D.new()
		fuel.text = "FUEL"
		fuel.font_size = 96
		fuel.pixel_size = 0.01
		fuel.position = Vector3(-11.5, 8.35, -7.8)
		node.add_child(fuel)
		var name_l := Label3D.new()
		name_l.text = "PETROL  ·  SHOP"
		name_l.font_size = 80
		name_l.pixel_size = 0.0045
		name_l.position = Vector3(-10.4, 5.6, -36.9)
		node.add_child(name_l)
		stations.append({"z0": next_station_z, "node": node})
		# Often the main road is blocked alongside, so the slip road pays off.
		if state == State.PLAYING and level >= 2 and rng.randf() < 0.6 and _lane_clear(LANE_OURS, next_station_z - 70.0, 20.0):
			_spawn_roadworks(LANE_OURS, next_station_z - 70.0, 1.0)
		next_station_z -= rng.randf_range(650.0, 1000.0)
	for s in stations.duplicate():
		if float(s.z0) - STATION_LEN - 40.0 > bz:
			(s.node as Node3D).queue_free()
			stations.erase(s)


# --- Entities ---------------------------------------------------------------

func _update_ents(dt: float, collide: bool) -> void:
	var bx := bus.position.x
	var bz := bus.position.z
	var magnet := 0.6 + int(save.up.magnet) * 1.4
	var keep: Array[Ent] = []
	for e in ents:
		var p := e.node.position
		if e.hit:
			if e.kind != Kind.POTHOLE:
				e.life -= dt
				e.vel.y -= 22.0 * dt
				p += e.vel * dt
				if p.y < 0.0:
					p.y = 0.0
					e.vel *= Vector3(0.6, -0.3, 0.6)
				e.node.position = p
				e.node.rotation += e.spin * dt
			if e.life > 0.0 or (e.kind == Kind.POTHOLE and p.z < bz + 30.0):
				keep.append(e)
			else:
				e.node.queue_free()
			continue
		if e.dir != 0:
			_drive(e, dt, bx, bz)
			p = e.node.position
		if e.kind == Kind.COIN:
			e.node.rotation.y += 3.0 * dt
		if p.z > bz + 30.0 or p.z < bz - 420.0:
			e.node.queue_free()
			continue
		keep.append(e)
		if not collide:
			continue
		var dx := absf(p.x - bx)
		var dz := absf(p.z - bz)
		if e.kind == Kind.COIN:
			if dx < BUS_HX + magnet and dz < BUS_HZ + magnet:
				_collect(e)
			continue
		if dx < e.hx + BUS_HX - 0.05 and dz < e.hz + BUS_HZ - 0.1:
			_collide(e)
			if state != State.PLAYING:
				collide = false
			continue
		if not e.passed and p.z > bz and (e.kind == Kind.CAR or e.kind == Kind.BLOCK):
			e.passed = true
			var gap := dx - e.hx - BUS_HX
			if gap < 0.9:
				_near_miss()
	ents = keep


## Moves a vehicle along its lane, braking for whatever is ahead of it.
func _drive(e: Ent, dt: float, bx: float, bz: float) -> void:
	var p := e.node.position
	var lead_gap := INF
	var lead_speed := 0.0
	for o in ents:
		if o == e or o.hit or o.kind == Kind.COIN or o.kind == Kind.POTHOLE or o.dir == -e.dir:
			continue
		var op := o.node.position
		if absf(op.x - p.x) > 1.6:
			continue
		var ahead := (op.z - p.z) * e.dir
		if ahead <= 0.0:
			continue
		var gap := ahead - o.hz - e.hz
		if gap < lead_gap:
			lead_gap = gap
			lead_speed = o.speed if o.dir == e.dir else 0.0
	if e.dir == -1 and bz < p.z and absf(bx - p.x) < BUS_HX + e.hx:
		var gap := p.z - bz - BUS_HZ - e.hz
		if gap < lead_gap:
			lead_gap = gap
			lead_speed = spd
	var target := e.base_speed
	if lead_gap < 25.0:
		target = minf(target, lead_speed + maxf(lead_gap - 3.5, 0.0) * 0.8)
	e.speed = move_toward(e.speed, maxf(target, 0.0), 12.0 * dt)
	p.z += e.dir * e.speed * dt
	e.node.position = p


func _collect(e: Ent) -> void:
	e.hit = true
	e.life = 0.35
	e.vel = Vector3((bus.position.x - e.node.position.x) * 3.0, 9.0, -spd)
	coins += 1
	run_money += 3.0 * _fare()
	sfx.play("coin", 1.0 + minf(combo, 6) * 0.05)


func _near_miss() -> void:
	combo = combo + 1 if combo_t > 0.0 else 1
	combo_t = 3.0
	near_misses += 1
	var bonus := 2.0 * combo * _fare()
	run_money += bonus
	ui.popup("CLOSE CALL! +$%d%s" % [int(bonus), (" x%d" % combo) if combo > 1 else ""], GameUI.ACCENT)
	sfx.play("near", 0.9 + minf(combo, 5) * 0.08)


func _knock(e: Ent, power: float) -> void:
	var side := signf(e.node.position.x - bus.position.x)
	if side == 0.0:
		side = 1.0
	e.hit = true
	e.life = 2.5
	e.vel = Vector3(side * rng.randf_range(3.0, 6.0) * power, rng.randf_range(4.0, 7.0) * power, -spd * 1.1)
	e.spin = Vector3(rng.randf_range(-6, 6), rng.randf_range(-8, 8), rng.randf_range(-6, 6)) * power


func _collide(e: Ent) -> void:
	match e.kind:
		Kind.CONE:
			_knock(e, 1.0)
			spd *= 0.85
			shake = maxf(shake, 0.25)
			sfx.play("thud", 1.4)
			ui.popup("CONE!", Color("ff9a3c"))
		Kind.POTHOLE:
			e.hit = true
			spd *= 0.75
			shake = maxf(shake, 0.5)
			bump = 0.4
			sfx.play("thud", 0.7)
			ui.popup("POTHOLE!", Color("ff9a3c"))
		_:
			if invuln > 0.0:
				return
			hp -= 1
			invuln = 2.0
			shake = 1.0
			spd *= 0.45
			combo = 0
			_knock(e, 0.5)
			e.vel.z = -spd * 1.5 if e.dir <= 0 else e.speed * 0.3
			sfx.play("crash")
			if hp <= 0:
				_game_over()
			else:
				ui.popup("CRASH!  %d left" % hp, GameUI.BAD)


# --- Scenery ----------------------------------------------------------------

func _update_chunks() -> void:
	var bz := bus.position.z
	ground.position.x = bus.position.x
	ground.position.z = bz
	var first := int(floor((-bz - 60.0) / CHUNK))
	var last := int(floor((-bz + 300.0) / CHUNK))
	for i in chunks.keys():
		if i < first or i > last:
			(chunks[i] as Node3D).queue_free()
			chunks.erase(i)
	for i in range(first, last + 1):
		if not chunks.has(i):
			chunks[i] = _make_chunk(i)


func _make_chunk(i: int) -> Node3D:
	var c := Node3D.new()
	var zc := -i * CHUNK - CHUNK * 0.5
	c.position.z = zc
	add_child(c)
	var road := _prop(c, "road", Vector3.ZERO)
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var left_free := true
	for s in stations:
		var z0: float = s.z0
		if zc - CHUNK * 0.5 < z0 + 10.0 and zc + CHUNK * 0.5 > z0 - STATION_LEN - 10.0:
			left_free = false
	# Street lamps alternate sides.
	if i % 2 == 0:
		_prop(c, "lamp", Vector3(4.7, 0, 0), PI)
	elif left_free:
		_prop(c, "lamp", Vector3(-4.7, 0, 0))
	for side: float in [-1.0, 1.0]:
		if side < 0.0 and not left_free:
			continue
		var roll := rng.randf()
		if roll < 0.18:
			var hx := side * rng.randf_range(15.0, 19.0)
			_prop(c, "house:%d" % rng.randi_range(0, 3), Vector3(hx, 0, rng.randf_range(-10, 10)), PI if side > 0.0 else 0.0)
		elif roll < 0.26 and side < 0.0:
			_prop(c, "busstop", Vector3(-5.6, 0, rng.randf_range(-12, 12)))
		elif roll < 0.32 and side > 0.0:
			_prop(c, "sign", Vector3(4.6, 0, rng.randf_range(-15, 15)))
		var trees := rng.randi_range(2, 6)
		for t in trees:
			var x := side * rng.randf_range(9.0 if side > 0.0 else 13.0, 45.0)
			var key := "pine" if rng.randf() < 0.45 else "tree:%d" % rng.randi_range(0, 2)
			var tr := _prop(c, key, Vector3(x, 0, rng.randf_range(-20, 20)), rng.randf_range(0, TAU))
			tr.scale = Vector3.ONE * rng.randf_range(0.8, 1.35)
		if rng.randf() < 0.5:
			_prop(c, "bush", Vector3(side * rng.randf_range(6.0, 10.0), 0, rng.randf_range(-18, 18)), rng.randf_range(0, TAU))
		if rng.randf() < 0.22:
			_prop(c, "hill:%d" % rng.randi_range(0, 2), Vector3(side * rng.randf_range(80.0, 130.0), 0, 0), rng.randf_range(0, TAU))
	if left_free:
		for f in 5:
			_prop(c, "fence", Vector3(-12.0, 0, -16.0 + f * 8.0))
	return c


func _prop(parent: Node3D, key: String, pos: Vector3, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Models.mesh(key)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			_toggle_pause()
		elif event.keycode == KEY_C and steer.uses_sensor():
			steer.calibrate()
		return
	if state != State.PLAYING and state != State.COUNTDOWN:
		touch_active = false
		return
	var w := get_viewport().get_visible_rect().size.x
	if event is InputEventScreenTouch:
		touch_active = event.pressed
		touch_c = (event.position.x / w - 0.5) * 4.0
	elif event is InputEventScreenDrag:
		touch_active = true
		touch_c = (event.position.x / w - 0.5) * 4.0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		touch_active = event.pressed
		touch_c = (event.position.x / w - 0.5) * 4.0
	elif event is InputEventMouseMotion and touch_active:
		touch_c = (event.position.x / w - 0.5) * 4.0


# --- Save -------------------------------------------------------------------

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	var data = cf.get_value("save", "data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return
	for k in ["money", "best", "mode", "sens", "flip"]:
		if data.has(k):
			save[k] = data[k]
	if data.has("up") and typeof(data.up) == TYPE_DICTIONARY:
		for id in UPGRADES:
			save.up[id] = clampi(int(data.up.get(id, 0)), 0, UPGRADES[id].max)


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("save", "data", save)
	cf.save(SAVE_PATH)
