"""Independent checks of delivered OBJ/PNG/materials, not the generator's claims."""
from pathlib import Path
from PIL import Image
import json, math, re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art/story/chapter1'
audit = json.loads((OUT / 'asset_audit.json').read_text(encoding='utf-8'))
checks, issues, models = 0, [], []

def check(ok, label):
    global checks
    checks += 1
    if not ok:
        issues.append(label)

for item in audit['assets']:
    name = item['asset']
    image = Image.open(OUT / f'{name}.png').convert('RGB')
    w, h = image.size
    check(all(v > 0 and (v & (v-1)) == 0 for v in (w, h)), name + ': power-of-two atlas')
    text = (OUT / f'{name}.obj').read_text(encoding='utf-8')
    vertices = [tuple(map(float, row.split()[1:])) for row in text.splitlines() if row.startswith('v ')]
    uv = [tuple(map(float, row.split()[1:])) for row in text.splitlines() if row.startswith('vt ')]
    faces = [row.split()[1:] for row in text.splitlines() if row.startswith('f ')]
    check(len(faces) == item['triangles'] and all(len(f) == 3 for f in faces), name + ': delivered triangle count')
    check(all(0 <= x <= 1 and 0 <= y <= 1 for x, y in uv), name + ': UV bounds')
    check(all(0 < int(i.split('/')[0]) <= len(vertices) for f in faces for i in f), name + ': valid mesh indices')
    if name not in ('camera_head', 'camera_mount'):
        check(abs(min(v[1] for v in vertices)) < 1e-5, name + ': bottom pivot Y=0')
    if name == 'camera_mount':
        check(abs(min(v[2] for v in vertices)) < 1e-5, name + ': back pivot Z=0')
    occupied = set()
    for face in item['faces']:
        x, y, fw, fh = face['rect']
        check(face['pixels'] == [max(1, round(span * 32)) for span in face['metres']], name + ': face texel density')
        region = {(xx, yy) for yy in range(y-2, y+fh+2) for xx in range(x-2, x+fw+2)}
        check(not occupied.intersection(region), name + ': padded islands do not overlap')
        occupied.update(region)
        check(x >= 2 and y >= 2 and x+fw+2 <= w and y+fh+2 <= h, name + ': 2px padding bounds')
        check(all(image.getpixel((xx, yy)) == image.getpixel((min(x+fw-1, max(x, xx)), min(y+fh-1, max(y, yy))))
                  for xx, yy in region if not (x <= xx < x+fw and y <= yy < y+fh)), name + ': padding extruded correctly')
    material = (OUT / f'{name}.tres').read_text(encoding='utf-8')
    check('texture_filter = 0' in material and 'roughness = 0.88' in material and 'metallic = 0.0' in material and 'metallic_specular = 0.0' in material, name + ': nearest matte material')
    check('emission_operator = 1' in material, name + ': emission mask multiplies instead of lighting whole atlas')
    for suffix in ('', '_emission'):
        settings = (OUT / f'{name}{suffix}.png.import').read_text(encoding='utf-8')
        check('mipmaps/generate=false' in settings, name + suffix + ': no mipmaps')
    models.append({'name': name, 'triangles': len(faces), 'atlas': [w, h], 'minimum_y': min(v[1] for v in vertices)})

result = {'checks': checks, 'failures': len(issues), 'issues': issues, 'models': models}
destination = ROOT / '.runtime/chapter1_20261029/asset_checks.json'
destination.write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, ensure_ascii=False))
raise SystemExit(bool(issues))
