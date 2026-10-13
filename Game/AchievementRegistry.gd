class_name AchievementRegistry
extends RefCounted


# Achievement tiers are grouped into progression lines. IDs from the original
# achievements are intentionally preserved so existing saves keep their unlocks.
const DEFINITIONS: Array[Dictionary] = [
	# Heat: lifetime production.
	{
		"id": "first_spark",
		"line_id": "heat",
		"line_title": "The Eternal Furnace",
		"title": "First Spark",
		"description": "Produce 1,000 Heat in total.",
		"progress_type": "resource_produced",
		"resource_id": ResourceIds.HEAT,
		"target": 1000.0
	},
	{
		"id": "heat_production_2",
		"line_id": "heat",
		"line_title": "The Eternal Furnace",
		"title": "Burning Bright",
		"description": "Produce 1 million Heat in total.",
		"progress_type": "resource_produced",
		"resource_id": ResourceIds.HEAT,
		"target": 1000000.0
	},
	{
		"id": "heat_production_3",
		"line_id": "heat",
		"line_title": "The Eternal Furnace",
		"title": "Infernal Industry",
		"description": "Produce 1 billion Heat in total.",
		"progress_type": "resource_produced",
		"resource_id": ResourceIds.HEAT,
		"target": 1000000000.0
	},
	{
		"id": "heat_production_4",
		"line_id": "heat",
		"line_title": "The Eternal Furnace",
		"title": "A Realm Ablaze",
		"description": "Produce 1 trillion Heat in total.",
		"progress_type": "resource_produced",
		"resource_id": ResourceIds.HEAT,
		"target": 1000000000000.0
	},
	{
		"id": "heat_production_5",
		"line_id": "heat",
		"line_title": "The Eternal Furnace",
		"title": "Heart of the Inferno",
		"description": "Produce 1 quadrillion Heat in total.",
		"progress_type": "resource_produced",
		"resource_id": ResourceIds.HEAT,
		"target": 1000000000000000.0
	},

	# Matter: lifetime production, so spending or decay does not undo progress.
	{
		"id": "matter_matters",
		"line_id": "matter",
		"line_title": "Material Dominion",
		"title": "Matter Matters",
		"description": "Produce 1,000 Matter in total.",
		"progress_type": "resource_produced",
		"resource_id": ResourceIds.MATTER,
		"target": 1000.0
	},
	{
		"id": "matter_production_2",
		"line_id": "matter",
		"line_title": "Material Dominion",
		"title": "Solid Foundations",
		"description": "Produce 1 million Matter in total.",
		"progress_type": "resource_produced",
		"resource_id": ResourceIds.MATTER,
		"target": 1000000.0
	},
	{
		"id": "matter_production_3",
		"line_id": "matter",
		"line_title": "Material Dominion",
		"title": "Matter Made Manifest",
		"description": "Produce 1 billion Matter in total.",
		"progress_type": "resource_produced",
		"resource_id": ResourceIds.MATTER,
		"target": 1000000000.0
	},
	{
		"id": "matter_production_4",
		"line_id": "matter",
		"line_title": "Material Dominion",
		"title": "Mountain of Matter",
		"description": "Produce 1 trillion Matter in total.",
		"progress_type": "resource_produced",
		"resource_id": ResourceIds.MATTER,
		"target": 1000000000000.0
	},
	{
		"id": "matter_production_5",
		"line_id": "matter",
		"line_title": "Material Dominion",
		"title": "Material Singularity",
		"description": "Produce 1 quadrillion Matter in total.",
		"progress_type": "resource_produced",
		"resource_id": ResourceIds.MATTER,
		"target": 1000000000000000.0
	},

	# Prestige: lifetime number of smashed Realms.
	{
		"id": "into_the_void",
		"line_id": "prestige",
		"line_title": "Beyond the Realm",
		"title": "Into the Void",
		"description": "Smash your first Realm.",
		"progress_type": "prestige_count",
		"target": 1.0
	},
	{
		"id": "prestige_count_2",
		"line_id": "prestige",
		"line_title": "Beyond the Realm",
		"title": "A Habit of Destruction",
		"description": "Smash 5 Realms.",
		"progress_type": "prestige_count",
		"target": 5.0
	},
	{
		"id": "prestige_count_3",
		"line_id": "prestige",
		"line_title": "Beyond the Realm",
		"title": "Worldbreaker",
		"description": "Smash 25 Realms.",
		"progress_type": "prestige_count",
		"target": 25.0
	},
	{
		"id": "prestige_count_4",
		"line_id": "prestige",
		"line_title": "Beyond the Realm",
		"title": "The Realm Reaper",
		"description": "Smash 100 Realms.",
		"progress_type": "prestige_count",
		"target": 100.0
	},
	{
		"id": "prestige_count_5",
		"line_id": "prestige",
		"line_title": "Beyond the Realm",
		"title": "Master of Ruin",
		"description": "Smash 500 Realms.",
		"progress_type": "prestige_count",
		"target": 500.0
	},

	# Industry: total levels currently owned across all generators.
	{
		"id": "industry_1",
		"line_id": "industry",
		"line_title": "Infernal Civilization",
		"title": "A Machine Awakens",
		"description": "Own 10 generator levels in total.",
		"progress_type": "total_generator_levels",
		"target": 10.0
	},
	{
		"id": "industry_2",
		"line_id": "industry",
		"line_title": "Infernal Civilization",
		"title": "Growing Industry",
		"description": "Own 25 generator levels in total.",
		"progress_type": "total_generator_levels",
		"target": 25.0
	},
	{
		"id": "industrial_revolution",
		"line_id": "industry",
		"line_title": "Infernal Civilization",
		"title": "Industrial Revolution",
		"description": "Own 50 generator levels in total.",
		"progress_type": "total_generator_levels",
		"target": 50.0
	},
	{
		"id": "industry_4",
		"line_id": "industry",
		"line_title": "Infernal Civilization",
		"title": "Engines of the Abyss",
		"description": "Own 100 generator levels in total.",
		"progress_type": "total_generator_levels",
		"target": 100.0
	},
	{
		"id": "industry_5",
		"line_id": "industry",
		"line_title": "Infernal Civilization",
		"title": "The Great Machine",
		"description": "Own 250 generator levels in total.",
		"progress_type": "total_generator_levels",
		"target": 250.0
	},

	# Eternal Flame: total earned, unaffected by spending or assignment.
	{
		"id": "eternal_flame",
		"line_id": "eternal_flame",
		"line_title": "Eternal Ascension",
		"title": "Eternal Flame",
		"description": "Earn your first Eternal Flame.",
		"progress_type": "eternal_flame",
		"target": 1.0
	},
	{
		"id": "eternal_flame_2",
		"line_id": "eternal_flame",
		"line_title": "Eternal Ascension",
		"title": "A Lasting Ember",
		"description": "Earn 5 Eternal Flames.",
		"progress_type": "eternal_flame",
		"target": 5.0
	},
	{
		"id": "eternal_flame_3",
		"line_id": "eternal_flame",
		"line_title": "Eternal Ascension",
		"title": "Flamebearer",
		"description": "Earn 25 Eternal Flames.",
		"progress_type": "eternal_flame",
		"target": 25.0
	},
	{
		"id": "eternal_flame_4",
		"line_id": "eternal_flame",
		"line_title": "Eternal Ascension",
		"title": "Immortal Pyre",
		"description": "Earn 100 Eternal Flames.",
		"progress_type": "eternal_flame",
		"target": 100.0
	},
	{
		"id": "eternal_flame_5_lifetime_10000",
		"line_id": "eternal_flame",
		"line_title": "Eternal Ascension",
		"title": "Eternal Ascendant",
		"description": "Earn 10,000 Eternal Flames in total, including Flames spent.",
		"progress_type": "eternal_flame",
		"target": 10000.0
	},

	# Crystallized Flame: highest amount reached in a single Realm run.
	{
		"id": "crystallized_run_1",
		"line_id": "crystallized_flame",
		"line_title": "Eternal Embers",
		"title": "A Spark Preserved",
		"description": "Reach 1 Crystallized Flame in a single Realm.",
		"progress_type": "highest_crystallized_flame_this_run",
		"target": 1.0
	},
	{
		"id": "crystallized_run_2",
		"line_id": "crystallized_flame",
		"line_title": "Eternal Embers",
		"title": "Kindled Embers",
		"description": "Reach 10 Crystallized Flames in a single Realm.",
		"progress_type": "highest_crystallized_flame_this_run",
		"target": 10.0
	},
	{
		"id": "crystallized_run_3",
		"line_id": "crystallized_flame",
		"line_title": "Eternal Embers",
		"title": "Burning Core",
		"description": "Reach 50 Crystallized Flames in a single Realm.",
		"progress_type": "highest_crystallized_flame_this_run",
		"target": 50.0
	},
	{
		"id": "crystallized_run_4",
		"line_id": "crystallized_flame",
		"line_title": "Eternal Embers",
		"title": "Eternal Pyre",
		"description": "Reach 200 Crystallized Flames in a single Realm.",
		"progress_type": "highest_crystallized_flame_this_run",
		"target": 200.0
	},
	{
		"id": "crystallized_run_5",
		"line_id": "crystallized_flame",
		"line_title": "Eternal Embers",
		"title": "Beyond the Crucible",
		"description": "Reach 500 Crystallized Flames in a single Realm.",
		"progress_type": "highest_crystallized_flame_this_run",
		"target": 500.0
	}
]


static func get_definitions() -> Array[Dictionary]:
	return DEFINITIONS.duplicate(true)


static func get_definition(achievement_id: String) -> Dictionary:
	for definition in DEFINITIONS:
		if str(definition.get("id", "")) == achievement_id:
			return definition.duplicate(true)

	return {}
