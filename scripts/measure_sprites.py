"""Inspect alpha bounds and frame uniqueness; never modify generated PNG pixels."""
from pathlib import Path
import json
from PIL import Image

root = Path(__file__).resolve().parents[1] / 'assets/atelier'
result = {}
for path in sorted(root.glob('*.png')):
    if path.stem in ('knight', 'female', 'desk', 'monitor', 'lamp', 'window'):
        continue  # superseded drafts
    image = Image.open(path).convert('RGBA')
    width, height = image.size
    columns = 4 if path.stem.startswith(('knight_', 'female_')) else 2
    # Very low alpha dust from generation must not inflate layout measurements.
    opaque = image.getchannel('A').point(lambda value: 255 if value >= 128 else 0)
    bounds = []
    anchors = []
    for y in range(2):
        for x in range(columns):
            rect = (round(x * width / columns), round(y * height / 2), round((x + 1) * width / columns), round((y + 1) * height / 2))
            cell = opaque.crop(rect)
            box = cell.getbbox()
            bounds.append(box)
            if box:
                # Register feet / stand / pot, not moving arms, steam or leaves.
                bottom = cell.crop((0, box[3] - max(1, (box[3]-box[1])//4), cell.width, box[3])).getbbox()
                anchors.append([(bottom[0]+bottom[2])/2, box[3]])
    if any(b is None for b in bounds):
        raise ValueError(f'Empty frame in {path.name}')
    anchor_x, anchor_y = anchors[0]
    offsets = [[anchor_x - a[0], anchor_y - a[1]] for a in anchors]
    x0 = min(b[0] + o[0] for b, o in zip(bounds, offsets))
    y0 = min(b[1] + o[1] for b, o in zip(bounds, offsets))
    x1 = max(b[2] + o[0] for b, o in zip(bounds, offsets))
    y1 = max(b[3] + o[1] for b, o in zip(bounds, offsets))
    result[path.stem] = {'grid': [columns, 2], 'bounds': [x0, y0, x1-x0, y1-y0],
                         'offsets': offsets, 'size': [width, height]}
(root / 'metrics.json').write_text(json.dumps(result, indent=2) + '\n')
print('Measured', len(result), 'sprite sheets without changing source pixels')
