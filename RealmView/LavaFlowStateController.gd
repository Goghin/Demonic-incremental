class_name LavaFlowStateController
extends RefCounted


var _validated_layout_instance_id: int = 0
# Tracks the logical activation decision separately from the animation state.
# This lets threshold hysteresis remain stable while a visual transition runs.
var _desired_flow_states: Dictionary = {}


func update(
	state: GameState,
	realm_layout: RealmLayout,
	lava_lakes: Array[LavaLake],
	lava_flows: Array[LavaFlow],
	lava_falls: Array[LavaFall]
) -> void:
	if state == null or realm_layout == null:
		return

	var layout_instance_id: int = realm_layout.get_instance_id()
	if layout_instance_id != _validated_layout_instance_id:
		_desired_flow_states.clear()
	_validate_layout_thresholds(realm_layout)

	if lava_lakes.is_empty():
		return

	var lake: LavaLake = lava_lakes[0]

	if not is_instance_valid(lake):
		return

	var lake_fill: float = lake.fill

	var flow_count: int = min(
		lava_flows.size(),
		realm_layout.lava_flow_definitions.size()
	)

	for i in range(flow_count):
		var flow: LavaFlow = lava_flows[i]

		if not is_instance_valid(flow):
			continue

		var definition: Dictionary = (
			realm_layout.lava_flow_definitions[i]
		)

		var configured_start_fill: float = definition["start_fill"]
		var configured_stop_fill: float = definition["stop_fill"]

		# Keep runtime behavior robust if a layout is authored incorrectly.
		# _validate_layout_thresholds() reports reversed pairs once per layout.
		var start_fill: float = maxf(configured_start_fill, configured_stop_fill)
		var stop_fill: float = minf(configured_start_fill, configured_stop_fill)

		var requires_flow: int = definition.get("requires_flow", -1)

		var dependency_ready: bool = true

		if requires_flow >= 0:
			if requires_flow >= lava_flows.size():
				dependency_ready = false
			else:
				var required_flow: LavaFlow = lava_flows[requires_flow]

				if not is_instance_valid(required_flow):
					dependency_ready = false
				else:
					dependency_ready = (
						required_flow.flow_state ==
						LavaFlow.FlowState.FLOWING
					)

		var was_desired_active: bool = bool(
			_desired_flow_states.get(
				i,
				flow.flow_state == LavaFlow.FlowState.FLOWING
			)
		)
		var should_flow: bool

		if was_desired_active:
			# Preserve hysteresis even while the visual animation is starting
			# or stopping: an active flow uses the lower stop threshold.
			should_flow = lake_fill >= stop_fill
		else:
			# A new activation still waits for its configured start threshold
			# and any required upstream flow to become fully established.
			should_flow = lake_fill >= start_fill and dependency_ready

		_desired_flow_states[i] = should_flow
		flow.set_active(should_flow)

		if i < lava_falls.size():
			var fall: LavaFall = lava_falls[i]

			if is_instance_valid(fall):
				# Multiple fronts can overlap in time. Keep the fall filled
				# while any visible front still reaches the channel endpoint.
				fall.set_filled(flow.is_endpoint_covered())


func _validate_layout_thresholds(realm_layout: RealmLayout) -> void:
	var layout_instance_id: int = realm_layout.get_instance_id()

	if layout_instance_id == _validated_layout_instance_id:
		return

	_validated_layout_instance_id = layout_instance_id

	for i in range(realm_layout.lava_flow_definitions.size()):
		var definition: Dictionary = realm_layout.lava_flow_definitions[i]

		if not definition.has("start_fill") or not definition.has("stop_fill"):
			continue

		var start_fill: float = definition["start_fill"]
		var stop_fill: float = definition["stop_fill"]

		if start_fill <= stop_fill:
			push_warning(
				(
					"Realm layout '%s' lava flow %d has invalid thresholds: " +
					"start_fill (%s) should be greater than stop_fill (%s)."
				) %
				[realm_layout.resource_path, i, start_fill, stop_fill]
			)
