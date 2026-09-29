class_name GrindRail
extends Line2D

@export var points_per_segment := 48
@export var detection_radius := 150.0
@export var gravity := 400.0
@export var tension := 0.3
@export var constraint_iterations := 8
@export var damping := 0.94

class Particle:
	var pos: Vector2
	var old_pos: Vector2
	var rest_pos: Vector2
	var pinned: bool
	func _init(p: Vector2, pin: bool = false):
		pos = p
		old_pos = p
		rest_pos = p
		pinned = pin

var particles: Array = []
var rest_lengths: Array = []
var grabbed_t: float = -1.0
var anchor_points: Array = []
var time_alive := 0.0
var smooth_grab_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("grind_rails")
	_init_particles()

func _init_particles() -> void:
	particles.clear()
	anchor_points.clear()
	rest_lengths.clear()
	
	if points.size() < 2:
		return
	
	for p in points:
		anchor_points.append(p)
	
	var all_positions = []
	
	for seg_idx in range(anchor_points.size() - 1):
		var start_pos = anchor_points[seg_idx]
		var end_pos = anchor_points[seg_idx + 1]
		var seg_len = start_pos.distance_to(end_pos)
		var seg_rest = seg_len / float(points_per_segment)
		
		for i in range(points_per_segment):
			var t = float(i) / float(points_per_segment)
			all_positions.append(start_pos.lerp(end_pos, t))
			rest_lengths.append(seg_rest)
	
	all_positions.append(anchor_points[anchor_points.size() - 1])
	
	for i in range(all_positions.size()):
		var is_pinned = false
		for anchor in anchor_points:
			if all_positions[i].distance_to(anchor) < 0.1:
				is_pinned = true
				break
		particles.append(Particle.new(all_positions[i], is_pinned))
	
	clear_points()
	for p in particles:
		add_point(p.pos)

func _physics_process(delta: float) -> void:
	if particles.is_empty():
		return
	
	time_alive += delta
	
	for i in range(particles.size()):
		var p = particles[i]
		if p.pinned:
			continue
		var vel = (p.pos - p.old_pos) * damping
		p.old_pos = p.pos
		
		var gravity_mult = 1.0
		var edge_zone = 6
		if i < edge_zone:
			gravity_mult = lerp(0.2, 1.0, float(i) / float(edge_zone))
		elif i > particles.size() - 1 - edge_zone:
			gravity_mult = lerp(0.2, 1.0, float(particles.size() - 1 - i) / float(edge_zone))
		
		p.pos += vel + Vector2(0, gravity * gravity_mult * delta)
		
		var tension_force = (p.rest_pos - p.pos) * tension * 0.5
		p.pos += tension_force
	
	for _iter in range(constraint_iterations):
		for i in range(particles.size() - 1):
			var p1 = particles[i]
			var p2 = particles[i+1]
			var delta_vec = p2.pos - p1.pos
			var dist = delta_vec.length()
			if dist < 0.001 or not is_finite(dist):
				continue
			var rest = rest_lengths[i]
			var diff = (dist - rest) / dist
			var offset = delta_vec * diff * 0.5
			if not p1.pinned:
				p1.pos += offset
			if not p2.pinned:
				p2.pos -= offset
	
	for i in range(particles.size()):
		set_point_position(i, particles[i].pos)

func get_closest_point_and_t(global_pos: Vector2) -> Dictionary:
	var local_pos = to_local(global_pos)
	var min_dist = INF
	var best_t = 0.0
	var best_local = Vector2.ZERO
	
	if particles.size() < 2:
		return {"point": global_pos, "t": 0.0, "distance": INF}
	
	for i in range(particles.size() - 1):
		var p1 = particles[i].pos
		var p2 = particles[i+1].pos
		var seg = p2 - p1
		var len_sq = seg.length_squared()
		var t_local = 0.0
		if len_sq > 0.0001:
			t_local = clampf((local_pos - p1).dot(seg) / len_sq, 0.0, 1.0)
		var proj = p1 + seg * t_local
		var d = local_pos.distance_to(proj)
		if d < min_dist and is_finite(d):
			min_dist = d
			best_local = proj
			best_t = (float(i) + t_local) / float(particles.size() - 1)
	
	return {"point": to_global(best_local), "t": best_t, "distance": min_dist}

func get_point_at_t(t: float) -> Vector2:
	if particles.is_empty():
		return Vector2.ZERO
	var idx_f = t * (particles.size() - 1)
	var idx = int(idx_f)
	var frac = idx_f - idx
	if idx >= particles.size() - 1:
		return to_global(particles[particles.size() - 1].pos)
	var local = particles[idx].pos.lerp(particles[idx + 1].pos, frac)
	return to_global(local)

func get_tangent_at(t: float) -> Vector2:
	if particles.size() < 2:
		return Vector2.RIGHT
	var idx_f = t * (particles.size() - 1)
	var idx = int(idx_f)
	if idx >= particles.size() - 1:
		idx = particles.size() - 2
	var tangent = particles[idx + 1].pos - particles[idx].pos
	var len = tangent.length()
	if len < 0.01 or not is_finite(len):
		if idx > 0:
			tangent = particles[idx].pos - particles[idx - 1].pos
			len = tangent.length()
		if len < 0.01 or not is_finite(len):
			return Vector2.RIGHT
	return tangent / len

func set_grabbed(t: float, player_global_pos: Vector2) -> void:
	grabbed_t = t
	smooth_grab_pos = to_local(player_global_pos)

func release_grab() -> void:
	grabbed_t = -1.0

func apply_grab_pull(target_global_pos: Vector2, t: float, strength: float, is_moving: bool) -> void:
	if t < 0:
		return
	
	var target_local = to_local(target_global_pos)
	smooth_grab_pos = smooth_grab_pos.lerp(target_local, 0.15)
	
	var center_idx = int(t * (particles.size() - 1))
	var radius = 10
	for i in range(maxi(0, center_idx - radius), mini(particles.size(), center_idx + radius + 1)):
		var p = particles[i]
		if p.pinned:
			continue
		var dist = abs(i - center_idx)
		var factor = 1.0 - float(dist) / float(radius + 1)
		factor = factor * factor * factor * factor
		p.pos = p.pos.lerp(smooth_grab_pos, strength * factor)
	
	var sag_offset = Vector2(0, 6.0)
	for i in range(maxi(0, center_idx - 3), mini(particles.size(), center_idx + 4)):
		if particles[i].pinned:
			continue
		var dist = abs(i - center_idx)
		var factor = 1.0 - float(dist) / 4.0
		factor = factor * factor
		particles[i].pos += sag_offset * factor
