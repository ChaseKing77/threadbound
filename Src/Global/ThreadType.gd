extends Node

## Global singleton for archetype constants
## Provides centralized access to archetype names, colors, and configuration

# Archetype name constants
const RED: String = "Red"
const BLUE: String = "Blue"
const YELLOW: String = "Yellow"

# Archetype color constants
const RED_COLOR: Color = Color(1, 0, 0, 1)
const BLUE_COLOR: Color = Color(0, 0, 1, 1)
const YELLOW_COLOR: Color = Color(1, 1, 0, 1)

# Dictionary mapping archetype names to their colors
const ARCHETYPE_COLORS: Dictionary = {
	RED: RED_COLOR,
	BLUE: BLUE_COLOR,
	YELLOW: YELLOW_COLOR
}

# Get color for an archetype name
static func get_color(archetype_name: String) -> Color:
	return ARCHETYPE_COLORS.get(archetype_name, Color(0, 0, 0, 1))

# Get all valid archetype names
static func get_all_archetypes() -> Array[String]:
	return [RED, BLUE, YELLOW]

# Check if an archetype name is valid
static func is_valid(archetype_name: String) -> bool:
	return archetype_name in ARCHETYPE_COLORS
