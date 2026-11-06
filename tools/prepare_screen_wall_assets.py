"""Dequantize the CC0 server GLB for Godot's core glTF importer.

The original download is kept in .runtime/screen_wall_sources_20261106.
Geometry, node transforms and animations are preserved. Texture conversion
is lossless WebP decoding to PNG; this does not generate or repaint artwork.
"""
from pathlib import Path
import hashlib
import io
import json
import struct
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / '.runtime/screen_wall_sources_20261106/server_rack.glb'
target = ROOT / 'art/preview/screen_wall/cc0/server_rack.glb'
data = source.read_bytes()
json_size = struct.unpack_from('<I', data, 12)[0]
document = json.loads(data[20:20 + json_size])
binary = bytearray(data[28 + json_size:])


def append_view(payload, target_kind=None):
    while len(binary) % 4:
        binary.append(0)
    view = {'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(payload)}
    if target_kind:
        view['target'] = target_kind
    binary.extend(payload)
    document['bufferViews'].append(view)
    return len(document['bufferViews']) - 1


for accessor in document['accessors']:
    component = accessor['componentType']
    if component == 5126 or not accessor.get('normalized', False):
        continue
    view = document['bufferViews'][accessor['bufferView']]
    count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[accessor['type']]
    fmt = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H'}[component]
    maximum = {5120: 127, 5121: 255, 5122: 32767, 5123: 65535}[component]
    size = struct.calcsize('<' + fmt * count)
    stride = view.get('byteStride', size)
    start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    values = [tuple(max(-1.0, x / maximum) for x in struct.unpack_from('<' + fmt * count, binary, start + i * stride))
              for i in range(accessor['count'])]
    payload = b''.join(struct.pack('<' + 'f' * count, *row) for row in values)
    accessor['bufferView'] = append_view(payload, view.get('target'))
    accessor['byteOffset'] = 0
    accessor['componentType'] = 5126
    accessor.pop('normalized', None)
    if 'min' in accessor:
        accessor['min'] = [min(row[i] for row in values) for i in range(count)]
        accessor['max'] = [max(row[i] for row in values) for i in range(count)]

for image in document.get('images', []):
    if image.get('mimeType') != 'image/webp':
        continue
    view = document['bufferViews'][image['bufferView']]
    start = view.get('byteOffset', 0)
    png = io.BytesIO()
    Image.open(io.BytesIO(binary[start:start + view['byteLength']])).save(png, format='PNG')
    image['bufferView'] = append_view(png.getvalue())
    image['mimeType'] = 'image/png'
for texture in document.get('textures', []):
    extension = texture.get('extensions', {}).pop('EXT_texture_webp', None)
    if extension:
        texture['source'] = extension['source']
    if not texture.get('extensions'):
        texture.pop('extensions', None)
for key in ['extensionsUsed', 'extensionsRequired']:
    document[key] = [x for x in document.get(key, []) if x not in ['KHR_mesh_quantization', 'EXT_texture_webp']]
    if not document[key]:
        del document[key]
while len(binary) % 4:
    binary.append(0)
document['buffers'][0]['byteLength'] = len(binary)
encoded = json.dumps(document, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
result = (struct.pack('<III', 0x46546C67, 2, 28 + len(encoded) + len(binary))
          + struct.pack('<II', len(encoded), 0x4E4F534A) + encoded
          + struct.pack('<II', len(binary), 0x004E4942) + binary)
target.write_bytes(result)
print('Converted server GLB', len(result), hashlib.sha256(result).hexdigest())
