extends Node
class_name ThreadType
# Singleton — add as Autoload named "ThreadType"

enum Thread { RED, BLUE, YELLOW }

const COLORS := {
	Thread.RED:    Color(1.0, 0.0, 0.0),
	Thread.BLUE:   Color(0.0, 0.5, 1.0),
	Thread.YELLOW: Color(1.0, 1.0, 0.0)
}

static func get_color(thread: int) -> Color:
	return COLORS.get(thread, Color.WHITE)

static func get_name(thread: int) -> String:
	return ["Red", "Blue", "Yellow"][thread]
