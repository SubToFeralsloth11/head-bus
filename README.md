# Head Bus

A low-poly 3D browser game made in Godot 4.7: drive a red double-decker down an endless two-lane road (traffic keeps left), weave past slow cars and oncoming traffic, grab coins, dodge roadworks, and spend your fares on upgrades.

**Play:** https://subtoferalsloth11.github.io/head-bus/

## Steering

Pick a mode on the title screen:

| Mode | How it steers |
| --- | --- |
| Head (webcam) | The bus follows your head. Move slowly and it drifts; move quickly and it swerves (capped by the Power Steering upgrade). Look up to speed up (up to 140% of cruise speed), look down to slow down (down to 40%). Lean further left to pull into a petrol station. |
| Tilt (phone) | Tilt the phone or tablet left/right like a steering wheel. iPhone asks for motion access on your first tap. |
| Keys / Touch | Left/right arrows or A/D steer, up/down arrows or W/S change speed; or drag a finger across the screen. |

The game re-centres when each run starts (look straight at the screen / hold the device how you'll play). **Re-centre** (or `C`) does it again mid-run; **Flip left / right** swaps directions if your camera or device reads them backwards. `Esc`/`P` pauses.

Head tracking runs fully in the browser with MediaPipe's face detector; no video leaves your device.

## Rules

- Money comes in faster the faster you drive. Get stuck behind a slow car and your bus brakes, so overtake through the oncoming lane.
- Passing close to a vehicle without touching it is a **close call** bonus; chain them for a combo.
- Cones and potholes slow you down; crashing into vehicles, barriers or broken-down cars costs a heart.
- **Petrol stations** have a slip road on the left with no traffic. It skips jams and roadworks, but you drive at half speed in there, so you earn less.
- Every 450 m the level goes up: faster cruising speed, denser traffic, roadworks, broken-down cars and more trucks.

Upgrades (Garage): Power Steering, Bull Bars (extra hearts), Fare Box (+20% money), Coin Magnet.

## Development

- `project.godot`: open in Godot 4.7 (Compatibility renderer).
- `scripts/`: `game.gd` (gameplay, spawning, scenery), `models.gd` + `mesh_kit.gd` (all low-poly models built from code), `ui.gd`, `steer_input.gd`, `sfx.gd` (sounds synthesised at start-up).
- `web/headtrack.js`: browser-side head tracking (`window.HT`) and tilt (`window.TILT`), read by Godot through `JavaScriptBridge`.
- `tools/build_web.sh`: exports the web build to `docs/`, which GitHub Pages serves.
