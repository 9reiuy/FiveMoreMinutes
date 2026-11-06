"""Add editor-owned practical lights; keep the authored coast geometry intact."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
scene = ROOT / 'scenes/preview/night_coast.tscn'
text = scene.read_text(encoding='utf-8')
if '[node name="SpatialLighting"' in text:
    raise SystemExit('Lighting already authored; edit the saved nodes in place.')
resources = '''[ext_resource type="Script" path="res://scripts/preview/coast_spatial_lighting.gd" id="spatial_lighting_script"]
[ext_resource type="Shader" path="res://shaders/preview/coast_local_light_volume.gdshader" id="spatial_volume_shader"]

'''
text = text.replace('[sub_resource ', resources + '[sub_resource ', 1)
subresources = '''[sub_resource type="ShaderMaterial" id="SpatialLampHousing"]
resource_local_to_scene = true
shader = ExtResource("10_koh31")
shader_parameter/base_color = Color(0.14, 0.17, 0.23, 1)
shader_parameter/office_tonal_sample = true

[sub_resource type="StandardMaterial3D" id="SpatialWarmEmitter"]
shading_mode = 0
albedo_color = Color(1, 0.7, 0.35, 1)
emission_enabled = true
emission = Color(1, 0.55, 0.22, 1)
emission_energy_multiplier = 2.2
roughness = 0.9

[sub_resource type="StandardMaterial3D" id="SpatialWarningEmitter"]
shading_mode = 0
albedo_color = Color(1, 0.24, 0.09, 1)
emission_enabled = true
emission = Color(1, 0.12, 0.035, 1)
emission_energy_multiplier = 2.0
roughness = 0.9

[sub_resource type="BoxMesh" id="SpatialLampPostMesh"]
size = Vector3(0.08, 1.6, 0.08)

[sub_resource type="BoxMesh" id="SpatialLampHousingMesh"]
size = Vector3(0.36, 0.19, 0.27)

[sub_resource type="BoxMesh" id="SpatialLampCoreMesh"]
size = Vector3(0.25, 0.045, 0.16)

[sub_resource type="BoxMesh" id="SpatialVolumeBox"]
size = Vector3(3.6, 1.8, 3.6)

'''
for number in range(2):
    subresources += f'''[sub_resource type="ShaderMaterial" id="SpatialVolume{number}"]
resource_local_to_scene = true
shader = ExtResource("spatial_volume_shader")
shader_parameter/beam_height = 1.8
shader_parameter/beam_radius = 1.8
shader_parameter/density = 0.055

'''
text = text.replace('[node ', subresources + '[node ', 1)
text = text.replace('shader_parameter/office_dither_step = 0.03125\n', 'shader_parameter/office_dither_step = 0.03125\nshader_parameter/office_tonal_sample = true\n')
text = text.replace('ambient_light_color = Color(0.13, 0.19, 0.3, 1)', 'ambient_light_color = Color(0.18, 0.24, 0.4, 1)')
text = text.replace('ambient_light_energy = 0.18', '''ambient_light_energy = 0.24
glow_enabled = true
glow_intensity = 0.08
glow_bloom = 0.0
glow_hdr_threshold = 0.98
glow_hdr_scale = 1.0''')
text = text.replace('light_energy = 0.65\nshadow_enabled = true', '''light_energy = 1.9
light_angular_distance = 0.35
shadow_enabled = true
shadow_bias = 0.035
shadow_normal_bias = 0.35
directional_shadow_max_distance = 100.0''', 1)
nodes = '''
[node name="SpatialLighting" type="Node3D" parent="."]
editor_description = "冷色天光与柔和反弹补光；两处实体工作灯、深度裁切局部雾束。均可在3D编辑器调整。"
script = ExtResource("spatial_lighting_script")

[node name="CoolSkyBounce" type="DirectionalLight3D" parent="SpatialLighting"]
rotation = Vector3(-0.95, -0.65, 0)
light_color = Color(0.35, 0.48, 0.76, 1)
light_energy = 0.28
shadow_enabled = false
metadata/coast_base_energy = 0.28
metadata/coast_cloud_scale = 0.08

'''
for number, (x, y, z) in enumerate([(-6.2, 0.9502983, 21), (0, 1.5972779, 15)]):
    path = f'SpatialLighting/ShoreWorklight{number}'
    nodes += f'''[node name="ShoreWorklight{number}" type="Node3D" parent="SpatialLighting"]
position = Vector3({x}, {y}, {z})
editor_description = "暖色实体工作灯。移动整个节点可同时调整灯具、投影与空气散射范围。"

[node name="Post" type="MeshInstance3D" parent="{path}"]
position = Vector3(0, 0.8, 0)
mesh = SubResource("SpatialLampPostMesh")
material_override = SubResource("SpatialLampHousing")

[node name="Housing" type="MeshInstance3D" parent="{path}"]
position = Vector3(0, 1.71, 0)
mesh = SubResource("SpatialLampHousingMesh")
material_override = SubResource("SpatialLampHousing")

[node name="Emitter" type="MeshInstance3D" parent="{path}"]
position = Vector3(0, 1.59, 0)
mesh = SubResource("SpatialLampCoreMesh")
material_override = SubResource("SpatialWarmEmitter")
cast_shadow = 0

[node name="WarmSpot" type="SpotLight3D" parent="{path}"]
position = Vector3(0, 1.56, 0)
rotation = Vector3(-1.5707963, 0, 0)
light_color = Color(1, 0.66, 0.34, 1)
light_energy = 0.65
spot_range = 5.5
spot_attenuation = 1.1
spot_angle = 56.0
spot_angle_attenuation = 1.4
shadow_enabled = true
shadow_bias = 0.035
shadow_normal_bias = 0.2
metadata/coast_base_energy = 0.65
metadata/coast_cloud_scale = 0.60

[node name="WarmBounce" type="OmniLight3D" parent="{path}"]
position = Vector3(0, 0.6, 0)
light_color = Color(0.68, 0.49, 0.40, 1)
light_energy = 0.18
omni_range = 4.5
omni_attenuation = 0.7
shadow_enabled = false
metadata/coast_base_energy = 0.18
metadata/coast_cloud_scale = 0.50

[node name="LocalAirScattering" type="MeshInstance3D" parent="{path}"]
position = Vector3(0, 0.66, 0)
mesh = SubResource("SpatialVolumeBox")
material_override = SubResource("SpatialVolume{number}")
cast_shadow = 0

'''
nodes += '''[node name="CabinPractical" type="OmniLight3D" parent="WaveBreakers/TowerCrane"]
position = Vector3(1.1, 10, 1)
light_color = Color(1, 0.60, 0.27, 1)
light_energy = 1.3
omni_range = 4.5
omni_attenuation = 1.2
shadow_enabled = false
metadata/coast_base_energy = 1.3
metadata/coast_cloud_scale = 0.75

[node name="CabinLightCore" type="MeshInstance3D" parent="WaveBreakers/TowerCrane/CabinPractical"]
mesh = SubResource("SpatialLampCoreMesh")
material_override = SubResource("SpatialWarmEmitter")
cast_shadow = 0

[node name="CraneWarning" type="OmniLight3D" parent="WaveBreakers/TowerCrane"]
position = Vector3(-0.4, 12.4, 0)
light_color = Color(1, 0.18, 0.07, 1)
light_energy = 0.55
omni_range = 3.0
omni_attenuation = 1.3
shadow_enabled = false
metadata/coast_base_energy = 0.55
metadata/coast_cloud_scale = 0.65
metadata/coast_pulse = 0.10

[node name="WarningCore" type="MeshInstance3D" parent="WaveBreakers/TowerCrane/CraneWarning"]
mesh = SubResource("SpatialLampCoreMesh")
material_override = SubResource("SpatialWarningEmitter")
cast_shadow = 0
'''
scene.write_text(text + nodes, encoding='utf-8')
print('Authored two shoreline practicals, crane lights and local depth-clipped volumes.')
