extends Simulation

# Intrusive diagnostics only: never admitted to the compact kernel. Native
# methods own every mutation. Aliases/RNG identities are transferred unchanged.
var metrics: Dictionary = {"cycle_calls": 0, "cycle_usec": 0, "completion_usec": 0, "completions": 0, "crafting_completions": 0, "forge_completions": 0, "auto_attempts": 0, "auto_successes": 0, "crafting_active_ticks": 0, "crafting_progress_ticks": 0, "crafting_no_progress_ticks": 0}

class GenerationProbe extends RelicGenerationManager:
	var timings: Dictionary = {"generation_calls": 0, "generation_usec": 0}
	func generate_relic(tier: int, rng: RandomNumberGenerator, chance: float = 0.0, forced: String = "") -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super(tier, rng, chance, forced)
		timings["generation_calls"] += 1
		timings["generation_usec"] += Time.get_ticks_usec() - started
		return result

class InventoryProbe extends RelicManager:
	var timings: Dictionary = {"recipe_calls": 0, "recipe_usec": 0, "item_calls": 0, "item_usec": 0, "random_reward_calls": 0, "random_reward_usec": 0}
	func _init(source: RelicManager) -> void:
		super(source._gameplay_rng)
		inventory = source.inventory
		inventory_positions = source.inventory_positions
		machine_slots = source.machine_slots
		equipped = source.equipped
		_next_instance_number = source._next_instance_number
		_next_item_instance_number = source._next_item_instance_number
		generation_manager = GenerationProbe.new()
	func consume_crafting_recipe(id: String, requirements: Array[Dictionary]) -> bool:
		var started: int = Time.get_ticks_usec()
		var result: bool = super(id, requirements)
		timings["recipe_calls"] += 1
		timings["recipe_usec"] += Time.get_ticks_usec() - started
		return result
	func add_stackable_item(id: String, quantity: int) -> int:
		var started: int = Time.get_ticks_usec()
		var result: int = super(id, quantity)
		timings["item_calls"] += 1
		timings["item_usec"] += Time.get_ticks_usec() - started
		return result
	func add_random_relic_for_tier(tier: int, chance: float = 0.0, forced: String = "") -> String:
		var started: int = Time.get_ticks_usec()
		var result: String = super(tier, chance, forced)
		timings["random_reward_calls"] += 1
		timings["random_reward_usec"] += Time.get_ticks_usec() - started
		return result


func _init(target: GameState) -> void:
	super(target)
	state.relic_manager = InventoryProbe.new(state.relic_manager)


func update_cycle_generator(generator: Generator, delta: float, offline_mode: bool = false, heat_upgrade_multiplier: float = -1.0) -> void:
	var active_before: bool = generator.cycle_active
	var progress_before: float = generator.cycle_progress
	var completions_before: int = metrics["completions"]
	var started: int = Time.get_ticks_usec()
	super(generator, delta, offline_mode, heat_upgrade_multiplier)
	metrics["cycle_calls"] += 1
	metrics["cycle_usec"] += Time.get_ticks_usec() - started
	if generator.definition.id == "relic_shard_extractor" and (active_before or generator.cycle_active or metrics["completions"] > completions_before):
		metrics["crafting_active_ticks"] += 1
		if generator.cycle_progress != progress_before or metrics["completions"] > completions_before:
			metrics["crafting_progress_ticks"] += 1
		else:
			metrics["crafting_no_progress_ticks"] += 1


func complete_cycle(generator: Generator) -> void:
	var started: int = Time.get_ticks_usec()
	super(generator)
	metrics["completions"] += 1
	metrics["completion_usec"] += Time.get_ticks_usec() - started
	metrics["crafting_completions" if generator.definition.id == "relic_shard_extractor" else "forge_completions"] += 1


func buy_generator(id: String, source: String = "manual") -> bool:
	var result: bool = super(id, source)
	if source == "cycle_auto_run":
		metrics["auto_attempts"] += 1
		metrics["auto_successes"] += 1 if result else 0
	return result
