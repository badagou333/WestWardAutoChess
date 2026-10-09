extends RefCounted
## D-20261007-001 / 01 a9f81fe. Prototype only; never changes legacy catalogs.
const DEFAULT_ENEMY_PROFILE := "bear"
const ENEMY_PROFILES := ["legacy","normal","bear"]
const VERSION := "board-v5-bear"
const COLS := 12
const ROWS := 7
const DEPLOY_COLS := 6
const ORIGIN := Vector2(220,190)
const CELL := Vector2(110,102)
const STEP := 1.0/120.0
const MOVE_SECONDS_PER_CELL := 0.5 # Shared by every actor in this trial; not an attack interval.
const SCAN := 0.25
const AGGRO := 3
const LEASH := 2
const LONG_BLOCK_SECONDS := 2.0 # D-004 prototype safety release; all old stats unchanged.
const ENEMY_HP_FACTOR := 1.0
const ENEMY_DAMAGE_FACTOR := 1.0
const LEGACY_ENEMY_STATS := {
	"wolf":{"hp":155.0,"damage":14.0,"interval":0.90,"range":1},
	"boar":{"hp":96.0,"damage":10.0,"interval":1.10,"range":1},
	"rat":{"hp":52.0,"damage":7.0,"interval":0.95,"range":3}}
const NORMAL_ENEMY_STATS := {
	"wolf":{"hp":180.0,"damage":17.0,"interval":0.90,"range":1},
	"boar":{"hp":120.0,"damage":12.0,"interval":1.10,"range":1},
	"rat":{"hp":65.0,"damage":9.0,"interval":0.95,"range":3}}
const BEAR_STATS := {"hp":280.0,"damage":20.0,"interval":1.20,"range":1}
const CORE := {"hp":300.0,"damage":6.0,"interval":1.2,"range":3}
const FRIENDS := ["tangseng","guard_monk","wild_hunter","sparrow_spirit","herbal_spirit_child","foxfire_imp"]
# All configuration coordinates are ONE-BASED (column,row); runtime is zero-based.
const ENEMIES := [
	["wolf",Vector2i(8,2)],["wolf",Vector2i(8,6)],
	["boar",Vector2i(9,3)],["boar",Vector2i(9,5)],
	["rat",Vector2i(11,2)],["rat",Vector2i(11,6)]]
const FORMATIONS := {
	"A":[Vector2i(3,4),Vector2i(6,4),Vector2i(5,3),Vector2i(5,4),Vector2i(4,4),Vector2i(5,5)],
	"B":[Vector2i(6,4),Vector2i(2,4),Vector2i(3,1),Vector2i(3,4),Vector2i(1,7),Vector2i(3,7)],
	"C":[Vector2i(3,4),Vector2i(6,2),Vector2i(5,2),Vector2i(5,6),Vector2i(4,3),Vector2i(4,5)]}

static func enemy_specs(profile: String) -> Array:
	var result: Array=ENEMIES.duplicate(true)
	if profile=="bear": result.append(["bear_lord",Vector2i(10,4)])
	return result

static func enemy_stats(key: String, profile: String) -> Dictionary:
	if key=="bear_lord": return BEAR_STATS.duplicate()
	return (LEGACY_ENEMY_STATS if profile=="legacy" else NORMAL_ENEMY_STATS)[key].duplicate()

static func version_for(profile: String) -> String:
	return "board-v5-"+profile

static func valid(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.x<COLS and cell.y>=0 and cell.y<ROWS

static func deployable(cell: Vector2i) -> bool:
	return valid(cell) and cell.x<DEPLOY_COLS

static func center(cell: Vector2i) -> Vector2:
	return ORIGIN+(Vector2(cell)+Vector2(0.5,0.5))*CELL

static func cell_at(point: Vector2) -> Vector2i:
	var offset := (point-ORIGIN)/CELL
	var cell := Vector2i(floori(offset.x),floori(offset.y))
	return cell if valid(cell) else Vector2i(-1,-1)

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)
