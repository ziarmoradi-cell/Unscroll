"""Apply non-secret bundle identifiers and generate a gentle original alarm sound."""
import math
import os
from pathlib import Path
import re
import struct
import wave
import json
import zlib

root = Path(__file__).resolve().parents[1]
bundle = os.environ.get("UNSCROLL_BUNDLE_ID", "com.ziarmoradicell.unscroll")
if not re.fullmatch(r"[A-Za-z0-9]+(?:\.[A-Za-z0-9-]+){2,}", bundle):
    raise SystemExit("UNSCROLL_BUNDLE_ID must be a valid reverse-domain identifier")
text = (root / "project.yml").read_text(encoding="utf-8")
# The original template stays unchanged, making configuration repeatable.
(root / "project.generated.yml").write_text(text.replace("com.example.unscroll", bundle), encoding="utf-8")
resources = root / "Resources"
resources.mkdir(exist_ok=True)
rate = 22050
with wave.open(str(resources / "gentle-wake.wav"), "wb") as output:
    output.setparams((1, 2, rate, 0, "NONE", "not compressed"))
    for i in range(rate * 12):
        t = i / rate
        envelope = min(1, t / 5) * min(1, (12 - t) / 1.5)
        pulse = 0.5 + 0.5 * math.cos(2 * math.pi * t / 3)
        value = envelope * pulse * (math.sin(2 * math.pi * 523.25 * t) + .35 * math.sin(2 * math.pi * 659.25 * t)) / 1.35
        output.writeframesraw(struct.pack("<h", round(value * 9000)))
print("Project configuration and alarm audio generated.")

# Original geometric U/arrow mark. RGB PNG avoids transparent App Store icons.
catalog = resources / "Assets.xcassets"
icon = catalog / "AppIcon.appiconset"
icon.mkdir(parents=True, exist_ok=True)
(catalog / "Contents.json").write_text(json.dumps({"info": {"author": "Unscroll", "version": 1}}))
(icon / "Contents.json").write_text(json.dumps({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "Unscroll", "version": 1}}))
rows = bytearray()
for y in range(1024):
    rows.append(0)
    for x in range(1024):
        arc = y >= 525 and 138**2 <= (x - 512)**2 + (y - 525)**2 <= 206**2
        stems = 308 <= x <= 376 and 312 <= y <= 525 or 648 <= x <= 716 and 310 <= y <= 525
        arrow = 275 <= y <= 396 and (abs(y - (958 - x)) < 38 and 584 <= x <= 683 or abs(y - (x - 408)) < 38 and 681 <= x <= 780)
        rows.extend(b'\x1c\x29\x13' if arc or stems or arrow else b'\xc4\xf1\x80')
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1024, 1024, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b'')
(icon / 'AppIcon.png').write_bytes(png)
print('App icon generated.')
