class_name SteerInput
extends RefCounted
## Reads the steering "control" value from the browser-side head tracker
## (window.HT) or tilt sensor (window.TILT), both defined in web/headtrack.js.
## Control 0 = keep to your lane, +1 = oncoming lane, about -1.7 = petrol station.

enum Mode { HEAD, TILT, KEYS }

const MODE_NAMES := ["Head (webcam)", "Tilt (phone)", "Keys / Touch"]

var mode := Mode.KEYS
var sens := 1.0
var flip := false
var _js := {}


func is_web() -> bool:
	return OS.has_feature("web")


func _iface() -> JavaScriptObject:
	var name := "HT" if mode == Mode.HEAD else "TILT"
	if not _js.has(name) or _js[name] == null:
		_js[name] = JavaScriptBridge.get_interface(name) if is_web() else null
	return _js[name]


func uses_sensor() -> bool:
	return mode != Mode.KEYS


## Starts the camera / motion listener for the current mode (no-op for keys).
func start() -> void:
	var js := _iface() if uses_sensor() else null
	if js:
		js.start()
	set_preview(mode == Mode.HEAD)


func set_preview(on: bool) -> void:
	if not is_web():
		return
	var ht = JavaScriptBridge.get_interface("HT")
	if ht:
		ht.preview(on)


func calibrate() -> void:
	var js := _iface() if uses_sensor() else null
	if js:
		js.calibrate()


## "ready" (sensor delivering), "waiting", "error" or "off".
func state() -> String:
	if not uses_sensor():
		return "ready"
	var js := _iface()
	if js == null:
		return "error"
	var s := str(js.state)
	if s == "ready":
		return "ready"
	if s == "error":
		return "error"
	if s == "off":
		return "off"
	return "waiting"


func message() -> String:
	if not uses_sensor():
		return "Left/right or A/D to steer, up/down or W/S for speed, or drag a finger across the screen."
	if not is_web():
		return "Head and tilt steering only work in the web version. Using keys."
	var js := _iface()
	if js == null:
		return "Sensor script failed to load. Using keys."
	return str(js.msg)


## Latest control value; NAN when the sensor has no fresh reading.
func control() -> float:
	if not uses_sensor() or state() != "ready":
		return NAN
	var v := float(_iface().x) * sens
	return -v if flip else v


## Speed control from looking up (+) / down (-), clamped to -1..1 with a small
## dead zone so a steady head holds cruise speed. NAN without head tracking.
func throttle() -> float:
	if mode != Mode.HEAD or state() != "ready":
		return NAN
	var v := clampf(float(_iface().y) * sens, -1.0, 1.0)
	return 0.0 if absf(v) < 0.15 else (v - signf(v) * 0.15) / 0.85
