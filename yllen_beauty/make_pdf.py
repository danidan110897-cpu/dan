#!/usr/bin/env python3
"""Yllen Beauty - biglietto da visita (fronte/retro) + abbonamento 5 sedute, in PDF vettoriale.

Uso:  python3 make_pdf.py "https://URL-PAGINA-NOTINO" [output.pdf]
Le pagine includono 3 mm di abbondanza (bleed) per lato; i segni di taglio sono a 3 mm dal bordo.
"""
import math
import os
import random
import sys

import qrcode
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = os.environ.get("YLLEN_FONTS", os.path.join(HERE, "fonts"))
for name, f in [("Title", "PlayfairDisplay.ttf"), ("Script", "GreatVibes-Regular.ttf"),
                ("Serif", "CormorantGaramond.ttf"), ("SerifIt", "CormorantGaramond-Italic.ttf")]:
    pdfmetrics.registerFont(TTFont(name, os.path.join(FONT_DIR, f)))

URL = sys.argv[1] if len(sys.argv) > 1 else "https://www.notino.ro/"
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "yllen_beauty.pdf")

PAPER = (0.953, 0.922, 0.890)
PINK = (0.769, 0.380, 0.490)
INK = (0.10, 0.08, 0.08)
BURG = (0.43, 0.07, 0.16)
BURG2 = (0.55, 0.11, 0.22)
P1, P2, P3 = (0.96, 0.78, 0.83), (0.98, 0.86, 0.89), (0.91, 0.56, 0.67)
RIB, RIB_L = (0.91, 0.64, 0.72), (0.96, 0.78, 0.83)
LEAF = (0.35, 0.28, 0.20)
B = 3  # bleed mm


class Card:
    """Coordinate in mm con origine in alto a sinistra del taglio finale."""

    def __init__(self, c, w, h):
        self.c, self.w, self.h = c, w, h
        c.setPageSize(((w + 2 * B) * mm, (h + 2 * B) * mm))
        c.setFillColorRGB(*PAPER)
        c.rect(0, 0, (w + 2 * B) * mm, (h + 2 * B) * mm, stroke=0, fill=1)
        self.paper_texture()

    def X(self, x): return (x + B) * mm
    def Y(self, y): return (self.h - y + B) * mm

    def paper_texture(self):
        rnd = random.Random(3)
        c = self.c
        c.setStrokeColorRGB(0.90, 0.86, 0.82)
        c.setLineWidth(0.15)
        for _ in range(60):  # tenui venature di carta
            x, y = rnd.uniform(-3, self.w + 3), rnd.uniform(-3, self.h + 3)
            p = c.beginPath(); p.moveTo(self.X(x), self.Y(y))
            for _ in range(3):
                x += rnd.uniform(-6, 6); y += rnd.uniform(-6, 6)
                p.lineTo(self.X(x), self.Y(y))
            c.drawPath(p, stroke=1, fill=0)

    # ---- testo ----
    def text(self, s, x, y, font, size, color=INK, anchor="l", space=0, rot=0):
        c = self.c
        c.saveState()
        c.setFillColorRGB(*color)
        c.translate(self.X(x), self.Y(y)); c.rotate(rot)
        w = pdfmetrics.stringWidth(s, font, size) + space * (len(s) - 1)
        off = {"l": 0, "c": -w / 2, "r": -w}[anchor]
        t = c.beginText(off, 0); t.setFont(font, size); t.setCharSpace(space); t.textOut(s)
        c.drawText(t); c.restoreState()

    def fit(self, s, x, y, font, width_mm, color=INK, anchor="l"):
        size = width_mm * mm / pdfmetrics.stringWidth(s, font, 1)
        self.text(s, x, y, font, size, color, anchor)

    # ---- grafica ----
    def line(self, x1, y1, x2, y2, color=PINK, w=0.2):
        self.c.setStrokeColorRGB(*color); self.c.setLineWidth(w)
        self.c.line(self.X(x1), self.Y(y1), self.X(x2), self.Y(y2))

    def heart(self, cx, cy, s, color=PINK):
        c = self.c; c.setFillColorRGB(*color)
        x, y, k = self.X(cx), self.Y(cy), s * mm
        p = c.beginPath()
        p.moveTo(x, y - 0.5 * k)
        p.curveTo(x - 0.9 * k, y + 0.1 * k, x - 0.5 * k, y + 0.7 * k, x, y + 0.3 * k)
        p.curveTo(x + 0.5 * k, y + 0.7 * k, x + 0.9 * k, y + 0.1 * k, x, y - 0.5 * k)
        c.drawPath(p, stroke=0, fill=1)

    def divider(self, cx, y, half=14, color=PINK):
        self.line(cx - half, y, cx - 2.5, y, color, 0.2)
        self.line(cx + 2.5, y, cx + half, y, color, 0.2)
        self.heart(cx, y - 0.55, 2.2, color)

    def petals(self, cx, cy, r, n, col, rot=0, wide=0.55, seed=0):
        rnd = random.Random(seed)
        c = self.c; c.setFillColorRGB(*col)
        for i in range(n):
            a = rot + i * 360 / n + rnd.uniform(-6, 6)
            c.saveState(); c.translate(self.X(cx), self.Y(cy)); c.rotate(a)
            rr = r * rnd.uniform(0.9, 1.05)
            c.ellipse(-rr * wide * mm, 0, rr * wide * mm, rr * 1.0 * mm, stroke=0, fill=1)
            c.restoreState()

    def flower(self, cx, cy, r, kind="pink", seed=0):
        if kind == "peony":
            for i, (k, col) in enumerate([(1.0, BURG), (0.8, BURG2), (0.6, BURG), (0.42, (0.62, 0.15, 0.28)),
                                          (0.25, BURG)]):
                self.petals(cx, cy, r * k, 9 - i, col, rot=i * 20, wide=0.6, seed=seed + i)
            self.c.setFillColorRGB(0.78, 0.55, 0.3); self.c.circle(self.X(cx), self.Y(cy), r * 0.07 * mm, 0, 1)
        else:
            col = {"pink": P1, "light": P2, "deep": P3}[kind]
            self.petals(cx, cy, r, 7, col, wide=0.5, seed=seed)
            self.petals(cx, cy, r * 0.6, 6, tuple(min(1, v * 0.96) for v in P3) if kind != "deep" else P1,
                        rot=25, wide=0.45, seed=seed + 1)
            self.c.setFillColorRGB(0.85, 0.45, 0.5); self.c.circle(self.X(cx), self.Y(cy), r * 0.1 * mm, 0, 1)

    def leaf(self, cx, cy, l, ang):
        c = self.c; c.setFillColorRGB(*LEAF)
        c.saveState(); c.translate(self.X(cx), self.Y(cy)); c.rotate(ang)
        c.ellipse(-l * 0.22 * mm, 0, l * 0.22 * mm, l * mm, stroke=0, fill=1); c.restoreState()

    def blossom_twig(self, x, y, dx, dy, seed=0, n=6):
        rnd = random.Random(seed)
        self.c.setStrokeColorRGB(*LEAF); self.c.setLineWidth(0.25)
        px, py = x, y
        for i in range(n):
            nx, ny = px + dx / n + rnd.uniform(-1, 1), py + dy / n + rnd.uniform(-1, 1)
            self.line(px, py, nx, ny, LEAF, 0.25)
            self.flower(nx + rnd.uniform(-1, 1), ny + rnd.uniform(-1, 1), rnd.uniform(1.0, 1.6),
                        rnd.choice(["pink", "deep", "light"]), seed=seed + i)
            px, py = nx, ny

    def bow(self, cx, cy, s=1.0, rot=0):
        c = self.c
        c.saveState(); c.translate(self.X(cx), self.Y(cy)); c.rotate(rot); c.scale(s, s)
        m = mm
        for col, off in [(RIB, 0), (RIB_L, 0.5)]:
            c.setFillColorRGB(*col)
            for sgn in (-1, 1):  # anelli
                p = c.beginPath(); p.moveTo(0, 0)
                p.curveTo(sgn * 4 * m, 9 * m - off * m, sgn * 17 * m, 11 * m, sgn * 18 * m, 2 * m)
                p.curveTo(sgn * 18 * m, -6 * m, sgn * 5 * m, -6 * m + off * m, 0, 0)
                c.drawPath(p, stroke=0, fill=1)
            if off == 0:  # code
                for sgn, ex in ((-1, -12), (1, 10)):
                    p = c.beginPath(); p.moveTo(0, 0)
                    p.curveTo(sgn * 2 * m, -8 * m, ex * m, -14 * m, (ex + sgn * 2) * m, -22 * m)
                    p.lineTo((ex + 5 * sgn) * m, -20 * m)
                    p.curveTo((ex + 2) * m, -12 * m, 2 * m, -6 * m, 0, 0)
                    c.drawPath(p, stroke=0, fill=1)
        c.setFillColorRGB(*RIB); c.setStrokeColorRGB(0.82, 0.5, 0.6); c.setLineWidth(0.3)
        c.roundRect(-2.6 * m, -2.6 * m, 5.2 * m, 5.2 * m, 1.5 * m, stroke=1, fill=1)
        c.restoreState()

    def streamer(self, pts, width=2.2):
        """Nastro lungo che scende dal fiocco: curva spessa con riflesso."""
        c = self.c
        for col, w in [(RIB, width), (RIB_L, width * 0.35)]:
            c.setStrokeColorRGB(*col); c.setLineWidth(w * mm); c.setLineCap(1)
            p = c.beginPath(); p.moveTo(self.X(pts[0][0]), self.Y(pts[0][1]))
            for i in range(1, len(pts) - 2, 3):
                p.curveTo(*[v for pt in pts[i:i + 3] for v in (self.X(pt[0]), self.Y(pt[1]))])
            c.drawPath(p, stroke=1, fill=0)

    def butterfly(self, cx, cy, s=1.0, rot=0):
        c = self.c
        c.saveState(); c.translate(self.X(cx), self.Y(cy)); c.rotate(rot); c.scale(s, s)
        c.setFillColorRGB(0.93, 0.78, 0.66); c.setStrokeColorRGB(0.55, 0.38, 0.30); c.setLineWidth(0.15)
        for sg in (-1, 1):
            c.ellipse(sg * 0.3 * mm, 0, sg * 3.4 * mm, 2.6 * mm, stroke=1, fill=1)
            c.ellipse(sg * 0.3 * mm, -2.4 * mm, sg * 2.4 * mm, 0, stroke=1, fill=1)
        c.setFillColorRGB(0.35, 0.25, 0.2); c.ellipse(-0.3 * mm, -2 * mm, 0.3 * mm, 2 * mm, stroke=0, fill=1)
        c.restoreState()

    def corner_cluster(self, corner, scale=1.0, seed=0):
        """Mazzetto di fiori ancorato a un angolo (bl / br)."""
        rnd = random.Random(seed)
        w, h = self.w, self.h
        ax = 0 if corner == "bl" else w
        sg = 1 if corner == "bl" else -1
        spots = [(2, 1.5, 6, "peony"), (9, 1.0, 5.2, "light"), (14, 2.4, 4.4, "pink"), (5, 7.5, 4.6, "pink"),
                 (13, 6.5, 3.6, "peony"), (19, 1.8, 3.8, "deep")]
        for i, (dx, dy, r, k) in enumerate(spots):
            x, y = ax + sg * (dx * scale + 2), h - (dy * scale + 1.5)
            self.leaf(x, y, 5 * scale, rnd.uniform(0, 360)); self.leaf(x, y, 4 * scale, rnd.uniform(0, 360))
            self.flower(x, y, r * scale, k, seed=seed + i)
        self.blossom_twig(ax + sg * 3, h - 6 * scale, sg * 4, -14 * scale, seed=seed + 11, n=5)


def qr_box(card, x, y, size, url):
    """QR vettoriale (correzione errori H) con cuore al centro, come nel mockup."""
    q = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H, border=0)
    q.add_data(url); q.make(fit=True)
    m = q.get_matrix(); n = len(m); u = size / n
    c = card.c; c.setFillColorRGB(*INK)
    hole = n * 0.18  # moduli lasciati liberi al centro (~3% area: ben entro il 30% di H)
    lo, hi = (n - hole) / 2, (n + hole) / 2
    for r in range(n):
        for k in range(n):
            if m[r][k] and not (lo <= r < hi and lo <= k < hi):
                c.rect(card.X(x + k * u), card.Y(y + (r + 1) * u), u * mm + 0.05, u * mm + 0.05, stroke=0, fill=1)
    card.heart(x + size / 2, y + size / 2, size * 0.1, INK)


def crop_marks(c, w, h):
    c.setStrokeColorRGB(0, 0, 0); c.setLineWidth(0.2)
    for x in (B, B + w):
        for y0, y1 in ((0, B - 0.8), (B + h + 0.8, h + 2 * B)):
            c.line(x * mm, y0 * mm, x * mm, y1 * mm)
    for y in (B, B + h):
        for x0, x1 in ((0, B - 0.8), (B + w + 0.8, w + 2 * B)):
            c.line(x0 * mm, y * mm, x1 * mm, y * mm)


def front(c, w=85):
    h, d = 55, w - 85  # d = larghezza extra rispetto al biglietto da visita
    k = Card(c, w, h)
    k.streamer([(70 + d, 11), (80 + d, 12), (84 + d, 20), (82 + d, 30), (80 + d, 40), (82 + d, 46), (82 + d, 49)], 1.2)
    k.bow(68 + d, 9, 0.55, 8)
    k.corner_cluster("bl", 1.0, seed=1)
    xs = [26, 33, 40, 48, 55, 62, 70]
    for i, (x, f) in enumerate(zip(xs, ["pink", "light", "peony", "pink", "deep", "peony", "pink"])):
        x = 26 + (x - 26) * (44 + d) / 44
        k.leaf(x, h - 2, 5, 40 * i); k.flower(x, h - 2.6, 3.0 + (i % 3) * 0.5, f, seed=20 + i)
    k.butterfly(77 + d, 44, 0.9, -20)
    cx = 41.5 + d / 2
    k.fit("YLLEN BEAUTY", cx, 20.5, "Title", 54, INK, "c")
    k.fit("Beauty & Care", cx, 27.5, "Script", 31, PINK, "c")
    k.divider(cx, 33.5, 11)
    # il cuore tra le voci e' disegnato a mano: spezzo la riga in 4 voci
    items = ["COSMETICĂ", "EPILAT", "MASAJ", "TRATAMENTE FACIALE"]
    f, sz, sp = "Serif", 5.8, 0.7
    ws = [pdfmetrics.stringWidth(t, f, sz) / mm + sp * (len(t) - 1) / mm for t in items]
    gap = 4.4
    total = sum(ws) + gap * 3
    x = cx + 1 - total / 2
    for i, t in enumerate(items):
        k.text(t, x, 37.8, f, sz, INK, "l", sp)
        x += ws[i]
        if i < 3:
            k.heart(x + gap / 2, 37.2, 1.7, PINK)
            x += gap
    crop_marks(c, w, h); c.showPage()


def back(c, url):
    w, h = 85, 55
    k = Card(c, w, h)
    k.streamer([(70, 3), (77, 3), (82, 7), (83, 12), (82, 17)], 1.6)
    k.bow(70, 5, 0.5, -5)
    k.corner_cluster("br", 0.62, seed=5)
    k.butterfly(70, 44, 0.8, 20)
    rows = [(24.4, "phone", "+40732775010"), (32.6, "ig", "yllen.beauty"), (40.8, "pin", "Strada Culturii 13")]
    # le coordinate sono riportate al pannello di 85x55 mm
    ys = [20.5 - 0.5 + 3.5, 28.5 + 0.0, 36.0]
    for yy, (_, kind, txt) in zip((9.4, 16.4, 23.4), rows):
        k.c.setFillColorRGB(*PINK); k.c.circle(k.X(12), k.Y(yy), 3.1 * mm, 0, 1)
        k.c.setStrokeColorRGB(1, 0.97, 0.96); k.c.setFillColorRGB(1, 0.97, 0.96); k.c.setLineWidth(0.3)
        cx, cy = k.X(12), k.Y(yy)
        if kind == "phone":
            k.c.setLineWidth(0.9); k.c.setLineCap(1)
            p = k.c.beginPath(); p.moveTo(cx - 1.1 * mm, cy + 1.1 * mm)
            p.curveTo(cx - 0.9 * mm, cy - 0.5 * mm, cx + 0.5 * mm, cy - 1.0 * mm, cx + 1.1 * mm, cy - 1.1 * mm)
            k.c.drawPath(p, stroke=1, fill=0)
            k.c.setLineWidth(0.3); k.c.setLineCap(0)
        elif kind == "ig":
            k.c.roundRect(cx - 1.1 * mm, cy - 1.1 * mm, 2.2 * mm, 2.2 * mm, 0.6 * mm, stroke=1, fill=0)
            k.c.circle(cx, cy, 0.55 * mm, 1, 0)
        else:
            k.c.circle(cx, cy + 0.2 * mm, 0.95 * mm, 1, 0)
            p = k.c.beginPath(); p.moveTo(cx - 0.85 * mm, cy - 0.25 * mm); p.lineTo(cx, cy - 1.5 * mm)
            p.lineTo(cx + 0.85 * mm, cy - 0.25 * mm); k.c.drawPath(p, stroke=1, fill=0)
        k.text(txt, 17.5, yy + 1.1, "Title", 9.2 if kind != "pin" else 8.2, INK)
    k.text("(la Kataleya Beauty Center)", 17.5, 27.4, "Serif", 7.2, INK)
    k.text("Programează-te acum!", 11, 36.8, "Script", 12.5, PINK, rot=3)
    k.divider(23, 40.2, 12)
    k.text("Scanează QR code-ul și accesează", 11, 45.5, "Serif", 6.6, INK)
    k.text("pagina de programări Notino.", 11, 49, "Serif", 6.6, INK)
    # riquadro QR
    k.c.setStrokeColorRGB(*PINK); k.c.setLineWidth(0.3); k.c.setFillColorRGB(0.97, 0.94, 0.92)
    k.c.roundRect(k.X(54), k.Y(38), 18 * mm, 21.6 * mm, 2.6 * mm, stroke=1, fill=1)
    qr_box(k, 55.6, 18.4, 14.8, url)
    k.text("NOTINO", 63, 35.8, "Title", 4.4, INK, "c", 0.4)
    crop_marks(c, w, h); c.showPage()


def abbonamento(c):
    w, h = 98, 55
    k = Card(c, w, h)
    k.corner_cluster("bl", 0.62, seed=2)
    k.corner_cluster("br", 0.5, seed=9)
    k.streamer([(88, 5), (93, 4.5), (97, 8), (97, 12)], 1.1)
    k.bow(88, 4.5, 0.45, -4)
    k.butterfly(88.5, 36, 0.7, 15)
    k.fit("YLLEN BEAUTY", 7.8, 7.8, "Title", 40.5, INK, "l")
    k.fit("Abonament Beauty", 51.5, 7.2, "Script", 30.5, PINK, "l")
    k.line(20.7, 10.4, 39.5, 10.4); k.line(59.5, 10.4, 76.8, 10.4)
    k.text("5 ȘEDINȚE", 49, 11.4, "Serif", 8.5, INK, "c", 1.2)
    k.text("Serviciu:", 14, 16.4, "SerifIt", 8.6, INK)
    k.line(25.2, 16.6, 84.7, 16.6, INK, 0.2)
    k.text("Clientă:", 14, 21.2, "SerifIt", 8.6, INK)
    k.line(24, 21.4, 84.7, 21.4, INK, 0.2)
    for i in range(5):
        cx, cy, n = 23.7 + i * 12.6, 27.4, 12
        k.c.setStrokeColorRGB(*PINK); k.c.setLineWidth(0.25)
        p = k.c.beginPath()
        for j in range(n * 10 + 1):
            a = 2 * math.pi * j / (n * 10)
            r = 3.5 + 0.3 * math.cos(n * a)
            x, y = k.X(cx + r * math.cos(a)), k.Y(cy + r * math.sin(a))
            p.moveTo(x, y) if j == 0 else p.lineTo(x, y)
        p.close(); k.c.drawPath(p, stroke=1, fill=0)
        k.heart(cx, cy, 1.7, PINK)
        k.text(str(i + 1), cx, cy + 6.6, "Serif", 7.5, INK, "c")
    k.text("Valabil de la:", 22.5, 38.6, "SerifIt", 7.2, INK)
    k.line(36, 38.8, 73, 38.8, INK, 0.2)
    k.text("Valabil până la:", 22.5, 42.4, "SerifIt", 7.2, INK)
    k.line(38.5, 42.6, 73, 42.6, INK, 0.2)
    k.text("Abonamentul este personal și valabil pentru serviciul ales.", 47, 46.4, "SerifIt", 5.6, INK, "c")
    k.text("Thank you", 75, 44, "Script", 8.5, PINK, rot=14)
    k.heart(80.5, 47.4, 1.2, PINK)
    crop_marks(c, w, h); c.showPage()


if __name__ == "__main__":
    cv = canvas.Canvas(OUT)
    cv.setTitle("Yllen Beauty - biglietto e abbonamento")
    front(cv); back(cv, URL); abbonamento(cv); front(cv, 98)
    cv.save()
    print("scritto", OUT, "| QR ->", URL)
