@tool
extends Resource
class_name EquipmentPiece

@export var slot : SlotType
@export var thread_type : ThreadType.Thread  # assuming you have ThreadType.RED etc.
@export var piece_name : String = "Unnamed Piece"

# Visuals — leave blank until art exists
@export var debug_color : Color = Color.WHITE
@export var clothing_sprite : Texture2D
@export var rune_overlay : Texture2D
@export var trail_particles : PackedScene

# Ability scripts (we'll attach these to player components)
@export var jump_modifier : GDScript     # only used if slot == BOOTS
@export var grapple_ability : GDScript   # only if slot == GLOVES
@export var dash_ability : GDScript      # only if slot == CHEST_HEAD

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = []
	if slot == SlotType.BOOTS and jump_modifier == null:
		warnings.append("Boots piece should have a jump_modifier script")
	if slot == SlotType.GLOVES and grapple_ability == null:
		warnings.append("Gloves piece should have a grapple_ability script")
	if slot == SlotType.CHEST_HEAD and dash_ability == null:
		warnings.append("Chest/Head piece should have a dash_ability script")
	return warnings
