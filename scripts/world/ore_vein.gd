class_name OreVein
extends Node2D

signal depleted(vein: OreVein)

@export_range(20.0, 500.0, 1.0) var maximum_ore := 240.0
@export_range(0.0, 20.0, 0.1) var growth_per_second := 1.5
@export_range(1.0, 80.0, 1.0) var harvest_radius := 34.0
var ore := 0.0
var _depleted := false
var _active_miner: Node
var _mining_queue: Array[Node] = []
var _harvest_target_flash_remaining := 0.0

func _ready() -> void:
	ore = maximum_ore
	add_to_group("ore_veins")
	queue_redraw()

func _physics_process(delta: float) -> void:
	ore = minf(maximum_ore, ore + growth_per_second * delta)
	_harvest_target_flash_remaining = maxf(_harvest_target_flash_remaining - delta, 0.0)
	queue_redraw()

func flash_harvest_target() -> void:
	_harvest_target_flash_remaining = 1.1
	queue_redraw()

func harvest(amount: float) -> float:
	if _depleted:
		return 0.0
	var taken := minf(maxf(ore, 0.0), maxf(amount, 0.0))
	ore -= taken
	if ore <= 0.0:
		ore = 0.0
		_depleted = true
		remove_from_group("ore_veins")
		_active_miner = null
		_mining_queue.clear()
		depleted.emit(self)
	return taken

func request_mining_access(worker: Node) -> bool:
	if _depleted or worker == null or not is_instance_valid(worker):
		return false
	_prune_mining_queue()
	if _active_miner == worker:
		return true
	if is_instance_valid(_active_miner):
		if not _mining_queue.has(worker):
			_mining_queue.append(worker)
		return false
	if not _mining_queue.is_empty():
		if _mining_queue[0] != worker:
			if not _mining_queue.has(worker):
				_mining_queue.append(worker)
			return false
		_mining_queue.pop_front()
	_active_miner = worker
	return true

func is_available_for_mining(worker: Node = null) -> bool:
	_prune_mining_queue()
	if _active_miner != null and _active_miner != worker:
		return false
	return _mining_queue.is_empty() or (_mining_queue.size() == 1 and _mining_queue[0] == worker)

func release_mining_access(worker: Node) -> void:
	_mining_queue.erase(worker)
	if _active_miner == worker:
		_active_miner = null

func _prune_mining_queue() -> void:
	var valid_queue: Array[Node] = []
	for worker in _mining_queue:
		if is_instance_valid(worker) and not valid_queue.has(worker):
			valid_queue.append(worker)
	_mining_queue = valid_queue
	if _active_miner != null and not is_instance_valid(_active_miner):
		_active_miner = null

func _draw() -> void:
	var ratio := clampf(ore / maxf(maximum_ore, 1.0), 0.0, 1.0)
	if _harvest_target_flash_remaining > 0.0:
		var pulse := 1.0 - _harvest_target_flash_remaining / 1.1
		var pulse_radius := lerpf(52.0, 70.0, pulse)
		var pulse_alpha := 0.95 * (1.0 - pulse * 0.55)
		draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 40, Color(1.0, 0.82, 0.25, pulse_alpha), 4.0)
		draw_arc(Vector2.ZERO, pulse_radius - 7.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - pulse), 32, Color("fff0a3"), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-42, -56), "HARVEST", HORIZONTAL_ALIGNMENT_CENTER, 84, 12, Color(1.0, 0.9, 0.45, pulse_alpha))
	draw_circle(Vector2.ZERO, 42.0, Color("293b46"))
	draw_circle(Vector2.ZERO, 32.0, Color("526f72"))
	draw_circle(Vector2.ZERO, 22.0, Color("d0a451").lerp(Color("42505a"), 1.0 - ratio))
	for offset in [Vector2(-13, -5), Vector2(8, -11), Vector2(14, 8), Vector2(-8, 13)]:
		draw_circle(offset, 5.0, Color("f4d58b").lerp(Color("53656a"), 1.0 - ratio))
	draw_arc(Vector2.ZERO, 48.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 32, Color("f4d58b"), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-28, 64), "ORE %d" % roundi(ore), HORIZONTAL_ALIGNMENT_CENTER, 56, 11, Color("dce5df"))
