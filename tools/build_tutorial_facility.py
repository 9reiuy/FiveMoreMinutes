"""Editable maintenance training facility; same concrete/props as level 0-1."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ROOMS=[(1,18,8,6),(1,8,8,10),(1,2,8,6),(10,2,3,22),(9,20,1,3),(9,12,1,3),(9,4,1,3)]
def main():
    lines=['[gd_scene format=3]']
    for key,path,typ in [('wall','scenes/dream/3d/WallStraight3D.tscn','PackedScene'),('gate','scripts/story/training_gate.gd','Script'),('equipment','scripts/dream/props/maintenance_fixture.gd','Script'),('television','scripts/story/tutorial_tv_station.gd','Script'),('mannequin','art/Dream/enemy/Human body model.png','Texture2D')]:
        lines.append(f'[ext_resource type="{typ}" path="res://{path}" id="{key}"]')
    materials={'wall':(.27,.31,.37),'cap':(.30,.36,.40),'top_black':(0,0,0),'rubber':(.105,.14,.17),'amber':(.58,.36,.12),'teal':(.20,.48,.45),'metal':(.24,.32,.35),'glass':(.17,.31,.35)}
    for key,c in materials.items():
        lines += [f'[sub_resource type="StandardMaterial3D" id="mat_{key}"]',f'albedo_color = Color({c[0]}, {c[1]}, {c[2]}, 1)','roughness = 0.88','metallic_specular = 0.0','texture_filter = 0']
        if key in ['amber','teal']: lines += ['emission_enabled = true',f'emission = Color({c[0]}, {c[1]}, {c[2]}, 1)','emission_energy_multiplier = 0.4']
    nodes=['[node name="ChapterLayout" type="Node3D"]','[node name="Architecture" type="Node3D" parent="."]']
    serial=0
    def box(name,parent,point,size,mat='metal',solid=False,layer=4,rotation=None):
        nonlocal serial
        serial+=1; mid='mesh'+str(serial)
        lines.extend([f'[sub_resource type="BoxMesh" id="{mid}"]',f'size = Vector3({size[0]}, {size[1]}, {size[2]})'])
        nodes.extend([f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]',f'position = Vector3({point[0]}, {point[1]}, {point[2]})',f'mesh = SubResource("{mid}")',f'material_override = SubResource("mat_{mat}")',f'metadata/pixel_swatch = "{"floor_tile" if mat=="floor" else "rug" if mat=="rubber" else "metal"}"'])
        if mat=='top_black': nodes.append('metadata/black_top = true')
        if solid: nodes.extend([f'metadata/solid_size = Vector2({size[0]}, {size[2]})',f'metadata/solid_layer = {layer}'])
        if rotation: nodes.append(f'rotation_degrees = Vector3{rotation}')
    cells={(x,z) for a,b,w,h in ROOMS for x in range(a,a+w) for z in range(b,b+h)}
    openings={(x,2,'N') for x in [10,11,12]}

    def wall(name, x, z, yaw=0, cutaway=False, span=1):
        nodes.extend([
            f'[node name="{name}" parent="Architecture" instance=ExtResource("wall")]',
            f'position = Vector3({x}, 0, {z})',
            f'rotation_degrees = Vector3(0, {yaw}, 0)',
            'wall_height = 2.6',
            'wall_thickness = 0.24',
            f'metadata/solid_size = Vector2({span}, 0.24)',
            f'metadata/cutaway = {str(cutaway).lower()}',
        ])
        if span != 1:
            nodes.append(f'scale = Vector3({span}, 1, 1)')

    for x,z in sorted(cells):
        for dx,dz,side in [(0,-1,'N'),(0,1,'S'),(-1,0,'W'),(1,0,'E')]:
            if (x+dx,z+dz) in cells or (x,z,side) in openings: continue
            wall(f'Wall_{x}_{z}_{side}', x+dx*.5, z+dz*.5, 90 if dx else 0, side in ['S','E'])
    # Adjacent teaching rooms share one full-height wall and one collision per seam.
    for index, (near, far) in enumerate(zip(ROOMS[:2], ROOMS[1:3]), start=1):
        x, z, width, _ = near
        assert x == far[0] and width == far[2] and z == far[1] + far[3]
        wall(f'SharedWall_{index}_{index+1}', x+(width-1)*.5, z-.5, span=width)
    for name,rect in zip(['Preparation','Movement','Range','Gallery','LinkA','LinkB','LinkC'],ROOMS):
        x,z,w,h=rect;nodes.append(f'[node name="{name}" type="Node3D" parent="."]')
        box('Foundation'+name,'Architecture',(x+(w-1)/2,-.22,z+(h-1)/2),(w+.14,.40,h+.14),'wall')
    def prop(name,parent,kind,x,z,angle=0,size=(1.5,.8,1.0)):
        nodes.extend([f'[node name="{name}" type="Node3D" parent="{parent}"]',f'position = Vector3({x}, 0, {z})',f'rotation_degrees = Vector3(0, {angle}, 0)','script = ExtResource("equipment")',f'kind = "{kind}"',f'dimensions = Vector3{size}',f'metadata/solid_size = Vector2({size[0]}, {size[2]})',f'metadata/maintenance_kind = "{kind}"'])
    for parent,x,z,table in [('Preparation',2.2,20.5,True),('Movement',1.25,12.5,False),('Range',1.25,4.5,False)]:
        nodes.extend([f'[node name="TelevisionDesk" type="Node3D" parent="{parent}"]',f'position = Vector3({x}, 0, {z})','rotation_degrees = Vector3(0, 90, 0)','script = ExtResource("television")',f'table_enabled = {str(table).lower()}','conversation_enabled = true'])
    prop('EquipmentLocker','Movement','switchgear',1.7,14.7,90,size=(1.2,1.6,.7))
    prop('ServiceLocker','Movement','switchgear',7.5,10.7,-90,size=(1.2,1.6,.7))
    for x in [1.5,7.5]:
        box('Pipe'+str(serial),'Movement',(x,.4,12.5),(.09,.09,4.7),'metal')
    for name,z in [('StartGroove',14.2),('DashStrip',12.8),('FinishSensor',11.4)]:
        box(name,'Movement',(4,.028,z),(3.3,.025,.12),'amber')
        nodes.extend(['gi_mode = 0','metadata/floor_light_strip = true'])
    box('GuideRunner','Movement',(4,.018,12.5),(1.7,.012,5.3),'rubber')
    for name,pos in [('TrainingTarget',(4.5,0,2.9)),('TrainingWeapon',(7.2,0,6.6))]:
        nodes.extend([f'[node name="{name}" type="Marker3D" parent="Range"]',f'position = Vector3{pos}'])
    nodes.extend(['[node name="EditorPreview" type="Node3D" parent="Range/TrainingTarget"]'])
    lines.extend(['[sub_resource type="AtlasTexture" id="model_frame"]','atlas = ExtResource("mannequin")','region = Rect2(0, 0, 32, 32)'])
    nodes.extend(['[node name="Model" type="Sprite3D" parent="Range/TrainingTarget/EditorPreview"]','position = Vector3(0, 0.5, 0)','texture = SubResource("model_frame")','pixel_size = 0.03125','billboard = 1','shaded = true','texture_filter = 0'])
    box('TargetBase','Range',(4.5,.04,2.9),(1.2,.08,.8),'metal')
    box('TargetRail','Range',(4.5,.02,3.4),(.3,.035,1.8),'rubber')
    box('RangeBackstop','Range',(4.5,1.0,1.8),(5.2,2.0,.25),'rubber',True)
    box('ShootingLine','Range',(3.9,.011,4.9),(6.5,.007,.12),'cap')
    nodes.append('metadata/painted_line = true')
    prop('AmmoCrate0','Range','case',1.3,6.7,size=(1.3,.65,.85))
    prop('AmmoCrate1','Range','case',1.3,5.5,size=(1.3,.65,.85))
    prop('RangeGenerator','Range','generator',7.5,3.1,-90,size=(1.8,1.3,1.0))
    box('WeaponTray','Range',(7.2,.04,6.6),(1.4,.08,.7),'metal')
    for name,x,z,w,h,layer,yaw in [('PreparationDoor',8.5,21,3,2.7,4,90),('EntryToDash',8.5,13,3,2.7,4,90),('DashToRange',8.5,5,3,2.7,4,90),('Exit',11,1.5,3,2.7,4,0)]:
        nodes.extend([f'[node name="{name}" type="Node3D" parent="Architecture"]',f'position = Vector3({x}, 0, {z})',f'rotation_degrees = Vector3(0, {yaw}, 0)','script = ExtResource("gate")',f'width = {w}.0',f'height = {h}',f'collision_layer = {layer}'])
        # Original ribbed steel pressure hatch, inset jambs, segmented leaf, cam wheel and hazard rail.
        box('Leaf','Architecture/'+name,(0,h*.5,0),(w-.12,h,.16),'metal')
        for side in [-1,1]:
            box('Jamb'+str(side),'Architecture/'+name,(side*(w*.5-.10),h*.5,.02),(.20,h+.18,.34),'cap')
            box('JambChamfer'+str(side),'Architecture/'+name,(side*(w*.5-.19),h*.5,.21),(.09,h+.16,.09),'cap',rotation=(0,45,0))
        box('Header','Architecture/'+name,(0,h+.06,.02),(w,.20,.34),'cap')
        box('Sill','Architecture/'+name,(0,.025,.02),(w,.05,.35),'cap')
        for side in [-1,1]:
            box('Inset'+str(side),'Architecture/'+name+'/Leaf',(side*w*.24,0,.095),(w*.40,h*.72,.035),'wall')
            for row in [-.25,.25]:
                box('Rib'+str(side)+str(row),'Architecture/'+name+'/Leaf',(side*w*.24,h*row,.13),(w*.37,.06,.05),'cap')
        box('CenterSeam','Architecture/'+name+'/Leaf',(0,0,.12),(.035,h*.94,.025),'rubber')
        box('CamPlate','Architecture/'+name+'/Leaf',(w*.25,0,.15),(.28,.26,.07),'cap')
        box('HandleBar','Architecture/'+name+'/Leaf',(w*.25,0,.23),(.30,.045,.06),'rubber')
        box('HandleStem','Architecture/'+name+'/Leaf',(w*.25,0,.20),(.045,.22,.06),'rubber')
        box('Indicator','Architecture/'+name,(0,h+.09,.23),(.75,.08,.06),'amber')
    # Glazed observation inserts belong to the interior wall rather than a ground decal.
    for z in [10.2,11.2]:
        box('ObservationGlass'+str(z),'Movement',(8.44,1.66,z),(.035,.72,.86),'glass')
        for y in [1.27,2.05]: box('ObservationTrim'+str(z)+str(y),'Movement',(8.40,y,z),(.09,.06,.94),'cap')
    (ROOT/'scenes/story/chapter_tutorial_layout.tscn').write_text('\n\n'.join(lines+nodes)+'\n',encoding='utf-8')
    print('FACILITY editable rooms=',len(ROOMS),'floor cells=',len(cells))
if __name__=='__main__': main()
