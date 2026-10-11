class_name LavaRealmVisualController
extends RefCounted


var flows: Array[LavaFlow] = []
var falls: Array[LavaFall] = []
var lakes: Array[LavaLake] = []

var flow_state_controller: LavaFlowStateController = LavaFlowStateController.new()
var lake_state_controller: LavaLakeStateController = LavaLakeStateController.new()
var lake_visual_controller: LavaLakeVisualController = LavaLakeVisualController.new()
var network_controller: LavaNetworkController = LavaNetworkController.new()


func create_network(
	owner: Node,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	flow_scene: PackedScene,
	fall_scene: PackedScene
) -> void:
	network_controller.create_network(
		owner,
		realm_layout,
		island_rect,
		flows,
		falls,
		flow_scene,
		fall_scene
	)


func create_lakes(
	owner: Node,
	state: GameState,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	lake_scene: PackedScene
) -> void:
	lake_visual_controller.create_lakes(
		owner,
		state,
		realm_layout,
		island_rect,
		lake_scene,
		lakes
	)


func update_positions(
	realm_layout: RealmLayout,
	island_rect: Rect2
) -> void:
	network_controller.update_positions(
		realm_layout,
		island_rect,
		flows,
		falls
	)
	lake_visual_controller.update_positions(
		island_rect,
		lakes
	)


func update_lakes(
	state: GameState,
	realm_layout: RealmLayout
) -> void:
	lake_state_controller.update(
		state,
		realm_layout,
		lakes
	)


func update_flow_states(
	state: GameState,
	realm_layout: RealmLayout
) -> void:
	flow_state_controller.update(
		state,
		realm_layout,
		lakes,
		flows,
		falls
	)


func update_dynamic_states(
	state: GameState,
	realm_layout: RealmLayout
) -> void:
	# Flow activation depends on the main lake's updated fill value.
	update_lakes(state, realm_layout)
	update_flow_states(state, realm_layout)
