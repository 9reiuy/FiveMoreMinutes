"""Original editable three-room facility. No external/reverse-engineered assets."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ROOMS=[(1,18,8,6),(2,10,5,7),(0,1,9,8),(10,1,3,23),(9,20,1,3),(7,14,3,3),(9,6,1,3)]
def main():
    lines=['[gd_scene format=3]']
    for key,path,typ in [('wall','scenes/dream/3d/WallStraight3D.tscn','PackedScene'),('gate','scripts/story/training_gate.gd','Script')]+[(k,'scenes/story/tutorial_props/'+k+'.tscn','PackedScene') for k in ['cabinet','sofa','workstation','chair','shelf','coffee_table','water_dispenser']]+[('workmesh','art/story/chapter1/workbench.obj','ArrayMesh'),('workmat','art/story/chapter1/workbench.tres','Material')]:
        lines.append(f'[ext_resource type="{typ}" path="res://{path}" id="{key}"]')
    materials={'wall':(.27,.31,.37),'cap':(110/255,125/255,146/255),'floor':(.38,.42,.46),'rubber':(.105,.14,.17),'amber':(.58,.36,.12),'teal':(.20,.48,.45),'metal':(.34,.40,.45),'glass':(.17,.31,.35)}
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
        if solid: nodes.extend([f'metadata/solid_size = Vector2({size[0]}, {size[2]})',f'metadata/solid_layer = {layer}'])
        if rotation: nodes.append(f'rotation_degrees = Vector3{rotation}')
    cells={(x,z) for a,b,w,h in ROOMS for x in range(a,a+w) for z in range(b,b+h)}
    openings={(x,1,'N') for x in [10,11,12]}
    for x,z in sorted(cells):
        for dx,dz,side in [(0,-1,'N'),(0,1,'S'),(-1,0,'W'),(1,0,'E')]:
            if (x+dx,z+dz) in cells or (x,z,side) in openings: continue
            px,pz=x+dx*.5,z+dz*.5
            nodes.extend([f'[node name="Wall_{x}_{z}_{side}" parent="Architecture" instance=ExtResource("wall")]',f'position = Vector3({px}, 0, {pz})',f'rotation_degrees = Vector3(0, {90 if dx else 0}, 0)','wall_height = 2.8','wall_thickness = 0.12','metadata/solid_size = Vector2(1, 0.12)',f'metadata/cutaway = {"true" if side in ["S","E"] else "false"}'])
    for name,rect in zip(['Preparation','Movement','Range','Gallery','LinkA','LinkB','LinkC'],ROOMS):
        x,z,w,h=rect;nodes.append(f'[node name="{name}" type="Node3D" parent="."]')
        box('Floor',name,(x+(w-1)/2,.008,z+(h-1)/2),(w,.012,h),'floor')
        box('Foundation'+name,'Architecture',(x+(w-1)/2,-.22,z+(h-1)/2),(w+.14,.40,h+.14),'wall')
    def prop(name,parent,kind,x,z,angle=0):
        nodes.extend([f'[node name="{name}" parent="{parent}" instance=ExtResource("{kind}")]',f'position = Vector3({x}, 0, {z})',f'rotation_degrees = Vector3(0, {angle}, 0)'])
    prop('WaitingBench','Preparation','sofa',1.9,21.5,90)
    prop('ArchiveCabinet','Preparation','cabinet',2,18.8)
    prop('RegistrationDesk','Preparation','workstation',6.5,18.9)
    prop('DeskReturn','Preparation','coffee_table',7.6,19.5,90)
    prop('Chair','Preparation','chair',6.5,18.1)
    prop('WaterDispenser','Preparation','water_dispenser',2.5,23.0)
    box('EntryMat','Preparation',(4,.025,22),(2.1,.018,1.4),'rubber')
    prop('EquipmentLocker','Movement','cabinet',2.5,15.6,90)
    prop('ServiceLocker','Movement','cabinet',6.0,11.0,-90)
    for x in [2.0,6.0]:
        box('Pipe'+str(serial),'Movement',(x,.4,13.5),(.09,.09,4.7),'metal')
    for name,z in [('StartGroove',15.0),('DashStrip',12.7),('FinishSensor',10.7)]:
        box(name,'Movement',(4,.028,z),(3.3,.025,.12),'amber')
    box('GuideRunner','Movement',(4,.018,13.5),(1.7,.012,6.3),'rubber')
    for name,pos in [('TrainingTarget',(4,0,2.6)),('TrainingWeapon',(7,0,7.3))]:
        nodes.extend([f'[node name="{name}" type="Marker3D" parent="Range"]',f'position = Vector3{pos}'])
    nodes.extend(['[node name="EditorPreview" type="Node3D" parent="Range/TrainingTarget"]'])
    box('TargetBase','Range',(4,.12,2.6),(1.2,.24,.8),'metal')
    box('TargetRail','Range',(4,.02,3.3),(.3,.035,2.8),'rubber')
    box('RangeBackstop','Range',(4,1.0,1.3),(5.2,2.0,.25),'rubber',True)
    box('ShootingChestWall','Range',(3.0,.40,5.15),(6.9,.8,.28),'metal',True,32)
    box('ChestWallCap','Range',(3.0,.81,5.15),(6.9,.04,.34),'cap')
    prop('AmmoCrate0','Range','cabinet',1,7.4)
    prop('AmmoCrate1','Range','cabinet',1,6.1)
    prop('RangeShelf','Range','shelf',7.5,3.1,-90)
    nodes.extend(['[node name="AmmunitionDesk" type="MeshInstance3D" parent="Range"]','position = Vector3(7, 0, 6.2)','mesh = ExtResource("workmesh")','material_override = ExtResource("workmat")','metadata/solid_size = Vector2(1.5, 0.85)'])
    for name,x,z,w,h,layer,yaw in [('PreparationDoor',8.5,21,3,2.7,4,90),('EntryToDash',6.5,15,3,2.7,4,90),('DashToRange',8.5,7,3,2.7,4,90),('Exit',11,.5,3,2.7,4,0)]:
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
    for z in [11.2,12.2]:
        box('ObservationGlass'+str(z),'Movement',(6.44,1.66,z),(.035,.72,.86),'glass')
        for y in [1.27,2.05]: box('ObservationTrim'+str(z)+str(y),'Movement',(6.40,y,z),(.09,.06,.94),'cap')
    for name,x,z,color in [('RegistrationTask',6.5,19.3,'amber'),('WeaponTask',7,6.7,'teal')]:
        nodes.extend([f'[node name="{name}" type="OmniLight3D" parent="."]',f'position = Vector3({x}, 1.75, {z})',f'light_color = Color{(*materials[color],1)}','light_energy = 0.65','omni_range = 3.0'])
    (ROOT/'scenes/story/chapter_tutorial_layout.tscn').write_text('\n\n'.join(lines+nodes)+'\n',encoding='utf-8')
    print('FACILITY editable rooms=',len(ROOMS),'floor cells=',len(cells))
if __name__=='__main__': main()
