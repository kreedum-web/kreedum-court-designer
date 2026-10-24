#!/usr/bin/env python3
"""
Normalise a floor/court SVG so the Kreedum app can render and recolour it
reliably with flutter_svg.

What it does
  * strips XML comments
  * inlines simple <style> class rules (e.g. `.st0 {fill: pink}`) as attributes
  * converts luminance masks whose content is plain white shapes into clipPaths
    (identical result, far better renderer support) and drops full-canvas no-op masks
  * removes references to patterns / masks / clipPaths that don't exist
  * removes embedded <image>s that nothing displays (saves MBs)
  * marks the logo placeholder (<image id="logo_id">) with class="logo_slot"
    and swaps its picture for the default logo (--logo)

Usage
  python3 tools/normalize_svg.py IN.svg OUT.svg [--logo assets/brand/logo_slot.png]

Requires: pip install lxml
"""
import argparse
import base64
import re
import sys
from lxml import etree

SVG = "http://www.w3.org/2000/svg"
XLINK = "http://www.w3.org/1999/xlink"
HREFS = (f"{{{XLINK}}}href", "href")
NS = {"s": SVG}


def local(tag):
    return tag.split("}")[-1] if isinstance(tag, str) else ""


def parse_css(text):
    rules = {}
    for sel, body in re.findall(r"([^{}]+)\{([^}]*)\}", text):
        props = {}
        for decl in body.split(";"):
            if ":" in decl:
                k, v = decl.split(":", 1)
                props[k.strip()] = v.strip()
        for s in sel.split(","):
            s = s.strip()
            if s.startswith(".") and re.fullmatch(r"\.[\w-]+", s):
                rules.setdefault(s[1:], {}).update(props)
    return rules


def get_href(el):
    for h in HREFS:
        if el.get(h) is not None:
            return h, el.get(h)
    return None, None


def shrink_embedded(img, max_px=600):
    """Downscale huge embedded raster images (needs Pillow; skipped if missing)."""
    attr, h = get_href(img)
    if not h or not h.startswith("data:image/") or len(h) < 200_000:
        return
    try:
        import io
        from PIL import Image
    except ImportError:
        return
    data = base64.b64decode(h.split(",", 1)[1])
    pic = Image.open(io.BytesIO(data))
    if max(pic.size) <= max_px:
        return
    pic.thumbnail((max_px, max_px), Image.LANCZOS)
    buf = io.BytesIO()
    pic.save(buf, "PNG", optimize=True)
    img.set(attr, "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode())


def normalise(svg_bytes, logo_png=None):
    parser = etree.XMLParser(remove_comments=True, remove_blank_text=False, huge_tree=True)
    root = etree.fromstring(svg_bytes, parser)

    # 1. inline <style> class rules
    rules = {}
    for st in root.iter(f"{{{SVG}}}style"):
        rules.update(parse_css(st.text or ""))
    for st in list(root.iter(f"{{{SVG}}}style")):
        st.getparent().remove(st)
    if rules:
        for el in root.iter():
            for cls in (el.get("class") or "").split():
                for k, v in rules.get(cls, {}).items():
                    if k in ("enable-background",):
                        continue
                    if el.get(k) is None:
                        el.set(k, v)
    if root.get("style") and "enable-background" in root.get("style"):
        del root.attrib["style"]

    ids = {el.get("id"): el for el in root.iter() if el.get("id")}

    # 2. masks -> clipPaths (only when every mask child is a plain white shape)
    vb = (root.get("viewBox") or "0 0 0 0").split()
    canvas_w, canvas_h = (float(vb[2]), float(vb[3])) if len(vb) == 4 else (0, 0)
    mask_action = {}
    for m in list(root.iter(f"{{{SVG}}}mask")):
        kids = [k for k in m if isinstance(k.tag, str)]
        white = all((k.get("fill") or "").lower() in ("white", "#fff", "#ffffff") for k in kids) and kids
        full = (
            white and len(kids) == 1 and float(m.get("width", 0) or 0) >= canvas_w
            and float(m.get("height", 0) or 0) >= canvas_h and m.get("x", "0") == "0" and m.get("y", "0") == "0"
        )
        if full:
            mask_action[m.get("id")] = ("drop", None)
            m.getparent().remove(m)
        elif white:
            cp = etree.Element(f"{{{SVG}}}clipPath", id=m.get("id") + "_clip")
            for k in kids:
                k2 = etree.fromstring(etree.tostring(k))
                if k2.get("fill-rule"):
                    k2.set("clip-rule", k2.get("fill-rule"))
                cp.append(k2)
            m.addprevious(cp)
            m.getparent().remove(m)
            mask_action[m.get("id")] = ("clip", cp.get("id"))
    ids = {el.get("id"): el for el in root.iter() if el.get("id")}

    # 3. fix references
    url_re = re.compile(r"url\(#([^)]+)\)")
    for el in root.iter():
        if not isinstance(el.tag, str):
            continue
        for attr in ("fill", "stroke", "clip-path", "mask", "filter"):
            v = el.get(attr)
            if not v:
                continue
            m = url_re.search(v)
            if not m:
                continue
            ref = m.group(1)
            if attr == "mask" and ref in mask_action:
                act, new = mask_action[ref]
                del el.attrib["mask"]
                if act == "clip":
                    if el.get("clip-path"):
                        # wrap to combine both clips
                        g = etree.Element(f"{{{SVG}}}g")
                        g.set("clip-path", f"url(#{new})")
                        el.addprevious(g)
                        g.append(el)
                    else:
                        el.set("clip-path", f"url(#{new})")
                continue
            if ref not in ids:
                if attr in ("fill", "stroke"):
                    el.set(attr, "none")
                else:
                    del el.attrib[attr]

    # 4. logo slot + unused images
    referenced = set()
    for el in root.iter():
        if not isinstance(el.tag, str):
            continue
        _, h = get_href(el)
        if h and h.startswith("#"):
            referenced.add(h[1:])
        for v in el.attrib.values():
            referenced.update(url_re.findall(v))
    logo_b64 = base64.b64encode(logo_png).decode() if logo_png else None
    for img in list(root.iter(f"{{{SVG}}}image")):
        in_defs = any(local(a.tag) in ("defs", "pattern", "symbol") for a in img.iterancestors())
        if img.get("id") == "logo_id" or "logo_slot" in (img.get("class") or ""):
            img.set("class", "logo_slot")
            if logo_b64:
                for h in HREFS:
                    if h in img.attrib:
                        del img.attrib[h]
                img.set(f"{{{XLINK}}}href", "data:image/png;base64," + logo_b64)
            continue
        if in_defs and img.get("id") not in referenced:
            img.getparent().remove(img)
            continue
        shrink_embedded(img)

    # 5. drop now-empty <defs>/<pattern>s that nothing references
    for p in list(root.iter(f"{{{SVG}}}pattern")):
        if p.get("id") not in referenced or not len(p):
            p.getparent().remove(p)
    for d in list(root.iter(f"{{{SVG}}}defs")):
        if not len(d):
            d.getparent().remove(d)

    return etree.tostring(root, xml_declaration=False, encoding="unicode")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--logo", help="PNG used as the default logo in logo slots")
    a = ap.parse_args()
    logo = open(a.logo, "rb").read() if a.logo else None
    out = normalise(open(a.src, "rb").read(), logo)
    with open(a.dst, "w", encoding="utf-8") as f:
        f.write(out)
    print(f"{a.src} -> {a.dst} ({len(out)//1024} KB)", file=sys.stderr)


if __name__ == "__main__":
    main()
