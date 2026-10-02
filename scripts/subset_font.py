"""Development-only: regenerate the bundled TC font after changing UI copy."""
from pathlib import Path
import sys
from fontTools import subset

root = Path(__file__).resolve().parents[1]
characters = "".join(p.read_text(encoding="utf-8") for folder in ("scripts", "companion") for p in (root / folder).glob("*.*") if p.suffix in (".gd", ".py"))
characters += "".join(chr(i) for i in range(32, 127)) + "一二三四五六日週星期年月便當…—↗●×"
options = subset.Options()
options.font_number = 3  # Traditional Chinese face in Debian's Noto CJK collection.
font = subset.load_font(sys.argv[1], options)
subsetter = subset.Subsetter(options=options)
subsetter.populate(text=characters)
subsetter.subset(font)
# Subset has CFF outlines, so write an OpenType file.
subset.save_font(font, str(root / "assets/fonts/buddy.otf"), options)
