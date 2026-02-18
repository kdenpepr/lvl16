extends Node

# Global match settings used by gameplay systems.
const ARENA_BOUNDS: Rect2 = Rect2(Vector2(0, 0), Vector2(1920, 1080))
const TICK_RATE: float = 30.0
const TICK_DELTA: float = 1.0 / TICK_RATE

enum Team {
	PLAYER,
	ENEMY,
	NEUTRAL,
}

func is_valid_team(team: int) -> bool:
	return team in Team.values()

func get_opposing_team(team: int) -> int:
	if team == Team.PLAYER:
		return Team.ENEMY
	if team == Team.ENEMY:
		return Team.PLAYER
	return Team.NEUTRAL

func is_position_in_arena(position: Vector2) -> bool:
	return ARENA_BOUNDS.has_point(position)

func clamp_to_arena(position: Vector2) -> Vector2:
	return Vector2(
		clampf(position.x, ARENA_BOUNDS.position.x, ARENA_BOUNDS.end.x),
		clampf(position.y, ARENA_BOUNDS.position.y, ARENA_BOUNDS.end.y)
	)

func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) / TICK_RATE
