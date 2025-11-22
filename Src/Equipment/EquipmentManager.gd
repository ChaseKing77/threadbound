extends Node
class_name EquipmentManager

signal palette_changed(new_color: Color)
signal piece_equipped(slot: int, piece: EquipmentPiece)

const STARTING_THREAD = ThreadType.RED  # change later with game start screen

var starting_thread := STARTING_THREAD
var absorbed_channels := {
	ThreadType.RED: 1.0,
	ThreadType.BLUE: 0.0,
	ThreadType.YELLOW: 0.0
}

var equipped := {
	SlotType.GLOVES: null,
	SlotType.BOOTS: null,
	SlotType.CHEST_HEAD: null
}

func _ready() -> void:
	# Debug: press 1/2/3 to absorb masters instantly
	if OS.is_debug_build():
		set_process_input(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_absorb_red"):
		absorb_master(ThreadType.RED)
	if event.is_action_pressed("debug_absorb_blue"):
		absorb_master(ThreadType.BLUE)
	if event.is_action_pressed("debug_absorb_yellow"):
		absorb_master(ThreadType.YELLOW)

func absorb_master(thread: int) -> void:
	# Max out that channel
	absorbed_channels[thread] = 1.0
	
	# Unlock and auto-equip all three pieces for this thread
	var folder = "res://src/Equipment/pieces/"
	match thread:
		ThreadType.RED:
			_equip_from_path(folder + "red/Red_Gloves_Monarch.tres")
			_equip_from_path(folder + "red/Red_Boots_Monarch.tres")
			_equip_from_path(folder + "red/Red_ChestHead_Monarch.tres")
		ThreadType.BLUE:
			# TODO: add blue pieces later
			pass
		ThreadType.YELLOW:
			# TODO: add yellow pieces later
			pass
	
	palette_changed.emit(get_palette_color())

func _equip_from_path(path: String) -> void:
	var piece = load(path) as EquipmentPiece
	if piece:
		equipped[piece.slot] = piece
		piece_equipped.emit(piece.slot, piece)

func get_palette_color() -> Color:
	return Color(
		absorbed_channels[ThreadType.RED],
		absorbed_channels[ThreadType.BLUE],
		absorbed_channels[ThreadType.YELLOW]
	)

func get_rune_color() -> Color:
	return ThreadType.COLORS[starting_thread]

# Helper getters
func get_gloves_piece() -> EquipmentPiece: return equipped[SlotType.GLOVES]
func get_boots_piece() -> EquipmentPiece: return equipped[SlotType.BOOTS]
func get_chest_head_piece() -> EquipmentPiece: return equipped[SlotType.CHEST_HEAD]
