class_name ResourceThresholdRegistry
extends RefCounted


# Central configuration for resource thresholds.
# Base thresholds apply before any threshold upgrades are purchased.
# Each upgrade contributes its configured increment per level.
static func get_definitions() -> Dictionary:
	return {
		ResourceIds.HEAT: {
			"base_threshold": 0.0,
			"starting_levels": {
				"heat_threshold_line_1": 1
			},
			"upgrades": [
				{
					"id": "heat_threshold_line_1",
					"display_name": "Heat Retention I",
					"description": "Increases the base Heat leak threshold by 1,000 per level.",
					"increment": 1000.0,
					"cost": 600.0,
					"max_level": 10,
					"cost_multiplier": 1.5
				},
				{
					"id": "heat_threshold_line_2",
					"display_name": "Heat Retention II",
					"description": "Increases the base Heat leak threshold by 10,000 per level.",
					"increment": 10000.0,
					"cost": 30000.0,
					"max_level": 10,
					"cost_multiplier": 1.5
				}
			]
		},
		ResourceIds.MATTER: {
			"base_threshold": 0.0,
			"starting_levels": {
				"matter_threshold_line_1": 1
			},
			"upgrades": [
				{
					"id": "matter_threshold_line_1",
					"display_name": "Matter Preservation I",
					"description": "Increases the base Matter decay threshold by 100 per level.",
					"increment": 100.0,
					"cost": 50.0,
					"max_level": 10,
					"cost_multiplier": 1.4
				},
				{
					"id": "matter_threshold_line_2",
					"display_name": "Matter Preservation II",
					"description": "Increases the base Matter decay threshold by 1,000 per level.",
					"increment": 1000.0,
					"cost": 1500.0,
					"max_level": 10,
					"cost_multiplier": 1.5
				}
			]
		},
		ResourceIds.ASH: {
			"base_threshold": 1.0,
			"starting_levels": {},
			"upgrades": [
				{
					"id": "ash_threshold_line_1",
					"display_name": "Ash Filtration I",
					"description": "Raises the Ash contamination threshold by 9 per level.",
					"increment": 9.0,
					"cost": 25.0,
					"max_level": 10,
					"cost_multiplier": 1.5
				},
				{
					"id": "ash_threshold_line_2",
					"display_name": "Ash Filtration II",
					"description": "Raises the Ash contamination threshold by 40 per level.",
					"increment": 40.0,
					"cost": 250.0,
					"max_level": 10,
					"cost_multiplier": 1.6
				}
			]
		}
	}
