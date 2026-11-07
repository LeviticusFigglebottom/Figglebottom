class_name HumanoidRig
extends AnimationTree
## AnimationTree driver for one Mixamo-rigged humanoid (ADR 0004).
##
##   loco (BlendSpace1D idle 0 / walk 1 / run 2) -> loco_rate (TimeScale) --\
##   act0 (Animation) -> act0_seek (TimeSeek) --\                           mix (Blend2) -> output
##   act1 (Animation) -> act1_seek (TimeSeek) ---> slot (Blend2) ---------/
##
## Two action slots let one action cross-fade into the next. Action time is
## owned here, not by the tree: each physics tick both slots are seeked to
## their own clocks and the tree is advanced manually. Combat state machines
## count time in physics ticks too, so the skeleton shows exactly the clock
## combat code reads and a contact frame lands on its data windup tick. Actions play a section
## [start, end] of their clip (Tripo presets carry long idle lead-ins) and
## hold the end frame until stopped or until locomotion takes back over.

const LOCO_CLIPS := ["idle", "walk", "run"]

var model_id := ""
var own: AnimationLibrary = null

var _slot := 0                     # slot the current action plays in
var _clip := ["", ""]              # game clip name per slot
var _t := [0.0, 0.0]               # clip time per slot (s)
var _rate := [1.0, 1.0]
var _end := [0.0, 0.0]
var _start := [0.0, 0.0]
var _loop := [false, false]
var _done := [false, false]
var _active := false               # an action owns the rig
var _w_act := 0.0
var _w_act_to := 0.0
var _w_act_speed := 10.0
var _w_slot := 0.0
var _w_slot_speed := 10.0
var _loco_rate := 1.0
var _loco_pos := 0.0
var _loco_phase := 0.0             # seconds into the dominant loco cycle

func setup(id: String, skel: Skeleton3D) -> void:
	model_id = id
	add_animation_library("", HumanoidLib.shared_library())
	own = HumanoidLib.own_library(id)
	if own != null:
		add_animation_library("own", own)
	skel.motion_scale = HumanoidLib.hips_height(id)
	root_node = get_path_to(skel.get_parent())
	callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# pose before the owner's state machine ticks, so its hit volumes read
	# this tick's skeleton
	process_physics_priority = -10
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 2.0
	var lpos: Dictionary = HumanoidLib.meta().get("locomotion", {"idle": 0.0, "walk": 1.0, "run": 2.0})
	for c in LOCO_CLIPS:
		var an := AnimationNodeAnimation.new()
		an.animation = qualified(c)
		loco.add_blend_point(an, float(lpos.get(c, 0.0)), -1, StringName(c))
	bt.add_node("loco", loco)
	bt.add_node("loco_rate", AnimationNodeTimeScale.new())
	bt.connect_node("loco_rate", 0, "loco")
	for s in 2:
		var an := AnimationNodeAnimation.new()
		an.animation = qualified("idle")
		bt.add_node("act%d" % s, an)
		bt.add_node("act%d_seek" % s, AnimationNodeTimeSeek.new())
		bt.connect_node("act%d_seek" % s, 0, "act%d" % s)
	bt.add_node("slot", AnimationNodeBlend2.new())
	bt.connect_node("slot", 0, "act0_seek")
	bt.connect_node("slot", 1, "act1_seek")
	bt.add_node("mix", AnimationNodeBlend2.new())
	bt.connect_node("mix", 0, "loco_rate")
	bt.connect_node("mix", 1, "slot")
	bt.connect_node("output", 0, "mix")
	tree_root = bt
	active = true
	_push()
	advance(0.0)

## Library-qualified animation for a game clip. Each candidate name (the
## clip, then its aliases) is looked up real-first: the model's own real clip,
## the shared real clip, then the procedural overlays. So a real "roll"
## dropped into any rig's glb replaces the overlay everywhere it is missing.
func qualified(clip: String) -> String:
	var shared := HumanoidLib.shared_library()
	for c in HumanoidLib.candidates(clip):
		var hits := []
		if own != null and own.has_animation(c):
			hits.append("own/" + c)
		if shared.has_animation(c):
			hits.append(c)
		for q in hits:
			if not HumanoidLib.is_procedural(get_animation(q)):
				return q
		if not hits.is_empty():
			return hits[0]
	return ""

func _resolved_name(clip: String) -> String:
	var q := qualified(clip)
	return q.trim_prefix("own/")

func has_clip(clip: String) -> bool:
	return qualified(clip) != ""

func clip_anim(clip: String) -> Animation:
	var q := qualified(clip)
	return get_animation(q) if q != "" else null

func _section(clip: String) -> Vector3:   # (start, contact, end)
	var a := clip_anim(clip)
	var info := HumanoidLib.clip_info(_resolved_name(clip), HumanoidLib.is_procedural(a))
	var length := a.length if a != null else 1.0
	var s := float(info.get("start", 0.0))
	var e := minf(float(info.get("end", length)), length)
	return Vector3(s, float(info.get("contact", s)), e)

## Seconds of the clip section at 1x (the roll uses it to fit the data duration).
func clip_length(clip: String) -> float:
	var sec := _section(clip)
	return sec.z - sec.x

## Contact time measured from the section start at 1x.
func contact_time(clip: String) -> float:
	var sec := _section(clip)
	return sec.y - sec.x

func play(clip: String, blend := 0.12, speed := 1.0) -> void:
	var sec := _section(clip)
	_start_action(clip, blend, speed, sec.x, sec.z)

## Rate-scale `clip` so its contact frame lands `contact_at` seconds from now.
## Past the rate cap the lead-in is trimmed instead: the hit is never late.
func play_timed(clip: String, contact_at: float, blend := 0.08, lo := 0.0, hi := INF) -> float:
	var sec := _section(clip)
	var at := maxf(contact_at, 0.02)
	var cap := minf(hi, float(HumanoidLib.meta().get("max_rate", 2.4)))
	var start := sec.x
	var rate := (sec.y - start) / at
	if rate > cap:
		rate = cap
		start = sec.y - cap * at
	elif rate < lo:
		rate = lo
		start = maxf(sec.y - lo * at, 0.0)
		if start <= 0.0:
			rate = sec.y / at
	_start_action(clip, blend, rate, start, sec.z)
	return rate

func _start_action(clip: String, blend: float, rate: float, start: float, end: float) -> void:
	var q := qualified(clip)
	if q == "":
		return
	var from_loco := not _active or _w_act < 0.05
	var s := _slot if from_loco else 1 - _slot
	_slot = s
	_clip[s] = clip
	_t[s] = start
	_start[s] = start
	_rate[s] = rate
	_end[s] = end
	var anim := get_animation(q)
	_loop[s] = anim.loop_mode != Animation.LOOP_NONE
	_done[s] = false
	(tree_root.get_node("act%d" % s) as AnimationNodeAnimation).animation = q
	var b := maxf(blend, 0.001)
	if from_loco:
		_w_slot = float(s)
	_w_slot_speed = 1.0 / b
	_w_act_to = 1.0
	_w_act_speed = 1.0 / b
	_active = true

## Hand the rig back to locomotion.
func stop_action(blend := 0.2) -> void:
	_active = false
	_w_act_to = 0.0
	_w_act_speed = 1.0 / maxf(blend, 0.001)

func action_active() -> bool:
	return _active and not (_done[_slot] and not _loop[_slot])

func action_clip() -> String:
	return _clip[_slot] if _active else ""

func action_time() -> float:
	return _t[_slot]

func action_started_at() -> float:
	return _start[_slot]

## What owns the rig: the action clip, or the gait, or "" once a one-shot has
## finished (as AnimationPlayer reports a finished clip).
func current_clip() -> String:
	if _active:
		return "" if (_done[_slot] and not _loop[_slot]) else String(_clip[_slot])
	return LOCO_CLIPS[clampi(roundi(_loco_pos), 0, 2)]

## Gait blend by ground speed; stride/run_stride are the m/s at which the
## walk/run cycles play at 1x. Returns the dominant gait.
func locomotion(dt: float, ground_speed: float, stride: float, run_stride: float, grounded := true) -> String:
	if _active and not _done[_slot]:
		return ""
	if _active:
		stop_action(0.3)   # a finished one-shot yields, like AnimationPlayer's ""
	var v := ground_speed if grounded else 0.0
	var want := 0.0
	if v > 0.55:
		want = clampf(v / stride, 0.0, 1.0) if v <= stride \
				else clampf(1.0 + (v - stride) / maxf(run_stride - stride, 0.01), 1.0, 2.0)
	_loco_pos = lerpf(_loco_pos, want, 1.0 - exp(-10.0 * dt))
	if _loco_pos < 0.5:
		_loco_rate = 1.0
	elif _loco_pos < 1.0:
		_loco_rate = clampf(v / stride, 0.55, 1.75)
	else:
		_loco_rate = clampf(v / lerpf(stride, run_stride, _loco_pos - 1.0), 0.7, 1.5)
	return LOCO_CLIPS[clampi(roundi(_loco_pos), 0, 2)]

## Seconds into the dominant gait cycle and its length (for footfalls).
func loco_cycle() -> Vector2:
	var a := clip_anim(LOCO_CLIPS[clampi(roundi(_loco_pos), 0, 2)])
	return Vector2(_loco_phase, a.length if a != null else 1.0)

func _physics_process(dt: float) -> void:
	for s in 2:
		if _clip[s] == "" or _done[s]:
			continue
		_t[s] += dt * _rate[s]
		if _t[s] >= _end[s]:
			if _loop[s]:
				_t[s] = _start[s] + fposmod(_t[s] - _start[s], maxf(_end[s] - _start[s], 0.01))
			else:
				_t[s] = _end[s]
				_done[s] = true
	_w_act = move_toward(_w_act, _w_act_to, dt * _w_act_speed)
	_w_slot = move_toward(_w_slot, float(_slot), dt * _w_slot_speed)
	var cyc := loco_cycle()
	_loco_phase = fposmod(_loco_phase + dt * _loco_rate, maxf(cyc.y, 0.01))
	_push()
	advance(dt)

func _push() -> void:
	set("parameters/loco/blend_position", _loco_pos)
	set("parameters/loco_rate/scale", _loco_rate)
	set("parameters/act0_seek/seek_request", _t[0])
	set("parameters/act1_seek/seek_request", _t[1])
	set("parameters/slot/blend_amount", _w_slot)
	set("parameters/mix/blend_amount", _w_act)
