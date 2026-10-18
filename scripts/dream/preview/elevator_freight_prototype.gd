extends "res://scripts/dream/elevator_freight_facade.gd"
## Compatibility wrapper for the approved review entrypoint.
static func install(source: Node3D) -> Node3D:
    var old: Node3D=source.industrial_facade
    for display in old.leaf_displays: display.free()
    old.free()
    var facade=load("res://scripts/dream/elevator_freight_facade.gd").new()
    source.add_child(facade)
    source.industrial_facade=facade
    facade.configure(source)
    return facade
