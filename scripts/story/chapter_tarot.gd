extends RefCounted
## Chapter-only starter bonuses; original global card catalog/art is unchanged.
static func bonus(id: String,reversed: bool) -> Dictionary:
	var card:=TarotCardCatalog.get_card(StringName(id))
	if card==null: return {}
	var index: int=(card.arcana_index+(1 if reversed else 0))%3
	return [{"kind":"damage","label":"伤害 +10%"},{"kind":"tempo","label":"攻击速度 +10%"},{"kind":"range","label":"有效射程 +32"}][index]
static func apply(player: Node,id: String,reversed: bool) -> void:
	match bonus(id,reversed).get("kind",""):
		"damage": player.apply_damage_upgrade(1.10)
		"tempo": player.apply_attack_speed_upgrade(1.10)
		"range": player.apply_range_upgrade(32.)
