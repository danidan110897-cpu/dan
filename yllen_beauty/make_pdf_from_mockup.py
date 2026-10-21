#!/usr/bin/env python3
"""PDF fronte/retro costruito dalle immagini originali del mockup (source/mockup.webp).

Pagine: 1 fronte biglietto, 2 retro biglietto (QR sostituito con uno vero), 3 fronte abbonamento,
4 retro abbonamento (= logo del fronte biglietto).
Uso: python3 make_pdf_from_mockup.py "https://URL-NOTINO" [output.pdf]
"""
import io
import os
import sys

import numpy as np
import qrcode
from PIL import Image
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader

HERE = os.path.dirname(os.path.abspath(__file__))
URL = sys.argv[1] if len(sys.argv) > 1 else "https://www.notino.ro/saloane/kataleya-beauty-center/"
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "yllen_beauty.pdf")

im = Image.open(os.path.join(HERE, "source", "mockup.webp")).convert("RGB")
# bordi misurati delle tre carte nel mockup (px), tolti ~3px di ombra
c1 = im.crop((62, 101, 749, 508))     # fronte biglietto
c2 = im.crop((798, 101, 1478, 508))   # retro biglietto
c3 = im.crop((356, 563, 1177, 970))   # fronte abbonamento
UP = 2

# QR: area moduli nel retro (coordinate del crop c2), sfondo del riquadro campionato
QX, QY, QS = 424, 134, 102
bg = tuple(int(v) for v in np.median(np.asarray(c2.crop((415, 140, 421, 230))).reshape(-1, 3), axis=0))
c2p = c2.copy()
c2p.paste(bg, (416, 128, 534, 241))

# retro abbonamento: logo del fronte biglietto portato al formato 2:1 (taglio lieve sopra/sotto + stiramento ~9%)
w, h = c1.size
ch = round(w / 1.83); t = (h - ch) // 2 + 4
c4 = c1.crop((0, t, w, t + ch)).resize(c3.size, Image.LANCZOS)


def page(c, img, wmm, qr=False):
    hmm = wmm * img.height / img.width
    c.setPageSize((wmm * mm, hmm * mm))
    big = img.resize((img.width * UP, img.height * UP), Image.LANCZOS)
    buf = io.BytesIO(); big.save(buf, "JPEG", quality=93, subsampling=0); buf.seek(0)
    c.drawImage(ImageReader(buf), 0, 0, wmm * mm, hmm * mm)
    if qr:
        s = wmm * mm / img.width
        q = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, border=0)
        q.add_data(URL); q.make(fit=True)
        m = q.get_matrix(); n = len(m); u = QS / n
        lo, hi = n * 0.41, n * 0.59  # buco centrale per il cuore (~3% dell'area, ben entro il 15% di M)
        c.setFillColorRGB(0.1, 0.08, 0.08)
        for r in range(n):
            for k in range(n):
                if m[r][k] and not (lo <= r < hi and lo <= k < hi):
                    c.rect((QX + k * u) * s, (img.height - QY - (r + 1) * u) * s, u * s + 0.05, u * s + 0.05, stroke=0, fill=1)
        cx, cy, hs = (QX + QS / 2) * s, (img.height - QY - QS / 2) * s, QS * 0.1 * s
        p = c.beginPath(); p.moveTo(cx, cy - 0.5 * hs)
        p.curveTo(cx - 0.9 * hs, cy + 0.1 * hs, cx - 0.5 * hs, cy + 0.7 * hs, cx, cy + 0.3 * hs)
        p.curveTo(cx + 0.5 * hs, cy + 0.7 * hs, cx + 0.9 * hs, cy + 0.1 * hs, cx, cy - 0.5 * hs)
        c.drawPath(p, stroke=0, fill=1)
    c.showPage()


cv = canvas.Canvas(OUT); cv.setTitle("Yllen Beauty - biglietto e abbonamento")
page(cv, c1, 90); page(cv, c2p, 90, qr=True); page(cv, c3, 100); page(cv, c4, 100)
cv.save(); print("scritto", OUT, "| QR ->", URL)
