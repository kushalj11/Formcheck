# FormCheck

Built goal by goal from FormCheck_SDD. Open `FormCheck.xcodeproj`, set your Team under
Signing & Capabilities, and run on a real iPhone (the simulator has no camera).
Any Swift file added under `FormCheck/` is picked up automatically.

## Goal 1: squat tracking (current)

Two tabs: **Record** (camera) and **Library** (saved clips + Import from Photos).
Tapping a clip opens playback with the tracked joints drawn on top.

| Sub-goal | How to check |
|---|---|
| 1.1 Recording saved locally | Record tab: start, stop. The clip appears in Library (Documents/Recordings). |
| 1.2 In-app playback | Playback screen uses `PlayerModel` (the component Goal 5 reuses). Play, scrub, frame-step. |
| 1.3 Pose on every frame, no crashes | Open the **Report**: frames analysed, frames with pose, Vision errors, longest gap. |
| 1.4 Dots on correct joints, incl. bottom | Use **Jump to bottom**, then frame-step around it. Dot colour: green >= 0.7, yellow >= 0.4, red below. |
| 1.5 More than one lifter / lighting | Import different clips from Photos and compare Reports. |

If dots are offset or mirrored, look at `PoseDetector.imageOrientation` and `PoseOverlay` first.

Camera is portrait-locked for now.

## Filming

Film every set at a **45° angle to the lifter's front**, whole body in frame, phone steady at hip height.
From 45° the camera sees both front-to-back motion (depth, back angle, bar path) and side-to-side motion
(knee cave, hip balance), so every check runs on one clip. Front-to-back measurements are scaled up by
1 / cos 45° to undo the foreshortening; vertical measurements are unaffected by the camera angle.

## Live camera

The Record screen tracks the pose on every frame Vision can keep up with and draws the skeleton over the
preview, before and during recording. A cue card shows what to focus on at the current point in the rep
(setup, way down, bottom, way up, top), worked out from hip height (squat) or bar height
(bench press) in `RepPhaseTracker`. Scoring happens
afterwards on the saved recording, where every frame is tracked.

## Set analysis and scoring

Pick the lift on the Set Analysis screen (or a default in Settings). Each lift has its own rules, and all
of them run on a 45° clip:

### Squat (barbell: 10 checks, bodyweight: 8)

| Rule | Lifts | Measured as |
|---|---|---|
| Depth | Barbell, Bodyweight | Thigh angle vs parallel at the bottom |
| Lockout | Barbell, Bodyweight | Hip and knee ≥ 160° at the top |
| Back angle | Barbell, Bodyweight | Torso lean change in the first third of the ascent |
| Bar over mid-foot | Barbell | Shoulder drift from the lockout position |
| Knee tracking | Barbell, Bodyweight | Knee gap ÷ ankle gap at the bottom vs standing |
| Left/right balance | Barbell, Bodyweight | Hip height difference at the bottom |
| Bar level | Barbell | Shoulder height difference at the bottom |
| Head position | Barbell, Bodyweight | Head tilt vs the torso, bottom vs standing |
| Stance width | Barbell, Bodyweight | Ankle gap ÷ shoulder gap while standing |
| Controlled descent | Barbell, Bodyweight | Time from leaving the top to the bottom |

### Bench press (6 checks)

Filmed at bench height, 45° from the lifter's side toward the head. The bar is the
midpoint between the wrists; reps are found from bar height, measured in upper arm lengths.

| Rule | Measured as |
|---|---|
| Touch the chest | Elbow height below shoulder level at the bottom |
| Lockout | Elbow angle ≥ 160° at the top |
| Bar over shoulders | Bar's horizontal distance from the shoulders at lockout |
| Forearms vertical | Forearm lean from vertical at the bottom |
| Bar level | Wrist height difference |
| Hips on the bench | Hip rise during the press |

**Form score = 100 × (1 − failed checks / checks run)** across every rep. A check that can't be judged
from the detected camera angle, or whose joints weren't tracked confidently, is shown as "not checked"
and doesn't count either way. Thresholds live at the top of `SquatRules.swift`, `BarRules.swift` and `BenchRules.swift`.

Pose detection does not run in the iOS Simulator (Vision can't set up the body-pose request there);
use a real iPhone.
