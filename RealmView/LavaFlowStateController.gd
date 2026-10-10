class_name LavaFlowStateController
extends RefCounted


func update(
	state: GameState,
	realm_layout: RealmLayout,
	lava_lakes: Array[LavaLake],
	lava_flows: Array[LavaFlow],
	lava_falls: Array[LavaFall]
) -> void:
	if state == null:
		return

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

		var start_fill: float = definition["start_fill"]
		var stop_fill: float = definition["stop_fill"]
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

		var should_flow: bool = false

		if flow.flow_state == LavaFlow.FlowState.FLOWING:
			should_flow = lake_fill >= stop_fill
		else:
			should_flow = (
				lake_fill >= start_fill
				and dependency_ready
			)

		flow.set_active(should_flow)

		if i < lava_falls.size():
			var fall: LavaFall = lava_falls[i]

			if is_instance_valid(fall):
				var endpoint_filled: bool = (
					flow.flow_state == LavaFlow.FlowState.FLOWING
				)

				if flow.flow_state == LavaFlow.FlowState.STOPPING:
					endpoint_filled = flow.cooling_length < 1.0

				fall.set_filled(endpoint_filled)
