# -*- coding: utf-8 -*-
"""Kampüs Cepte verisini (assets/data/campus_poi.json) OpenStreetMap'ten üretir.

Kullanım:  python tool/build_campus_poi.py [onbellek_klasoru]

Serdivan ilçe sınırı içindeki noktaları ve yaya/bisiklet yollarını Overpass
API'den çeker. Mevcut dosyadaki kayıtlar korunur (id ile birleştirilir), bu
yüzden ilçe dışındaki eski kayıtlar ve elle eklenenler silinmez.

Veri © OpenStreetMap katkıcıları (ODbL). OSM'de olmayan yer bu dosyada da
olmaz; eksikler admin panelinden (Kampüs Cepte Noktaları) eklenir.
"""
import collections
import io
import json
import math
import os
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "assets", "data", "campus_poi.json")
CACHE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "osm_cache")
ENDPOINT = "https://overpass-api.de/api/interpreter"
AREA = "area(3606989045)->.a;"  # Serdivan (relation 6989045)
CENTER = {"lat": 40.7408, "lng": 30.3333}

QUERIES = {
    "p1": '[out:json][timeout:90];%snwr(area.a)["amenity"~"^(university|college|library|cafe|restaurant|fast_food|food_court|pharmacy|hospital|clinic|doctors|dentist|bank|atm|place_of_worship|bus_station|post_office|police|student_accommodation|cinema|theatre|community_centre)$"];out center tags;',
    "p2": '[out:json][timeout:90];%s(nwr(area.a)["highway"="bus_stop"];nwr(area.a)["public_transport"~"^(platform|station)$"];nwr(area.a)["railway"~"^(station|halt|tram_stop)$"];nwr(area.a)["building"~"^(dormitory|university|college)$"];);out center tags;',
    "p3": '[out:json][timeout:90];%s(nwr(area.a)["leisure"~"^(park|sports_centre|pitch|fitness_centre|stadium|swimming_pool|garden)$"];nwr(area.a)["shop"~"^(supermarket|convenience|mall|copyshop|stationery|books|bakery)$"];nwr(area.a)["tourism"~"^(hostel|attraction|viewpoint|museum)$"];);out center tags;',
    "p4": '[out:json][timeout:90];%snwr(area.a)["name"~"yurd|yurt|KYK|öğrenci evi|apart",i];out center tags;',
    "routes": '[out:json][timeout:150];%s(way(area.a)["highway"~"^(footway|path|pedestrian|cycleway|steps|track)$"];);out geom tags;',
}


def fetch(key):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, key + ".json")
    if os.path.exists(path):
        try:
            return json.load(io.open(path, encoding="utf-8"))["elements"]
        except ValueError:
            pass
    body = urllib.parse.urlencode({"data": QUERIES[key] % AREA}).encode()
    for attempt in range(4):
        req = urllib.request.Request(ENDPOINT, data=body, headers={
            "User-Agent": "NevGenc-campus-map-curation/1.0",
            "Accept": "application/json",
        })
        try:
            raw = urllib.request.urlopen(req, timeout=180).read()
            data = json.loads(raw.decode("utf-8"))
            io.open(path, "wb").write(raw)
            time.sleep(5)
            return data["elements"]
        except Exception as exc:  # 429/504: sunucu meşgul, bekleyip yeniden dene
            print("  %s deneme %d başarısız: %s" % (key, attempt + 1, exc))
            time.sleep(25)
    raise SystemExit("Overpass'ten %s alınamadı." % key)


def coord(e):
    c = e.get("center") or {}
    return e.get("lat", c.get("lat")), e.get("lon", c.get("lon"))


def meters(a, b):
    r = 6371000.0
    dlat = math.radians(b[0] - a[0])
    dlng = math.radians(b[1] - a[1])
    x = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(a[0])) * math.cos(math.radians(b[0])) * math.sin(dlng / 2) ** 2)
    return 2 * r * math.asin(math.sqrt(x))


def tr_lower(s):
    return s.replace("I", "ı").replace("İ", "i").lower()


# (kategori, isimsizse varsayılan ad, açıklama, isim zorunlu mu)
def classify(t):
    a, sh, le, b = t.get("amenity"), t.get("shop"), t.get("leisure"), t.get("building")
    name = tr_lower(t.get("name", ""))
    if b == "dormitory" or a == "student_accommodation" or "yurd" in name or "yurt" in name \
            or "kyk" in name or "öğrenci evi" in name:
        return "dormitory", "Öğrenci Yurdu", "Öğrenci yurdu", False
    if t.get("highway") == "bus_stop" or t.get("public_transport") == "platform":
        return "busStop", "Otobüs Durağı", "Otobüs durağı", False
    if a == "bus_station" or t.get("public_transport") == "station" \
            or t.get("railway") in ("station", "halt", "tram_stop"):
        return "busStop", "İstasyon", "Toplu taşıma istasyonu", False
    if a == "library":
        return "study", "Kütüphane", "Sessiz çalışma / kütüphane alanı", False
    if a in ("university", "college") or b in ("university", "college"):
        return "faculty", "", "Üniversite binası", True
    if a in ("restaurant", "fast_food", "food_court"):
        return "food", "", "Yemek", True
    if a == "cafe":
        return "food", "", "Kafe", True
    if a == "pharmacy":
        return "health", "Eczane", "Eczane", False
    if a in ("hospital", "clinic", "doctors", "dentist"):
        return "health", "Sağlık Kuruluşu", "Sağlık kuruluşu", False
    if sh in ("supermarket", "convenience", "mall", "bakery"):
        return "market", "", {"mall": "Alışveriş merkezi", "bakery": "Fırın"}.get(sh, "Market"), True
    if sh in ("copyshop", "stationery", "books"):
        return "market", "", "Kırtasiye / fotokopi", True
    if le in ("sports_centre", "fitness_centre", "stadium"):
        return "sport", "Spor Tesisi", "Spor tesisi", False
    if le in ("pitch", "swimming_pool"):
        return "sport", "", "Spor alanı", True
    if le in ("park", "garden"):
        return "park", "Park", "Park / yeşil alan", le == "garden"
    if a == "place_of_worship":
        return "worship", "Cami / Mescit", "İbadet yeri", False
    if a in ("bank", "atm"):
        label = "ATM" if a == "atm" else "Banka"
        return "finance", (t.get("operator") or t.get("brand") or label), label, False
    if a in ("cinema", "theatre", "community_centre") or t.get("tourism") in ("museum", "attraction"):
        return "culture", "", "Kültür / sanat", True
    return None


PREFIX = {"dormitory": "yurt", "busStop": "durak", "study": "calisma"}


def build_pois():
    out, seen = [], set()
    elements = []
    for key in ("p4", "p1", "p2", "p3"):  # p4 önce: isimden yurt eşleşmesi öncelikli
        elements += fetch(key)
    for e in elements:
        uid = (e["type"], e["id"])
        if uid in seen:
            continue
        t = e.get("tags", {})
        cls = classify(t)
        lat, lon = coord(e)
        if cls is None or lat is None:
            continue
        cat, default_name, desc, need_name = cls
        name = (t.get("name") or "").strip()
        if not name and need_name:
            continue
        seen.add(uid)
        street = " ".join(x for x in (t.get("addr:street"), t.get("addr:housenumber")) if x)
        out.append({
            "id": "%s-%s" % (PREFIX.get(cat, cat), e["id"]),
            "name": name or default_name,
            "category": cat,
            "lat": round(lat, 5), "lng": round(lon, 5),
            "description": desc,
            "address": street or t.get("addr:neighbourhood") or t.get("addr:suburb") or "Serdivan",
        })
    return out


def dedupe(pois):
    """Aynı kategoride birbirine çok yakın kayıtları (düğüm + bina, durak + peron) teke indirir."""
    kept = []
    for p in sorted(pois, key=lambda x: (x["name"] in ("Otobüs Durağı", "Park", "Eczane"), x["id"])):
        dup = False
        for k in kept:
            if k["category"] != p["category"]:
                continue
            d = meters((k["lat"], k["lng"]), (p["lat"], p["lng"]))
            same_name = tr_lower(k["name"]) == tr_lower(p["name"])
            if d < 15 or (same_name and d < 60 and p["category"] != "busStop"):
                dup = True
                break
        if not dup:
            kept.append(p)
    return kept


def simplify(pts, max_pts=60):
    if len(pts) <= max_pts:
        return pts
    step = (len(pts) - 1) / float(max_pts - 1)
    return [pts[int(round(i * step))] for i in range(max_pts)]


def build_routes():
    out = []
    for e in fetch("routes"):
        if e["type"] != "way":
            continue
        t = e.get("tags", {})
        hw = t.get("highway")
        if t.get("access") in ("private", "no") or t.get("foot") == "no":
            continue
        g = [(round(p["lat"], 5), round(p["lon"], 5)) for p in e.get("geometry", [])]
        if len(g) < 2:
            continue
        length = sum(meters(g[i], g[i + 1]) for i in range(len(g) - 1))
        if hw == "cycleway":
            cat, name, min_len = "bikeRoute", "Bisiklet Yolu", 40
        else:
            # Kaldırım parçalarını ve çok kısa bağlantıları ele: gerçek yürüyüş yolları kalsın.
            if t.get("footway") in ("sidewalk", "crossing") or hw == "steps":
                continue
            cat, name, min_len = "walkingRoute", "Yürüyüş Yolu", 120
        if length < min_len:
            continue
        out.append({
            "id": "rota-%s" % e["id"],
            "name": (t.get("name") or name).strip(),
            "category": cat,
            "description": "Yaklaşık %d m" % (round(length / 10.0) * 10),
            "points": [{"lat": p[0], "lng": p[1]} for p in simplify(g)],
        })
    return out


def main():
    old = {"pois": [], "routes": []}
    if os.path.exists(DEST):
        old = json.load(io.open(DEST, encoding="utf-8"))

    pois = build_pois()
    new_ids = {p["id"] for p in pois}
    pois += [p for p in old.get("pois", []) if p["id"] not in new_ids]
    pois = dedupe(pois)
    pois.sort(key=lambda p: (p["category"], tr_lower(p["name"])))

    routes = build_routes()
    new_route_ids = {r["id"] for r in routes}
    routes += [r for r in old.get("routes", []) if r["id"] not in new_route_ids]

    out = {"center": CENTER, "pois": pois, "routes": routes}
    with io.open(DEST, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print("Nokta:", len(pois), dict(collections.Counter(p["category"] for p in pois)))
    print("Rota:", len(routes), dict(collections.Counter(r["category"] for r in routes)))
    print("Boyut: %.0f KB" % (os.path.getsize(DEST) / 1024.0))


if __name__ == "__main__":
    main()
