# Assemble les captures strip_*.png d'un dossier en une planche (4 colonnes, recadrée au centre).
import sys, glob
from PIL import Image
d = sys.argv[1]; out = sys.argv[2]; cols = int(sys.argv[3]) if len(sys.argv) > 3 else 6
files = sorted(glob.glob(d + "/strip_*.png"))
ims = []
for f in files:
    im = Image.open(f); w, h = im.size
    c = im.crop((w*0.28, h*0.15, w*0.72, h*0.85)).resize((352, 315))
    ims.append(c)
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (cols*352, rows*315), (0,0,0))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % cols)*352, (i//cols)*315))
sheet.save(out); print(out, len(ims))
