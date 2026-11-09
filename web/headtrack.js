// Head Bus browser-side sensors, read by Godot through JavaScriptBridge.
//   window.HT   - webcam head tracking (MediaPipe face detector)
//   window.TILT - device tilt (deviceorientation)
// Both expose: state ("off" | "loading"/"waiting"/"noface"/"permission" | "ready" | "error"),
// msg (human-readable status), x (steering control, 0 = centre), start(), calibrate().
(() => {
  "use strict";
  const MP = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14";
  const MODEL =
    "https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/1/blaze_face_short_range.tflite";
  // Head offset (fraction of camera width) that equals one control unit,
  // i.e. moving from your lane into the oncoming lane.
  const HEAD_UNIT = 0.11;
  // Tilt angle in degrees that equals one control unit.
  const TILT_UNIT = 18;

  // ---------------------------------------------------------------- head ----
  const HT = (window.HT = { state: "off", msg: "Camera off", x: 0, face: false });
  let video = null;
  let detector = null;
  let lastTime = -1;
  let smooth = 0.5;
  let centre = 0.5;
  let previewOn = false;

  HT.start = async () => {
    if (HT.state !== "off" && HT.state !== "error") return;
    HT.state = "loading";
    HT.msg = "Starting camera… allow camera access";
    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error("This browser can't use the camera here");
      }
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "user", width: { ideal: 320 }, height: { ideal: 240 } },
        audio: false,
      });
      video = document.createElement("video");
      video.id = "ht-preview";
      video.playsInline = true;
      video.muted = true;
      video.srcObject = stream;
      Object.assign(video.style, {
        position: "fixed", left: "10px", bottom: "10px", width: "min(132px, 22vmin)",
        borderRadius: "10px", border: "2px solid rgba(255,255,255,.7)",
        transform: "scaleX(-1)", zIndex: 10, pointerEvents: "none", opacity: ".9",
        display: previewOn ? "block" : "none",
      });
      document.body.appendChild(video);
      await video.play();
      HT.msg = "Loading face tracker…";
      const vision = await import(MP + "/vision_bundle.mjs");
      const files = await vision.FilesetResolver.forVisionTasks(MP + "/wasm");
      const make = (delegate) =>
        vision.FaceDetector.createFromOptions(files, {
          baseOptions: { modelAssetPath: MODEL, delegate },
          runningMode: "VIDEO",
          minDetectionConfidence: 0.5,
        });
      try {
        detector = await make("GPU");
      } catch (e) {
        detector = await make("CPU");
      }
      HT.state = "noface";
      HT.msg = "Looking for your face…";
      requestAnimationFrame(track);
    } catch (e) {
      HT.state = "error";
      HT.msg = "Camera unavailable: " + (e && e.message ? e.message : e);
    }
  };

  function track() {
    if (video.readyState >= 2 && video.currentTime !== lastTime) {
      lastTime = video.currentTime;
      const res = detector.detectForVideo(video, performance.now());
      const d = res.detections && res.detections[0];
      if (d) {
        let nx;
        const kp = d.keypoints;
        if (kp && kp.length >= 3) {
          nx = (kp[0].x + kp[1].x + kp[2].x) / 3; // both eyes + nose tip
        } else {
          nx = (d.boundingBox.originX + d.boundingBox.width / 2) / video.videoWidth;
        }
        if (!HT.face) smooth = nx; // no lag when the face reappears
        smooth += (nx - smooth) * 0.6;
        HT.face = true;
        HT.state = "ready";
        HT.msg = "Tracking your head";
        // The camera image is not mirrored: your left is the image's right.
        HT.x = -(smooth - centre) / HEAD_UNIT;
      } else {
        HT.face = false;
        HT.state = "noface";
        HT.msg = "Can't see your face - look at the screen";
      }
    }
    requestAnimationFrame(track);
  }

  HT.calibrate = () => {
    centre = smooth;
    HT.x = 0;
  };
  HT.preview = (on) => {
    previewOn = !!on;
    if (video) video.style.display = previewOn ? "block" : "none";
  };

  // ---------------------------------------------------------------- tilt ----
  const TILT = (window.TILT = { state: "off", msg: "Tilt off", x: 0 });
  let angle = 0;
  let zero = 0;

  function onOrientation(e) {
    if (e.beta == null || e.gamma == null) return;
    const b = (e.beta * Math.PI) / 180;
    const g = (e.gamma * Math.PI) / 180;
    // Gravity in device coordinates (W3C Z-X'-Y'' Euler angles).
    const gx = Math.cos(b) * Math.sin(g);
    const gy = -Math.sin(b);
    let rot = 0;
    if (screen.orientation && typeof screen.orientation.angle === "number") rot = screen.orientation.angle;
    else if (typeof window.orientation === "number") rot = window.orientation;
    const t = (rot * Math.PI) / 180;
    // Rotate into screen axes: steering angle is rotation about the screen normal.
    const sx = gx * Math.cos(t) - gy * Math.sin(t);
    const sUp = gx * Math.sin(t) + gy * Math.cos(t);
    angle = (Math.atan2(sx, -sUp) * 180) / Math.PI;
    if (TILT.state !== "ready") {
      TILT.state = "ready";
      TILT.msg = "Tilt to steer";
      zero = angle;
    }
    let d = angle - zero;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    TILT.x = d / TILT_UNIT;
  }

  function listen() {
    window.addEventListener("deviceorientation", onOrientation);
    TILT.state = "waiting";
    TILT.msg = "Waiting for the tilt sensor…";
    setTimeout(() => {
      if (TILT.state === "waiting") {
        TILT.state = "error";
        TILT.msg = "No tilt sensor on this device";
      }
    }, 3000);
  }

  TILT.start = () => {
    if (TILT.state !== "off" && TILT.state !== "error") return;
    if (!("DeviceOrientationEvent" in window)) {
      TILT.state = "error";
      TILT.msg = "No tilt sensor on this device";
      return;
    }
    if (typeof DeviceOrientationEvent.requestPermission === "function") {
      // iOS only grants motion access from inside a tap.
      TILT.state = "permission";
      TILT.msg = "Tap the screen to allow motion access";
      const ask = () => {
        window.removeEventListener("touchend", ask);
        window.removeEventListener("click", ask);
        DeviceOrientationEvent.requestPermission()
          .then((p) => {
            if (p === "granted") listen();
            else {
              TILT.state = "error";
              TILT.msg = "Motion access was denied";
            }
          })
          .catch((e) => {
            TILT.state = "error";
            TILT.msg = "Motion access failed: " + e;
          });
      };
      window.addEventListener("touchend", ask);
      window.addEventListener("click", ask);
    } else {
      listen();
    }
  };

  TILT.calibrate = () => {
    zero = angle;
    TILT.x = 0;
  };
})();
