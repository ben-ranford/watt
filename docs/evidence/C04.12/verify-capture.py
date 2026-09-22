"""Validate native evidence identity/geometry, never claim pixel parity."""
import json
from pathlib import Path

root = Path(__file__).resolve().parent
capture = json.loads((root / 'capture.json').read_text())
expected = {
    'fixture': 'C04.12/base', 'node': '24:1960',
    'component': '24:2076', 'anchor': '24:2078',
    'actualButtonClass': 'NSStatusBarButton',
    'appearance': 'NSAppearanceNameAqua', 'selected': False,
    'customBackdrop': False, 'resampled': False,
    'bitmap1xPixels': [560, 44], 'bitmap1xPoints': [560, 44],
    'buttonFrame': '{{204, 15}, {97, 24}}',
}
for key, value in expected.items():
    assert capture[key] == value, (key, capture[key], value)
print('PASS: exact C04.12 identity, native Aqua/unselected/no-paint, 1x geometry')
