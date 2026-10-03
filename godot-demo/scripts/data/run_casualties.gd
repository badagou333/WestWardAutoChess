extends RefCounted
## One four-stage run's losses. Snapshots contain no Node references and survive
## inventory removal, camp coordinate rebuilds and destruction of the actor.
var seats := {} # stable numeric seat -> immutable identity/death-position snapshot
var actor_seats := {} # instance ID -> stable seat

func register(hero, index: int) -> bool:
	if index < 0 or seats.has(index) or actor_seats.has(hero.get_instance_id()): return false
	seats[index] = {"actor_id":hero.get_instance_id(),"unit":hero.unit_type,"name":hero.display_name,
		"star":hero.star,"max_hp":hero.max_health,"position":hero.position,
		"status":"阵亡","hp":0.0,"dead":true,"permanent":true,"selected":false}
	actor_seats[hero.get_instance_id()] = index
	return true

func contains(hero) -> bool:
	return is_instance_valid(hero) and actor_seats.has(hero.get_instance_id())

func coordinates() -> Dictionary:
	var result := {}
	for index in seats: result[index] = seats[index].position
	return result

func reset() -> void:
	seats.clear()
	actor_seats.clear()
