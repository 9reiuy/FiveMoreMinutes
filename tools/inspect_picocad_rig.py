"""Read-only inspection of the user's picoCAD reference; no assets copied."""
import json
import math
import statistics
from collections import Counter
from pathlib import Path
from PIL import Image

directory = Path(r'C:\Users\Administrator\AppData\Roaming\picocad2\examples')
data = json.loads((directory / 'rig.txt').read_text(encoding='utf-8'))
vertices, uv, faces = [], [], []
for line in (directory / 'rig.obj').read_text(encoding='utf-8').splitlines():
    fields = line.split()
    if not fields:
        continue
    if fields[0] == 'v':
        vertices.append(tuple(map(float, fields[1:4])))
    elif fields[0] == 'vt':
        uv.append(tuple(map(float, fields[1:3])))
    elif fields[0] == 'f':
        faces.append([tuple(int(x) - 1 for x in item.split('/')[:2]) for item in fields[1:]])
with Image.open(directory / 'rig.png') as image:
    size = image.size
    colors = len(image.convert('RGBA').getcolors(image.width * image.height))
    print('texture', size, 'visible PNG colors', colors, 'project palette', len(data['texture']['colors']))
print('mesh vertices', len(vertices), 'UV corners', len(uv), 'polygon sizes', dict(Counter(map(len, faces))))
print('mesh bounds', [round(max(v[a] for v in vertices) - min(v[a] for v in vertices), 3) for a in range(3)])
densities = []
islands = Counter()
for face in faces:
    coords = [uv[item[1]] for item in face]
    islands[tuple(sorted(coords))] += 1
    for i, (v1, t1) in enumerate(face):
        v2, t2 = face[(i + 1) % len(face)]
        edge = math.dist(vertices[v1], vertices[v2])
        pixel_edge = math.dist((uv[t1][0] * size[0], uv[t1][1] * size[1]), (uv[t2][0] * size[0], uv[t2][1] * size[1]))
        if edge > .01 and pixel_edge > .01:
            densities.append(pixel_edge / edge)
print('edge texel density median', round(statistics.median(densities), 3), 'common rounded values', Counter(round(x, 1) for x in densities).most_common(8))
print('shared UV islands', sum(n > 1 for n in islands.values()), 'largest reuse', max(islands.values()))
print('shadow palette 1', data['texture']['shade_pal_1'])
print('shadow palette 2', data['texture']['shade_pal_2'])
def walk(node):
    for child in node.get('children', []):
        if isinstance(child, dict):
            yield child
            yield from walk(child)
nodes = list(walk(data['graph']))
print('graph nodes', len(nodes), 'first node keys', list(nodes[0]) if nodes else [])
