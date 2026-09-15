extends Node2D

const FILL_ALPHA := 0.16
const BORDER_WIDTH := 2.0
const DASH_LENGTH := 8.0
const LABEL_FONT_SIZE := 12
const LABEL_PADDING := 6.0
const DISABLED_COLOR := Color(0.45, 0.45, 0.50, 1.0)
const PICK_MASK := 1 | 8

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	SpawnZoneManager.zones_changed.connect(queue_redraw)
	SpawnZoneManager.runtime_changed.connect(queue_redraw)
	SimulationManager.species_list_changed.connect(queue_redraw)

func _draw():
	for zone in SpawnZoneManager.zones:
		_draw_zone(zone)

func _draw_zone(zone: Dictionary):
	var zone_id := int(zone.get("id", -1))
	var rect := SpawnZoneManager.zone_rect(zone)
	var species: Dictionary = SimulationManager.get_type(SpawnZoneManager.zone_species(zone_id))
	var enabled := SpawnZoneManager.is_zone_enabled(zone_id)
	var color: Color = species.color if enabled else DISABLED_COLOR
	draw_rect(rect, Color(color.r, color.g, color.b, FILL_ALPHA), true)
	_draw_dashed_border(rect, color)
	var caption := "%s  %s" % [zone.get("name", "Zone"), species.name]
	if not enabled:
		caption += "  (off)"
	var label_position := rect.position + Vector2(LABEL_PADDING, LABEL_FONT_SIZE + LABEL_PADDING * 0.5)
	var label_width := maxf(1.0, rect.size.x - LABEL_PADDING * 2.0)
	draw_string(ThemeDB.fallback_font, label_position, caption, HORIZONTAL_ALIGNMENT_LEFT, label_width, LABEL_FONT_SIZE, color.darkened(0.35))

func _draw_dashed_border(rect: Rect2, color: Color):
	var top_left := rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_right := rect.end
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	draw_dashed_line(top_left, top_right, color, BORDER_WIDTH, DASH_LENGTH)
	draw_dashed_line(top_right, bottom_right, color, BORDER_WIDTH, DASH_LENGTH)
	draw_dashed_line(bottom_right, bottom_left, color, BORDER_WIDTH, DASH_LENGTH)
	draw_dashed_line(bottom_left, top_left, color, BORDER_WIDTH, DASH_LENGTH)

func pickable_zone_at(point: Vector2) -> Dictionary:
	if SimulationManager.is_replaying or _has_clickable_object_at(point):
		return {}
	return SpawnZoneManager.zone_at(point)

func _has_clickable_object_at(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = PICK_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()

func menu_actions(zone: Dictionary) -> Array:
	var selected_species: Dictionary = SimulationManager.get_type(SimulationManager.selected_type_id)
	var starts_enabled: bool = zone.get("enabled", true)
	return [
		{"id": "zone_species", "label": "Use " + str(selected_species.name), "color": selected_species.color},
		{"id": "zone_toggle", "label": "Start Off" if starts_enabled else "Start On", "color": Color(0.482, 0.302, 0.686, 1.0)},
		{"id": "zone_remove", "label": "Remove", "color": Color(0.8, 0.25, 0.25, 1.0)},
	]

func apply_menu_action(zone_id: int, action_id: String):
	match action_id:
		"zone_species":
			SpawnZoneManager.set_zone_species(zone_id, SimulationManager.selected_type_id)
		"zone_toggle":
			var zone := SpawnZoneManager.get_zone(zone_id)
			SpawnZoneManager.set_zone_starts_enabled(zone_id, not zone.get("enabled", true))
		"zone_remove":
			SpawnZoneManager.remove_zone(zone_id)
