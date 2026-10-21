class_name TutorialManager
extends Node

signal tutorial_requested(tutorial_id: String, title: String, message: String)

const SAVE_PATH := "user://tutorial_progress.json"

const TUTORIALS := {
	"navigation_generators": {
		"title": "THE MACHINERY",
		"message": "This is the heart of your operation. Select machines, buy levels, and unlock new generators to increase production. Every machine has its own costs and role in the realm."
	},
	"navigation_upgrades": {
		"title": "MAKE THE MACHINERY BETTER",
		"message": "Upgrades improve your production and can unlock new mechanics. Some affect your whole realm, while others specialize a particular generator. Check their effects before spending your hard-earned resources."
	},
	"navigation_stats": {
		"title": "WHAT THE NUMBERS MEAN",
		"message": "The Stats panel shows how your realm is performing, including production, multipliers, and resource losses. When something changes unexpectedly, this is a good place to investigate."
	},
	"navigation_realm": {
		"title": "THE CYCLE OF REALMS",
		"message": "The Realm panel is where you prepare for and perform a Smash, spend your prestige rewards, and plan the next realm. A reset costs your current run's progress, so check the rewards and your choices before committing."
	},
	"navigation_achievements": {
		"title": "PROOF OF YOUR DEPRAVITY",
		"message": "Achievements record milestones you've reached and give you goals to pursue. Check back as your realm grows; some accomplishments will happen naturally, while others reward deliberate planning."
	},
	"matter_decay_started": {
		"title": "MATTER ISN'T FOREVER",
		"message": "Your Matter has crossed its decay threshold, so some of it is now being lost over time. The threshold is shown in your realm's mechanics and can be raised by upgrades and Density. Check the Stats panel to see how much Matter you're losing, and consider whether more production or a higher threshold would help."
	},
	"first_generator_purchase": {
		"title": "A WORD FROM YOUR INFERNAL INTERN",
		"message": "Excellent! You have made the machinery obey. Generators produce resources over time, and each new level improves their output. Keep an eye on the cost before buying more. I would explain the finer points, but I have a very small attention span."
	},
	"unlock_molecular_agitation": {
		"title": "MOLECULAR AGITATION",
		"message": "The atoms are getting restless. Molecular Agitation is now available! Inspect its panel to see what it produces and what each level costs. More machinery means more production, but the price of obedience rises with every purchase."
	},
	"unlock_lava_mite_colony": {
		"title": "A COLONY OF TINY MENACES",
		"message": "Lava mites! Horrible little workers, excellent employees. Your Lava Mite Colony is ready. Check its panel for its output and costs, and keep an eye on its condition as your realm develops. I would supervise them, but they bite."
	},
	"unlock_thermal_furnace": {
		"title": "INFERNAL CONDENSATION",
		"message": "A furnace that makes the realm's processes a little less primitive. Infernal Condensation is unlocked. Review its panel before investing: each machine has its own costs and production, so choose where your resources will do the most good."
	},
	"unlock_matter_furnace": {
		"title": "THE MATTER FURNACE",
		"message": "Now we're cooking with... matter. The Matter Furnace is available. Take a look at its panel to understand its role in your production chain, and remember: spending resources here means you have less available for other machines and upgrades."
	},
	"unlock_thermal_compressor": {
		"title": "SQUEEZE THE REALM",
		"message": "Behold, the Thermal Compressor! Compression adds another tool to your industrial nightmare. Check its panel and available upgrades to learn what it can do in your current setup. Please don't ask me to demonstrate; I have delicate bones."
	},
	"unlock_infernal_forge": {
		"title": "THE INFERNAL FORGE",
		"message": "At last, a proper forge. The Infernal Forge processes Matter into Ash and Crystallized Flames over time. Its cycle takes patience, and Ash contamination can interfere with its operation. Feed it wisely, and don't stand too close when it finishes."
	}
}

var completed_tutorials: Dictionary = {}
var pending_tutorials: Array[String] = []
var active_tutorial_id: String = ""


func _ready() -> void:
	_load_progress()


func notify_event(event_id: String) -> void:
	var tutorial_id := ""
	match event_id:
		"matter_decay_started":
			tutorial_id = "matter_decay_started"
		"first_generator_purchase":
			tutorial_id = "first_generator_purchase"
		"navigation_generators":
			tutorial_id = "navigation_generators"
		"navigation_upgrades":
			tutorial_id = "navigation_upgrades"
		"navigation_stats":
			tutorial_id = "navigation_stats"
		"navigation_realm":
			tutorial_id = "navigation_realm"
		"navigation_achievements":
			tutorial_id = "navigation_achievements"
		"generator_unlocked:molecular_agitation":
			tutorial_id = "unlock_molecular_agitation"
		"generator_unlocked:lava_mite_colony":
			tutorial_id = "unlock_lava_mite_colony"
		"generator_unlocked:thermal_furnace":
			tutorial_id = "unlock_thermal_furnace"
		"generator_unlocked:matter_furnace":
			tutorial_id = "unlock_matter_furnace"
		"generator_unlocked:thermal_compressor":
			tutorial_id = "unlock_thermal_compressor"
		"generator_unlocked:infernal_forge":
			tutorial_id = "unlock_infernal_forge"
		_:
			return

	if completed_tutorials.get(tutorial_id, false):
		return
	if active_tutorial_id == tutorial_id or pending_tutorials.has(tutorial_id):
		return

	pending_tutorials.append(tutorial_id)
	_show_next_tutorial()


func complete_tutorial(tutorial_id: String) -> void:
	if tutorial_id == "":
		return

	completed_tutorials[tutorial_id] = true
	if active_tutorial_id == tutorial_id:
		active_tutorial_id = ""
	_save_progress()
	_show_next_tutorial()


func _show_next_tutorial() -> void:
	if active_tutorial_id != "" or pending_tutorials.is_empty():
		return

	active_tutorial_id = pending_tutorials.pop_front()
	var tutorial: Dictionary = TUTORIALS.get(active_tutorial_id, {})
	if tutorial.is_empty():
		active_tutorial_id = ""
		_show_next_tutorial()
		return

	tutorial_requested.emit(
		active_tutorial_id,
		str(tutorial.get("title", "INFERNAL INTERN")),
		str(tutorial.get("message", "Something has gone wrong in the tutorial archives."))
	)


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed := JSON.new()
	var result := parsed.parse(file.get_as_text())
	file.close()
	if result != OK or not parsed.data is Dictionary:
		return

	var saved_completed: Variant = parsed.data.get("completed_tutorials", {})
	if saved_completed is Dictionary:
		completed_tutorials = saved_completed


func _save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save tutorial progress.")
		return

	file.store_string(JSON.stringify({
		"completed_tutorials": completed_tutorials
	}))
	file.close()

func get_archive_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for tutorial_id in TUTORIALS:
		if not completed_tutorials.get(tutorial_id, false):
			continue
		var tutorial: Dictionary = TUTORIALS[tutorial_id]
		entries.append({
			"id": tutorial_id,
			"title": str(tutorial.get("title", "INFERNAL INTERN")),
			"message": str(tutorial.get("message", ""))
		})
	return entries


func replay_tutorial(tutorial_id: String) -> void:
	if not completed_tutorials.get(tutorial_id, false):
		return
	var tutorial: Dictionary = TUTORIALS.get(tutorial_id, {})
	if tutorial.is_empty():
		return
	if active_tutorial_id != "":
		return
	active_tutorial_id = tutorial_id
	tutorial_requested.emit(
		tutorial_id,
		str(tutorial.get("title", "INFERNAL INTERN")),
		str(tutorial.get("message", ""))
	)

