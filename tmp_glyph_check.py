import json, sys
data = json.load(sys.stdin)
glyphs = data.get("glyphs", [])
keywords = ["glory", "rank", "novice", "scout", "hero class", "kael", "progress"]
for g in glyphs:
    label = g.get("l", "")
    if any(word in label.lower() for word in keywords):
        y = g["y"]
        x = g["x"]
        w = g["w"]
        h = g["h"]
        ia = g.get("ia", False)
        wt = g["wt"]
        print(f"  y={y:7.1f}  x={x:7.1f}  w={w:6.1f}  h={h:5.1f}  ia={str(ia):5s}  wt={wt:20s}  l={repr(label)}")
