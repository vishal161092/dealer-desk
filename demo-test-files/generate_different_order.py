#!/usr/bin/env python3
"""
Generate a GENUINELY DIFFERENT order sheet (verification file).

Unlike the three canonical demo files (which all dictate the same 8-line /
73-unit / Rs 2,82,500 order == the demo fallback, so a real read looks identical
to the fallback), this sheet uses a DIFFERENT product mix and quantities. A real
extraction therefore produces a visibly different table; a silent fallback would
still show the canonical 8-line demo order. Combined with the on-card source
badge, this proves whether the file is actually being read.

Products deliberately chosen from catalogue entries NOT present in the demo order
(Smoke Grey enamel, Supwhite 4 L, 30 KG putty, TE1 10 L).

  order_sheet_different.pdf   -> expect 5 lines, 69 units, Rs 2,51,900

Run:  python3 generate_different_order.py
"""
import os

OUT = os.path.dirname(os.path.abspath(__file__))

# (Product name as written on the sheet, Pack, Qty)  -- maps to NEW catalogue SKUs
SHEET_ROWS = [
    ("Glosscoat Gloss Enamel Smoke Grey", "4 L", 10),   # HL000000008 @ 100
    ("Fieldcoat Emulsion Supwhite", "4 L", 25),      # HL000000014 @ 5700
    ("Hueline Wall Putty White", "30 KG", 7),        # HL000000030 @ 7900
    ("Fieldcoat Emulsion TE1", "10 L", 9),           # HL000000019 @ 5700
    ("Glosscoat Gloss Enamel Smoke Grey", "1 L", 18),   # HL000000007 @ 100
]


def make_order_sheet_pdf():
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import mm
    from reportlab.lib import colors
    from reportlab.platypus import (SimpleDocTemplate, Table, TableStyle,
                                    Paragraph, Spacer)
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle

    path = os.path.join(OUT, "order_sheet_different.pdf")
    doc = SimpleDocTemplate(path, pagesize=A4,
                            topMargin=20 * mm, bottomMargin=20 * mm,
                            leftMargin=22 * mm, rightMargin=22 * mm)
    styles = getSampleStyleSheet()
    h = ParagraphStyle("h", parent=styles["Title"], fontSize=18, spaceAfter=2)
    sub = ParagraphStyle("sub", parent=styles["Normal"], fontSize=10,
                         textColor=colors.HexColor("#555555"))

    story = [
        Paragraph("Lakeview Colour &amp; Hardware", h),
        Paragraph("Weekly order &nbsp;·&nbsp; Dealer HL-PUN-04417 &nbsp;·&nbsp; "
                  "Pune West · Kothrud &nbsp;·&nbsp; Mon 05 Oct 2026", sub),
        Spacer(1, 10 * mm),
    ]

    data = [["#", "Product", "Pack", "Qty"]]
    units = 0
    for i, (name, pack, qty) in enumerate(SHEET_ROWS, 1):
        data.append([str(i), name, pack, str(qty)])
        units += qty
    data.append(["", "Total", "", str(units)])

    tbl = Table(data, colWidths=[12 * mm, 95 * mm, 25 * mm, 20 * mm])
    tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#C8102E")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 11),
        ("ALIGN", (0, 0), (0, -1), "CENTER"),
        ("ALIGN", (3, 0), (3, -1), "CENTER"),
        ("ROWBACKGROUNDS", (0, 1), (-1, -2), [colors.white, colors.HexColor("#F4F4F4")]),
        ("LINEBELOW", (0, 0), (-1, 0), 0.5, colors.white),
        ("LINEABOVE", (0, -1), (-1, -1), 0.75, colors.HexColor("#C8102E")),
        ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
        ("GRID", (0, 0), (-1, -2), 0.25, colors.HexColor("#DDDDDD")),
    ]))
    story.append(tbl)
    story.append(Spacer(1, 8 * mm))
    story.append(Paragraph(
        "5 lines &nbsp;·&nbsp; 69 units. Please deliver to Bhosari depot. "
        "— Anil Verma", sub))
    doc.build(story)
    print("wrote", path)


if __name__ == "__main__":
    make_order_sheet_pdf()
