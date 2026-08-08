# -*- coding: utf-8 -*-
"""Overpass JSON çıktılarını kampüs POI JSON'una kürasyonlar (bir kerelik)."""
import json
import os
import math
import collections

BASE = r"C:\Users\TURAN\AppData\Local\Temp"
A = json.load(open(os.path.join(BASE, "overpass_a.json"), encoding="utf-8"))["elements"]
B = json.load(open(os.path.join(BASE, "overpass_b.json"), encoding="utf-8"))["elements"]
C = json.load(open(os.path.join(BASE, "overpass_c.json"), encoding="utf-8"))["elements"]

pois = []
routes = []
used_ids = set()


def _add(poi):
    if poi["id"] in used_ids:
        return
    used_ids.add(poi["id"])
    pois.append(poi)


def coord(e):
    return (e.get("lat") or (e.get("center") or {}).get("lat"),
            e.get("lon") or (e.get("center") or {}).get("lon"))


def haversine(a, b):
    R = 6371.0
    dlat = math.radians(b[0] - a[0])
    dlng = math.radians(b[1] - a[1])
    x = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(a[0])) * math.cos(math.radians(b[0])) * math.sin(dlng / 2) ** 2)
    return 2 * R * math.asin(math.sqrt(x))


# --- Yurtlar (B): Sakarya'da kalanlar. Kandıra (Kocaeli) ve isimsiz lojman hariç ---
for e in B:
    t = e.get("tags", {})
    lat, lon = coord(e)
    if lat is None:
        continue
    name = (t.get("name") or "").strip()
    low = name.lower()
    if low == "lojman" or "kand" in low:  # 'kandıra' → 'kand' (ASCII-safe)
        continue
    pois.append({
        "id": "yurt-%s" % e["id"], "name": name or "Öğrenci Yurdu",
        "category": "dormitory", "lat": round(lat, 5), "lng": round(lon, 5),
        "description": "Özel / KYK öğrenci yurdu", "address": t.get("addr:city", "Sakarya"),
    })

# --- Duraklar (A): highway=bus_stop — hepsi, isimsiz olanlar 'Durak' ---
for e in A:
    t = e.get("tags", {})
    if t.get("highway") != "bus_stop":
        continue
    lat, lon = coord(e)
    if lat is None:
        continue
    name = (t.get("name") or "").strip()
    pois.append({
        "id": "durak-%s" % e["id"], "name": name or "Otobüs Durağı",
        "category": "busStop", "lat": round(lat, 5), "lng": round(lon, 5),
        "description": "Otobüs durağı",
    })

# --- Ders çalışma (A): amenity=library ---
for e in A:
    t = e.get("tags", {})
    if t.get("amenity") != "library":
        continue
    lat, lon = coord(e)
    if lat is None:
        continue
    name = (t.get("name") or "").strip() or "Kütüphane"
    pois.append({
        "id": "calisma-%s" % e["id"], "name": name, "category": "study",
        "lat": round(lat, 5), "lng": round(lon, 5),
        "description": "Sessiz çalışma / kütüphane alanı",
    })

# --- Wi-Fi (A): kampüse yakın isimli kafeler (fiilen wifi + oturma alanı) ---
CAMPUS = (40.7408, 30.3333)
WHITELIST = {"Kampüs Kafeterya", "Lumo Coffee Sakarya Kampüs", "Taş Kafe", "Kantin"}
for e in A:
    t = e.get("tags", {})
    if t.get("amenity") != "cafe" or t.get("name") not in WHITELIST:
        continue
    lat, lon = coord(e)
    if lat is None or haversine(CAMPUS, (lat, lon)) > 2.0:
        continue
    pois.append({
        "id": "wifi-%s" % e["id"], "name": t["name"], "category": "wifi",
        "lat": round(lat, 5), "lng": round(lon, 5),
        "description": "Ücretsiz wi-fi + oturma alanı",
    })

# --- Rotalar (C) ---
way_geoms = {}
for e in C:
    if e["type"] == "way":
        g = [(round(p["lat"], 5), round(p["lon"], 5)) for p in e.get("geometry", [])]
        if g:
            way_geoms[e["id"]] = g


def simplify(pts, max_pts=80):
    if len(pts) <= max_pts:
        return pts
    step = len(pts) / max_pts
    out = [pts[0]]
    for i in range(1, max_pts - 1):
        out.append(pts[int(i * step)])
    out.append(pts[-1])
    return out


def to_points(g):
    return [{"lat": p[0], "lng": p[1]} for p in simplify(g)]


n_cycle = n_path = 0
for e in C:
    if e["type"] != "way":
        continue
    t = e.get("tags", {})
    hw = t.get("highway", "")
    g = way_geoms.get(e["id"], [])
    if len(g) < 3:
        continue
    if hw == "cycleway":
        cat = "bikeRoute"
        n_cycle += 1
    elif hw == "path":
        cat = "walkingRoute"
        n_path += 1
    else:
        continue
    routes.append({
        "id": "rota-%s" % e["id"],
        "name": "Bisiklet Yolu" if cat == "bikeRoute" else "Yürüyüş Yolu",
        "category": cat, "points": to_points(g),
    })

n_rel = 0
for e in C:
    if e["type"] != "relation":
        continue
    t = e.get("tags", {})
    if t.get("route") != "bicycle":
        continue
    n_rel += 1
    for m in e.get("members", []):
        if m.get("type") == "way" and m.get("geometry"):
            g = [(round(p["lat"], 5), round(p["lon"], 5)) for p in m["geometry"]]
            if len(g) < 3:
                continue
            routes.append({
                "id": "rota-%s-%s" % (m["ref"], e["id"]),
                "name": t.get("name") or "Bisiklet Rotası",
                "category": "bikeRoute", "points": to_points(g),
            })

out = {
    "center": {"lat": 40.7408, "lng": 30.3333},
    "pois": pois,
    "routes": routes,
}
dest = r"C:\Users\TURAN\OneDrive\Masaüstü\class\newgenc\assets\data\campus_poi.json"
json.dump(out, open(dest, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("POI:", len(pois), dict(collections.Counter(p["category"] for p in pois)))
print("Rota:", len(routes), "(cycleway %d, path %d, rel %d)" % (n_cycle, n_path, n_rel))
print("JSON boyutu:", round(os.path.getsize(dest) / 1024, 1), "KB")
