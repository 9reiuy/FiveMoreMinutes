"""
Generate 3 sharp, crystalline grayscale transition masks for TASK-020-B.
Resolution: 640x360, 8-bit Grayscale (Mode 'L').
Adheres strictly to the sharp shard / glass fracture specification (No soft noise, no circles).
"""

import math
import os
import random
from PIL import Image

WIDTH = 640
HEIGHT = 360

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "transitions", "masks")
os.makedirs(OUT_DIR, exist_ok=True)


def clamp(val, low=0, high=255):
    return max(low, min(high, int(val)))


def generate_mask_a_edge_fracture():
    """
    Mask A: Edge Fracture
    Inward erosion from all screen borders with irregular triangular sawteeth and razor blades.
    """
    rng = random.Random(42001)
    img = Image.new("L", (WIDTH, HEIGHT))
    pixels = img.load()

    # Pre-generate 64 angular tooth frequency / phase offsets
    tooth_frequencies = [rng.uniform(0.015, 0.05) for _ in range(8)]
    tooth_amplitudes = [rng.uniform(15.0, 45.0) for _ in range(8)]
    tooth_phases = [rng.uniform(0.0, math.pi * 2) for _ in range(8)]

    cx, cy = WIDTH / 2.0, HEIGHT / 2.0

    for y in range(HEIGHT):
        for x in range(WIDTH):
            # Distance to nearest border (normalized by half-extents)
            dist_left = x / cx
            dist_right = (WIDTH - 1 - x) / cx
            dist_top = y / cy
            dist_bottom = (HEIGHT - 1 - y) / cy

            base_border_dist = min(dist_left, dist_right, dist_top, dist_bottom)

            # Angular / linear sharp sawtooth perturbations
            angle = math.atan2(y - cy, x - cx)
            # Create triangular / sawtooth wave along perimeter
            sawtooth = 0.0
            for freq, amp, phase in zip(tooth_frequencies, tooth_amplitudes, tooth_phases):
                # Hard triangular wave: abs((t % 1) - 0.5) * 4 - 1
                t = (angle * freq * 10.0 + phase) / (2.0 * math.pi)
                tri = abs((t - math.floor(t)) - 0.5) * 4.0 - 1.0
                sawtooth += tri * (amp / 120.0)

            # High-frequency sharp razor blade spikes
            blade_spike = 0.0
            blade_phase = (x * 0.07 + y * 0.09)
            blade_saw = abs((blade_phase / 3.14159) - math.floor(blade_phase / 3.14159) - 0.5) * 2.0
            blade_spike = math.pow(blade_saw, 3.0) * 0.25

            # Combine: border starts at 0.0 (first to cover), center reaches 1.0 (last)
            fracture_metric = base_border_dist + sawtooth * 0.65 + blade_spike
            fracture_metric = max(0.0, min(1.0, fracture_metric / 1.15))

            val = clamp(fracture_metric * 255.0)
            pixels[x, y] = val

    out_path = os.path.join(OUT_DIR, "mask_edge_fracture.png")
    img.save(out_path)
    print(f"Mask A generated: {out_path} ({img.size})")


def generate_mask_b_shattered_memory():
    """
    Mask B: Shattered Memory
    Crystalline Voronoi shards with planar faceted slopes. Multiple sharp nucleus points.
    """
    rng = random.Random(20261012)
    img = Image.new("L", (WIDTH, HEIGHT))
    pixels = img.load()

    # 18 sharp crystal nucleus seeds across screen
    num_seeds = 20
    seeds = []
    for i in range(num_seeds):
        sx = rng.uniform(40, WIDTH - 40)
        sy = rng.uniform(30, HEIGHT - 30)
        # Random plane slope direction and base rank
        slope_angle = rng.uniform(0, math.pi * 2)
        slope_dx = math.cos(slope_angle)
        slope_dy = math.sin(slope_angle)
        base_priority = rng.uniform(0.0, 0.45)
        seeds.append((sx, sy, slope_dx, slope_dy, base_priority))

    for y in range(HEIGHT):
        for x in range(WIDTH):
            # Find closest seed and distance (Manhattan or L1/L-inf hybrid for straight crystal edges)
            best_dist = 1e9
            best_idx = 0
            for i, (sx, sy, _, _, _) in enumerate(seeds):
                # Octagonal / polygonal distance metric for sharp crystal faces
                dx = abs(x - sx)
                dy = abs(y - sy)
                d = max(dx, dy) * 0.7 + (dx + dy) * 0.4
                if d < best_dist:
                    best_dist = d
                    best_idx = i

            sx, sy, slope_dx, slope_dy, base_p = seeds[best_idx]
            # Planar facet inside crystal cell
            rel_x = (x - sx) / 80.0
            rel_y = (y - sy) / 80.0
            facet = (rel_x * slope_dx + rel_y * slope_dy) * 0.25

            cell_val = base_p + (best_dist / 220.0) + facet
            val = clamp(max(0.0, min(1.0, cell_val)) * 255.0)
            pixels[x, y] = val

    out_path = os.path.join(OUT_DIR, "mask_shattered_memory.png")
    img.save(out_path)
    print(f"Mask B generated: {out_path} ({img.size})")


def generate_mask_c_diagonal_tear():
    """
    Mask C: Diagonal Tear
    45-degree directional tearing wave front with sharp serrated razor sawteeth.
    """
    rng = random.Random(777)
    img = Image.new("L", (WIDTH, HEIGHT))
    pixels = img.load()

    for y in range(HEIGHT):
        for x in range(WIDTH):
            # Diagonal gradient: 0 at top-left to 1 at bottom-right
            diag_pos = (x + y * 1.3) / (WIDTH + HEIGHT * 1.3)

            # Sharp sawtooth tearing along diagonal wave front
            perp_pos = (x * 1.3 - y) * 0.08
            # Triangle wave
            t1 = abs(((perp_pos) % 2.0) - 1.0)
            t2 = abs(((perp_pos * 2.3 + 0.4) % 2.0) - 1.0)
            t3 = abs(((perp_pos * 5.1 + 1.2) % 2.0) - 1.0)

            teeth = (t1 * 0.12) + (t2 * 0.08) - (t3 * 0.04)

            # Diagonal slice stepped layers
            stepped_bias = math.floor(diag_pos * 8.0) / 8.0 * 0.15

            metric = diag_pos + teeth + stepped_bias
            val = clamp(max(0.0, min(1.0, metric / 1.15)) * 255.0)
            pixels[x, y] = val

    out_path = os.path.join(OUT_DIR, "mask_diagonal_tear.png")
    img.save(out_path)
    print(f"Mask C generated: {out_path} ({img.size})")


if __name__ == "__main__":
    generate_mask_a_edge_fracture()
    generate_mask_b_shattered_memory()
    generate_mask_c_diagonal_tear()
    print("All 3 sharp transition masks generated successfully.")
