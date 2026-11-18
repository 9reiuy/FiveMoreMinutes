"""Build the original round-lobed mesh used by the isolated smoke preview.

Requires numpy. Output stays in .runtime beside the user's private tutorial
textures; no model or texture from a reverse-engineered game is imported.
"""
from pathlib import Path
import json

import numpy as np

DESTINATION = Path(__file__).resolve().parents[1] / ".runtime/stylized_smokes_tutorial_20261116"
CENTERS = np.array([
    [0, 0, 0], [-.34, -.08, .04], [.33, .02, .12],
    [-.12, .34, .04], [.15, -.32, -.02], [-.17, .06, -.33],
    [.19, .24, -.19], [.04, -.10, .33],
])
RADII = [.32, .26, .25, .24, .22, .23, .21, .24]
GRID = 23
BLEND = .055


def field(points):
    distance = np.linalg.norm(points - CENTERS[0], axis=-1) - RADII[0]
    for center, radius in zip(CENTERS[1:], RADII[1:]):
        other = np.linalg.norm(points - center, axis=-1) - radius
        blend = np.clip(.5 + .5 * (other - distance) / BLEND, 0, 1)
        distance = other * (1 - blend) + distance * blend - BLEND * blend * (1 - blend)
    return distance


def normal(points):
    offsets = np.eye(3) * .001
    gradient = np.stack([field(points + offset) - field(points - offset)
                         for offset in offsets], axis=-1)
    return gradient / np.maximum(np.linalg.norm(gradient, axis=-1, keepdims=True), 1e-9)


def main():
    axis = np.linspace(-.85, .85, GRID)
    points = np.stack(np.meshgrid(axis, axis, axis, indexing="ij"), axis=-1)
    values = field(points)
    corners = np.array([[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0],
                        [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]])
    tetrahedra = [[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6],
                  [0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6]]
    edges = [(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)]
    vertices = []
    for x in range(GRID - 1):
        for y in range(GRID - 1):
            for z in range(GRID - 1):
                indices = corners + [x, y, z]
                cube_values = values[tuple(indices.T)]
                if cube_values.min() >= 0 or cube_values.max() < 0:
                    continue
                cube_points = points[tuple(indices.T)]
                for tetrahedron in tetrahedra:
                    positions = cube_points[tetrahedron]
                    distances = cube_values[tetrahedron]
                    intersections = []
                    for a, b in edges:
                        if (distances[a] < 0) == (distances[b] < 0):
                            continue
                        fraction = distances[a] / (distances[a] - distances[b])
                        intersections.append(positions[a] + (positions[b] - positions[a]) * fraction)
                    if len(intersections) < 3:
                        continue
                    polygon = np.array(intersections)
                    midpoint = polygon.mean(axis=0)
                    direction = normal(midpoint)
                    u = polygon[0] - midpoint
                    u /= np.linalg.norm(u)
                    v = np.cross(direction, u)
                    order = np.argsort(np.arctan2((polygon - midpoint) @ v, (polygon - midpoint) @ u))
                    polygon = polygon[order]
                    for i in range(1, len(polygon) - 1):
                        triangle = polygon[[0, i, i + 1]].copy()
                        # Godot uses clockwise front faces.
                        if np.dot(np.cross(triangle[1] - triangle[0], triangle[2] - triangle[0]), direction) > 0:
                            triangle[[1, 2]] = triangle[[2, 1]]
                        vertices.extend(triangle)
    vertices = np.array(vertices)
    normals = normal(vertices)
    vertices *= .58 / np.linalg.norm(vertices, axis=-1).max()
    DESTINATION.mkdir(parents=True, exist_ok=True)
    vertices.astype("<f4").tofile(DESTINATION / "puff_vertices.f32")
    normals.astype("<f4").tofile(DESTINATION / "puff_normals.f32")
    manifest = {"vertices": len(vertices), "triangles": len(vertices) // 3,
                "radius": .58, "generator": "original smooth union of eight pronounced round smoke lobes", "grid": GRID}
    (DESTINATION / "puff_mesh_manifest.json").write_text(json.dumps(manifest) + "\n", encoding="utf-8")
    print(json.dumps(manifest))


if __name__ == "__main__":
    main()
