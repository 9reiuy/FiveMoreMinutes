"""Package actual game-camera captures; never synthesize gameplay frames."""
from pathlib import Path
from PIL import Image

folder = Path(__file__).resolve().parents[2] / ".runtime/phase_dash_20261022/live"
frames = [Image.open(folder / f"frame_{i:02d}.png").convert("RGB") for i in range(6)]
frames[0].save(folder / "phase_dash.gif", save_all=True, append_images=frames[1:], duration=65, loop=0)
