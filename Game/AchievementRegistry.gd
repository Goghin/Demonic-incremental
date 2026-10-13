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

	# Industry: number of different generators unlocked across all Realms.
	{
		"id": "industry_1",
		"line_id": "industry",
		"line_title": "Infernal Civilization",
		"title": "A Machine Awakens",
		"description": "Unlock your first generator.",
		"progress_type": "unique_generators",
		"target": 1.0
	},
	{
		"id": "industry_2",
		"line_id": "industry",
		"line_title": "Infernal Civilization",
		"title": "Growing Industry",
		"description": "Unlock 3 different generators across all Realms.",
		"progress_type": "unique_generators",
		"target": 3.0
	},
	{
		"id": "industrial_revolution",
		"line_id": "industry",
		"line_title": "Infernal Civilization",
		"title": "Industrial Revolution",
		"description": "Unlock 5 different generators across all Realms.",
		"progress_type": "unique_generators",
		"target": 5.0
	},
	{
		"id": "industry_4",
		"line_id": "industry",
		"line_title": "Infernal Civilization",
		"title": "Engines of the Abyss",
		"description": "Unlock 6 different generators across all Realms.",
		"progress_type": "unique_generators",
		"target": 6.0
	},
	{
		"id": "industry_5",
		"line_id": "industry",
		"line_title": "Infernal Civilization",
		"title": "The Great Machine",
		"description": "Unlock all 7 generators.",
		"progress_type": "unique_generators",
		"target": 7.0
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
		"id": "eternal_flame_5",
		"line_id": "eternal_flame",
		"line_title": "Eternal Ascension",
		"title": "The Undying",
		"description": "Earn 500 Eternal Flames.",
		"progress_type": "eternal_flame",
		"target": 500.0
	},

	# Crystallized Flame: cumulative total earned across all Realms.
	{
		"id": "crystallized_flame_1",
		"line_id": "crystallized_flame",
		"line_title": "Eternal Embers",
		"title": "A Spark Preserved",
		"description": "Earn 1 Crystallized Flame in total.",
		"progress_type": "total_crystallized_flame",
		"target": 1.0
	},
	{
		"id": "crystallized_flame_2",
		"line_id": "crystallized_flame",
		"line_title": "Eternal Embers",
		"title": "Ember Collector",
		"description": "Earn 10 Crystallized Flames in total.",
		"progress_type": "total_crystallized_flame",
		"target": 10.0
	},
	{
		"id": "crystallized_flame_3",
		"line_id": "crystallized_flame",
		"line_title": "Eternal Embers",
		"title": "Flame Hoarder",
		"description": "Earn 100 Crystallized Flames in total.",
		"progress_type": "total_crystallized_flame",
		"target": 100.0
	},
	{
		"id": "crystallized_flame_4",
		"line_id": "crystallized_flame",
		"line_title": "Eternal Embers",
		"title": "A Thousand Embers",
		"description": "Earn 1,000 Crystallized Flames in total.",
		"progress_type": "total_crystallized_flame",
		"target": 1000.0
	},
	{
		"id": "crystallized_flame_5",
		"line_id": "crystallized_flame",
		"line_title": "Eternal Embers",
		"title": "The Eternal Pyre",
		"description": "Earn 10,000 Crystallized Flames in total.",
		"progress_type": "total_crystallized_flame",
		"target": 10000.0
	}
]


static func get_definitions() -> Array[Dictionary]:
	return DEFINITIONS.duplicate(true)


static func get_definition(achievement_id: String) -> Dictionary:
	for definition in DEFINITIONS:
		if str(definition.get("id", "")) == achievement_id:
			return definition.duplicate(true)

	return {}
