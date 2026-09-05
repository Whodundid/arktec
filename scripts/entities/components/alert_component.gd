class_name AlertComponent
extends EntityComponent

## Small reactive AI layer for enemies. An attacked unit alerts nearby allies,
## who pursue the attacker briefly, investigate the last known position after
## losing line of sight, and finally return to their home territory.

enum State { IDLE, PURSUING, ENGAGING, INVESTIGATING, WAITING_AT_LEASH, RETURNING }
enum Role { GUARD, PURSUER, FLANKER, BUILDER }

@export var enabled := false
@export var role := Role.PURSUER
@export_range(32.0, 600.0, 1.0) var alert_radius := 260.0
@export_range(0.5, 20.0, 0.5) var pursuit_duration := 6.0
@export_range(0.5, 20.0, 0.5) var investigate_duration := 3.5
@export_range(16.0, 300.0, 1.0) var investigate_radius := 96.0
@export_range(1.0, 64.0, 1.0) var arrival_distance := 14.0
@export_range(16.0, 160.0, 1.0) var pursuit_spacing := 48.0
@export_range(0.05, 0.9, 0.05) var retreat_health_ratio := 0.25
@export_range(64.0, 2000.0, 8.0) var max_pursuit_distance := 520.0
@export_range(0.5, 10.0, 0.5) var leash_wait_duration := 2.5
@export_range(0.5, 20.0, 0.5) var engagement_duration := 8.0
@export_range(32.0, 400.0, 8.0) var engagement_radius := 220.0
@export_range(0.4, 0.95, 0.05) var firing_standoff_ratio := 0.7
@export_range(1.0, 64.0, 1.0) var firing_standoff_tolerance := 20.0
@export_range(-3.14, 3.14, 0.05) var flank_angle_bias := 0.0
@export_range(0.05, 0.5, 0.01) var decision_interval := 0.25

var state := State.IDLE
var _attacker: Entity
var _pursuit_base_angle := 0.0
var _last_known_position := Vector2.ZERO
var _engagement_position := Vector2.ZERO
var _engagement_remaining := 0.0
var _state_remaining := 0.0
var _return_position := Vector2.ZERO
var _search_points: Array[Vector2] = []
var _search_index := 0
var _search_destination_active := false
var _movement: MovementComponent
var _combat: CombatComponent
var _wander: WanderComponent
var _decision_remaining := 0.0
var construction_active := false
var _emergency_defense_active := false
var _normal_projectile_damage := -1.0

func set_construction_active(active: bool) -> void:
	construction_active = active
	_log_ai("construction %s" % ("started" if active else "finished"))
	if active:
		var harvest := entity.get_component(HarvestComponent) as HarvestComponent
		if harvest != null:
			harvest.cancel_harvest_action()
		entity.set_action_state(Entity.ActionState.CONSTRUCTING)
		_attacker = null
		state = State.IDLE
		if _movement != null:
			_movement.stop()
		if _wander != null:
			_wander.enabled = false
		if _combat != null:
			_combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
	else:
		if entity.action_state == Entity.ActionState.CONSTRUCTING:
			entity.set_action_state(Entity.ActionState.IDLE)
		if _wander != null:
			_wander.enabled = true
		if _combat != null:
			_combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)

func set_role(new_role: int) -> void:
	role = clampi(new_role, Role.GUARD, Role.BUILDER)
	_log_ai("role assigned: %s" % get_role_name(role))
	match role:
		Role.GUARD:
			# Guards protect the local area and give up a chase quickly.
			alert_radius = 320.0
			pursuit_duration = 3.5
			investigate_radius = 64.0
			max_pursuit_distance = 220.0
			leash_wait_duration = 1.5
			firing_standoff_ratio = 0.75
			pursuit_spacing = 40.0
			flank_angle_bias = 0.0
		Role.PURSUER:
			# Pursuers use the balanced baseline profile.
			alert_radius = 260.0
			pursuit_duration = 6.0
			investigate_radius = 96.0
			max_pursuit_distance = 520.0
			leash_wait_duration = 2.5
			firing_standoff_ratio = 0.7
			pursuit_spacing = 48.0
			flank_angle_bias = 0.0
		Role.FLANKER:
			# Flankers tolerate a longer chase and approach from a side angle.
			alert_radius = 300.0
			pursuit_duration = 7.0
			investigate_radius = 112.0
			max_pursuit_distance = 620.0
			leash_wait_duration = 3.0
			firing_standoff_ratio = 0.65
			pursuit_spacing = 96.0
			flank_angle_bias = 0.9
		Role.BUILDER:
			# Builders are valuable specialists, not frontline fighters. They
			# retreat readily and only tolerate a very short defensive response.
			alert_radius = 220.0
			pursuit_duration = 1.0
			investigate_radius = 64.0
			max_pursuit_distance = 120.0
			leash_wait_duration = 1.0
			firing_standoff_ratio = 0.9
			pursuit_spacing = 32.0
			flank_angle_bias = 0.0
			retreat_health_ratio = 0.75

static func get_role_name(role_value: int) -> String:
	match role_value:
		Role.GUARD:
			return "Guard"
		Role.FLANKER:
			return "Flanker"
		Role.BUILDER:
			return "Builder"
		_:
			return "Pursuer"

func get_debug_active_action() -> String:
	if role == Role.BUILDER:
		match entity.action_state:
			Entity.ActionState.HARVESTING:
				return "Mining ore"
			Entity.ActionState.WAITING_FOR_RESOURCE:
				return "Waiting for an available vein"
			Entity.ActionState.RETURNING_TO_BASE:
				return "Returning ore to base"
			Entity.ActionState.CONSTRUCTING:
				return "Building or repairing"
	match state:
		State.PURSUING:
			return "Pursuing attacker"
		State.ENGAGING:
			return "Resolving local engagement"
		State.INVESTIGATING:
			return "Searching last known area"
		State.WAITING_AT_LEASH:
			return "Waiting at pursuit leash"
		State.RETURNING:
			return "Returning to base"
		_:
			if _wander != null and _wander.enabled:
				return "Wandering territory"
			return "Holding position"

func get_debug_next_goal() -> String:
	if role == Role.BUILDER:
		match entity.action_state:
			Entity.ActionState.HARVESTING:
				return "Finish mining, then return"
			Entity.ActionState.WAITING_FOR_RESOURCE:
				return "Switch to a nearby free vein"
			Entity.ActionState.RETURNING_TO_BASE:
				return "Deposit ore, then resume work"
			Entity.ActionState.CONSTRUCTING:
				return "Finish the construction task"
			Entity.ActionState.IDLE:
				return "Find ore or a damaged building"
	match state:
		State.PURSUING:
			return "Close to firing distance"
		State.ENGAGING:
			return "Hold area and engage visible hostiles"
		State.INVESTIGATING:
			return "Check search points, then return"
		State.WAITING_AT_LEASH:
			return "Resume return to base"
		State.RETURNING:
			return "Reach home territory"
		_:
			if _wander != null and _wander.enabled:
				return "Choose next wander point"
			return "Await an alert or order"

func on_entity_ready() -> void:
	_movement = entity.get_component(MovementComponent) as MovementComponent
	_combat = entity.get_component(CombatComponent) as CombatComponent
	_wander = entity.get_component(WanderComponent) as WanderComponent
	var health := entity.get_component(HealthComponent) as HealthComponent
	if health != null:
		health.attacked.connect(_on_attacked)
		health.health_changed.connect(_on_health_changed)
	_decision_remaining = fmod(float(entity.get_instance_id()), decision_interval)

func _physics_process(delta: float) -> void:
	if not enabled or entity == null or _movement == null or _combat == null:
		return
	_decision_remaining = maxf(_decision_remaining - delta, 0.0)

	match state:
		State.PURSUING:
			_update_pursuit(delta)
		State.ENGAGING:
			_update_engagement(delta)
		State.INVESTIGATING:
			_update_investigation(delta)
		State.WAITING_AT_LEASH:
			_update_leash_wait(delta)
		State.RETURNING:
			_update_return()

func _on_attacked(attacker: Entity) -> void:
	if not enabled or not _is_valid_opponent(attacker):
		return
	if construction_active:
		return
	_log_ai("decision: attacked by %s" % attacker.get_diagnostics_identity())
	if role == Role.BUILDER:
		if _has_available_combat_defender():
			_request_faction_defense(attacker)
			_broadcast_alert(attacker)
			_begin_return()
		else:
			# Builders are a last line of defense only. They can buy time when the
			# faction has no idle combat unit left, but their emergency weapon is
			# intentionally much weaker than a real combat unit's weapon.
			_begin_emergency_defense(attacker)
		return
	if _is_low_health():
		_begin_return()
		return
	_broadcast_alert(attacker)
	_respond_to_alert(attacker, attacker.global_position)

func _request_faction_defense(attacker: Entity) -> void:
	var sandboxes := get_tree().get_nodes_in_group("battle_sandboxes")
	if sandboxes.is_empty():
		return
	sandboxes[0].call("request_worker_defense", entity, attacker)

func _on_health_changed(current_health: float, maximum_health: float) -> void:
	if maximum_health <= 0.0 or current_health / maximum_health > retreat_health_ratio:
		return
	if state == State.PURSUING or state == State.INVESTIGATING:
		_begin_return()

func _broadcast_alert(attacker: Entity) -> void:
	for candidate in entity.get_nearby_entities(alert_radius):
		if candidate == entity or not candidate is Entity:
			continue
		var ally := candidate as Entity
		if entity.global_position.distance_to(ally.global_position) > alert_radius:
			continue
		if not entity.is_teammate(ally):
			continue
		var alert := ally.get_component(AlertComponent) as AlertComponent
		if alert != null:
			alert._respond_to_alert(attacker, attacker.global_position)

func _respond_to_alert(attacker: Entity, known_position: Vector2) -> void:
	if not _is_valid_opponent(attacker):
		return
	if construction_active:
		return
	if role == Role.BUILDER:
		if not _emergency_defense_active:
			_last_known_position = known_position
			_begin_return()
			return
	if _attacker != attacker:
		_pursuit_base_angle = attacker.global_position.direction_to(entity.global_position).angle()
	_attacker = attacker
	_last_known_position = known_position
	_state_remaining = pursuit_duration
	_decision_remaining = 0.0
	state = State.PURSUING
	_log_ai("decision: pursuing %s" % attacker.get_diagnostics_identity())
	if _wander != null:
		_wander.enabled = false
	_combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
	_combat.set_target(attacker)

func _begin_emergency_defense(attacker: Entity) -> void:
	if _normal_projectile_damage < 0.0:
		_normal_projectile_damage = _combat.projectile_damage
	_emergency_defense_active = true
	_combat.projectile_damage = minf(_normal_projectile_damage, 6.0)
	_log_ai("decision: emergency defense against %s" % attacker.get_diagnostics_identity())
	_broadcast_alert(attacker)
	_respond_to_alert(attacker, attacker.global_position)

func _has_available_combat_defender() -> bool:
	var team := entity.get_component(TeamComponent) as TeamComponent
	if team == null:
		return false
	var sandboxes := get_tree().get_nodes_in_group("battle_sandboxes")
	if sandboxes.is_empty() or not sandboxes[0].has_method("has_available_combat_defender"):
		return false
	return bool(sandboxes[0].call("has_available_combat_defender", team.team))

func _update_pursuit(delta: float) -> void:
	_state_remaining -= delta
	if not _is_valid_opponent(_attacker):
		# The original attacker may have died while the battle is still active.
		# Stop treating that individual as the mission objective and resolve the
		# local hostile presence instead.
		_begin_engagement(_last_known_position)
		return
	if _state_remaining <= 0.0:
		_begin_investigation()
		return
	if _wander != null and entity.global_position.distance_to(_wander.get_home_territory_center()) > max_pursuit_distance:
		_begin_leash_wait()
		return
	if _decision_remaining > 0.0:
		return
	_decision_remaining = decision_interval

	var terrain_map := _find_terrain_map()
	var can_see_attacker := terrain_map == null or terrain_map.has_line_of_sight(entity.global_position, _attacker.global_position, _combat.projectile_radius, [_attacker.get_rid()])
	if can_see_attacker:
		_last_known_position = _attacker.global_position
		var firing_standoff := _combat.attack_range * firing_standoff_ratio
		var pursuit_position := _get_pursuit_position(firing_standoff)
		# Each pursuer owns a distinct standoff position. Being inside weapon
		# range is not enough by itself; stopping there makes several units choose
		# the same approach lane and form an immovable clump.
		var distance_to_pursuit_position := entity.global_position.distance_to(pursuit_position)
		if distance_to_pursuit_position > firing_standoff_tolerance:
			_request_move_if_needed(pursuit_position)
		else:
			_movement.stop()
		return

	# The target is hidden. Chase only the last position we actually observed.
	_combat.clear_target("lost_los")
	if entity.global_position.distance_to(_last_known_position) > arrival_distance:
		_request_move_if_needed(_last_known_position)
	else:
		_begin_investigation()

func _begin_engagement(position: Vector2) -> void:
	_engagement_position = position
	_engagement_remaining = engagement_duration
	_attacker = null
	state = State.ENGAGING
	_log_ai("state: ENGAGING at %s" % str(position.round()))
	_decision_remaining = 0.0
	if _wander != null:
		_wander.enabled = false
	_combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
	_combat.clear_target("original_attacker_resolved")
	_update_engagement(0.0)

func _update_engagement(delta: float) -> void:
	_engagement_remaining -= delta
	if _is_low_health():
		_begin_return()
		return
	if _decision_remaining > 0.0:
		return
	_decision_remaining = decision_interval

	# Any visible enemy in weapon range is now a valid combat target. The
	# original attacker is preferred only while it remains alive; it is not the
	# condition that ends the faction response.
	if not is_instance_valid(_combat.target) and _combat.acquire_nearest_visible_target():
		_engagement_remaining = engagement_duration
		return

	var hostile_in_area := false
	for candidate in entity.get_nearby_entities(engagement_radius):
		if candidate is Entity and _is_valid_opponent(candidate):
			hostile_in_area = true
			break

	# Reinforcements converge on the incident briefly, but do not pursue an
	# enemy indefinitely. Once the area is quiet, investigate the last contact.
	if entity.global_position.distance_to(_engagement_position) > arrival_distance:
		if entity.global_position.distance_to(_engagement_position) <= max_pursuit_distance:
			_request_move_if_needed(_engagement_position)
		else:
			_begin_leash_wait()
		return
	if hostile_in_area:
		# A nearby hostile keeps the local incident alive even when terrain or
		# range currently prevents a shot. The next sensing tick can retarget it.
		_engagement_remaining = engagement_duration
		return
	if _engagement_remaining <= 0.0:
		_begin_investigation()

func _begin_investigation() -> void:
	state = State.INVESTIGATING
	_log_ai("state: INVESTIGATING last known position")
	_state_remaining = investigate_duration
	_search_points = _build_search_pattern()
	_search_index = 0
	_search_destination_active = false
	_decision_remaining = 0.0
	_combat.clear_target("investigate")
	_combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
	if _wander != null:
		_wander.enabled = false
	_move_to_next_search_point()

func _update_investigation(delta: float) -> void:
	_state_remaining -= delta
	if not _is_valid_opponent(_attacker):
		_begin_return()
		return
	if _decision_remaining <= 0.0:
		_decision_remaining = decision_interval
		var terrain_map := _find_terrain_map()
		var can_see_attacker := terrain_map == null or terrain_map.has_line_of_sight(entity.global_position, _attacker.global_position, _combat.projectile_radius, [_attacker.get_rid()])
		if can_see_attacker:
			_respond_to_alert(_attacker, _attacker.global_position)
			return
	if not _movement.is_moving() and _search_destination_active:
		_search_destination_active = false
		_search_index += 1
		_move_to_next_search_point()
	if _state_remaining <= 0.0:
		_begin_return()

func _begin_return() -> void:
	state = State.RETURNING
	_log_ai("decision: returning to base")
	_decision_remaining = 0.0
	_end_emergency_defense()
	_combat.clear_target("return_to_base")
	_combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
	if _wander != null:
		_wander.enabled = false
		_wander.restore_home_territory()
		_return_position = _wander.get_home_return_position(entity.global_position)
		_movement.move_to(_return_position)

func _begin_leash_wait() -> void:
	state = State.WAITING_AT_LEASH
	_log_ai("decision: pursuit leash reached; waiting")
	_state_remaining = leash_wait_duration
	_combat.clear_target("pursuit_leash")
	_combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
	_movement.stop()
	if _wander != null:
		_wander.enabled = false

func _update_leash_wait(delta: float) -> void:
	_state_remaining -= delta
	if _state_remaining <= 0.0:
		_begin_return()

func _update_return() -> void:
	if _wander != null and entity.global_position.distance_to(_return_position) <= arrival_distance:
		state = State.IDLE
		_log_ai("state: IDLE; returned to territory")
		_attacker = null
		_combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION if role == Role.BUILDER else CombatComponent.AUTO_ATTACK_MOVE)
		_wander.enabled = true

func _request_move_if_needed(destination: Vector2, minimum_repath_distance: float = 32.0) -> void:
	var current_destination: Variant = _movement.get_destination_position()
	if _movement.is_moving() and current_destination is Vector2:
		if (current_destination as Vector2).distance_to(destination) <= minimum_repath_distance:
			return
	_movement.move_to(destination)

func _end_emergency_defense() -> void:
	if not _emergency_defense_active:
		return
	_emergency_defense_active = false
	if _normal_projectile_damage >= 0.0:
		_combat.projectile_damage = _normal_projectile_damage

func _build_search_pattern() -> Array[Vector2]:
	var points: Array[Vector2] = [_last_known_position]
	var offsets := [
		Vector2(1.0, 0.0),
		Vector2(-1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(0.0, -1.0),
	]
	for offset in offsets:
		points.append(_last_known_position + offset * investigate_radius * 0.65)
	return points

func _move_to_next_search_point() -> void:
	if _search_index >= _search_points.size():
		return
	var destination := _search_points[_search_index]
	_log_ai("action: searching point %d/%d at %s" % [_search_index + 1, _search_points.size(), str(destination.round())])
	_movement.move_to(destination)
	_search_destination_active = _movement.get_destination_position() != null
	if not _search_destination_active:
		_search_index += 1
		_move_to_next_search_point()

func _get_pursuit_position(standoff_distance: float) -> Vector2:
	var pursuers: Array[AlertComponent] = []
	for candidate in entity.get_nearby_entities(maxf(_combat.attack_range, pursuit_spacing) + 160.0):
		if not candidate is Entity:
			continue
		var ally := candidate as Entity
		if not entity.is_teammate(ally):
			continue
		var alert := ally.get_component(AlertComponent) as AlertComponent
		if alert != null and alert.state == State.PURSUING and alert._attacker == _attacker:
			pursuers.append(alert)
	pursuers.sort_custom(func(first: AlertComponent, second: AlertComponent) -> bool:
		return first.entity.get_instance_id() < second.entity.get_instance_id()
	)
	var slot_index := pursuers.find(self)
	if slot_index < 0:
		slot_index = 0
	var angular_spread := clampf(pursuit_spacing / maxf(standoff_distance, 1.0), 0.25, 0.8)
	var angle_offset := (float(slot_index) - float(pursuers.size() - 1) * 0.5) * angular_spread
	return _attacker.global_position + Vector2.RIGHT.rotated(_pursuit_base_angle + flank_angle_bias + angle_offset) * standoff_distance

func _is_low_health() -> bool:
	var health := entity.get_component(HealthComponent) as HealthComponent
	return health != null and health.maximum_health > 0.0 and health.current_health / health.maximum_health <= retreat_health_ratio

func _is_valid_opponent(candidate: Variant) -> bool:
	# A typed Entity variable can still refer to an object that has been freed.
	# Keep this parameter untyped so validity/type checks happen before Godot
	# attempts to pass the value through an Entity-typed function boundary.
	if candidate == null or not is_instance_valid(candidate) or not candidate is Entity or candidate == entity:
		return false
	var own_team := entity.get_component(TeamComponent) as TeamComponent
	var other_entity := candidate as Entity
	var other_team := other_entity.get_component(TeamComponent) as TeamComponent
	return own_team != null and other_team != null and own_team.team != other_team.team

func _log_ai(message: String) -> void:
	if entity != null:
		var position := entity.global_position
		RuntimeLogger.debug("%s, [world=(%8.1f, %8.1f)] - %s" % [entity.get_diagnostics_identity(), position.x, position.y, message])

func _find_terrain_map() -> TerrainMap:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	return null if maps.is_empty() else maps[0] as TerrainMap
