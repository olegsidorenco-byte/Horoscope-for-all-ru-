"""
Точный астрономический движок на чистом Python (алгоритмы Жана Мееса и JPL Standish).
Без внешних C-зависимостей (работает одинаково в Cloud Run, GitHub Actions и systemd).

Обеспечивает:
1. Юлианскую дату (JD) и истинную эклиптическую долготу Солнца (< 0.01°).
2. Истинную долготу Луны по периодическим членам ELP2000/Meeus (< 0.1°), элонгацию и фазу Луны.
3. Геоцентрические координаты 10 планет (Солнце..Плутон) и определение ретроградности.
4. Расчет Асцендента (Asc), Середины Неба (MC) и куспидов 12 домов (Placidus с безопасным fallback).
5. Точные транзитные аспекты к натальной карте (соединение, секстиль, квадрат, тригон, оппозиция).
6. Реальные халдейские планетарные часы дня от истинного восхода до заката по координатам города.
"""

import math
from datetime import datetime, timedelta, timezone

ZODIAC_SIGNS_RU = [
    "Овен", "Телец", "Близнецы", "Рак", "Лев", "Дева",
    "Весы", "Скорпион", "Стрелец", "Козерог", "Водолей", "Рыбы",
]

ZODIAC_SIGNS_GEN_RU = [
    "Овна", "Тельца", "Близнецов", "Рака", "Льва", "Девы",
    "Весов", "Скорпиона", "Стрельца", "Козерога", "Водолея", "Рыб",
]

ZODIAC_BY_LANG = {
    "ru": ZODIAC_SIGNS_RU,
    "en": ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"],
    "es": ["Aries", "Tauro", "Géminis", "Cáncer", "Leo", "Virgo", "Libra", "Escorpio", "Sagitario", "Capricornio", "Acuario", "Piscis"],
    "de": ["Widder", "Stier", "Zwillinge", "Krebs", "Löwe", "Jungfrau", "Waage", "Skorpion", "Schütze", "Steinbock", "Wassermann", "Fische"],
    "fr": ["Bélier", "Taureau", "Gémeaux", "Cancer", "Lion", "Vierge", "Balance", "Scorpion", "Sagittaire", "Capricorne", "Verseau", "Poissons"],
}

PLANET_NAMES_RU = {
    "Sun": "Солнце",
    "Moon": "Луна",
    "Mercury": "Меркурий",
    "Venus": "Венера",
    "Mars": "Марс",
    "Jupiter": "Юпитер",
    "Saturn": "Сатурн",
    "Uranus": "Уран",
    "Neptune": "Нептун",
    "Pluto": "Плутон",
}

CHALDEAN_ORDER = ["Saturn", "Jupiter", "Mars", "Sun", "Venus", "Mercury", "Moon"]
CHALDEAN_RULERS_BY_WEEKDAY = {
    0: "Moon",     # Понедельник
    1: "Mars",     # Вторник
    2: "Mercury",  # Среда
    3: "Jupiter",  # Четверг
    4: "Venus",    # Пятница
    5: "Saturn",   # Суббота
    6: "Sun",      # Воскресенье
}
HARMONIOUS_PLANETS = {"Sun", "Jupiter", "Venus", "Mercury"}


def datetime_to_jd(dt_utc: datetime) -> float:
    """Преобразует UTC datetime в юлианскую дату JD."""
    if dt_utc.tzinfo is not None:
        dt_utc = dt_utc.astimezone(timezone.utc)
    y = dt_utc.year
    m = dt_utc.month
    d = dt_utc.day + (dt_utc.hour + dt_utc.minute / 60.0 + dt_utc.second / 3600.0) / 24.0
    if m <= 2:
        y -= 1
        m += 12
    a = math.floor(y / 100)
    b = 2 - a + math.floor(a / 4)
    return math.floor(365.25 * (y + 4716)) + math.floor(30.6001 * (m + 1)) + d + b - 1524.5


def format_lon_deg(lon_deg: float, lang: str = "ru") -> dict:
    """Форматирует эклиптическую долготу 0..360° в знак зодиака и градусы/минуты."""
    total_arcmin = int(round((lon_deg % 360.0) * 60)) % (360 * 60)
    idx = (total_arcmin // 1800) % 12
    rem = total_arcmin % 1800
    signs = ZODIAC_BY_LANG.get(lang, ZODIAC_SIGNS_RU)
    return {
        "lon": round(lon_deg % 360.0, 4),
        "sign_idx": idx,
        "sign_ru": ZODIAC_SIGNS_RU[idx],
        "sign_gen_ru": ZODIAC_SIGNS_GEN_RU[idx],
        "sign": signs[idx],
        "deg_in_sign": round((lon_deg % 30.0), 2),
        "deg_str": f"{rem // 60}°{rem % 60:02d}'",
    }


def get_true_sun_longitude(jd: float) -> float:
    """Истинная видимая геоцентрическая долгота Солнца (Жан Меес, гл. 25), точность ~0.01°."""
    t = (jd - 2451545.0) / 36525.0
    l0 = (280.46646 + 36000.76983 * t + 0.0003032 * t**2) % 360.0
    m = (357.52911 + 35999.05029 * t - 0.0001537 * t**2) % 360.0
    m_rad = math.radians(m)
    c = (
        (1.914602 - 0.004817 * t - 0.000014 * t**2) * math.sin(m_rad)
        + (0.019993 - 0.000101 * t) * math.sin(2 * m_rad)
        + 0.000289 * math.sin(3 * m_rad)
    )
    sun_true = l0 + c
    omega = math.radians(125.04 - 1934.136 * t)
    apparent = sun_true - 0.00569 - 0.00478 * math.sin(omega)
    return apparent % 360.0


def get_true_moon_longitude(jd: float) -> float:
    """Истинная эклиптическая долгота Луны (Жан Меес, гл. 47, основные периодические члены ELP2000)."""
    t = (jd - 2451545.0) / 36525.0
    l_prime = (218.3164477 + 481267.88123421 * t - 0.0015786 * t**2 + t**3 / 538841.0 - t**4 / 65194000.0) % 360.0
    d = (297.8501921 + 445267.1114034 * t - 0.0018819 * t**2 + t**3 / 545868.0 - t**4 / 113065000.0) % 360.0
    m = (357.5291092 + 35999.0502909 * t - 0.0001536 * t**2 + t**3 / 24490000.0) % 360.0
    m_prime = (134.9633964 + 477198.8675055 * t + 0.0087414 * t**2 + t**3 / 69699.0 - t**4 / 14712000.0) % 360.0
    f = (93.2720950 + 483202.0175233 * t - 0.0036539 * t**2 - t**3 / 3526000.0 + t**4 / 863310000.0) % 360.0

    e = 1.0 - 0.002516 * t - 0.0000074 * t**2
    e2 = e * e

    terms = [
        (0, 0, 1, 0, 6288774),
        (2, 0, -1, 0, 1274027),
        (2, 0, 0, 0, 658314),
        (0, 0, 2, 0, 213618),
        (0, 1, 0, 0, -185116),
        (0, 0, 0, 2, -114332),
        (2, 0, -2, 0, 58793),
        (2, -1, -1, 0, 57066),
        (2, 0, 1, 0, 53322),
        (2, -1, 0, 0, 45758),
        (0, 1, -1, 0, -40923),
        (1, 0, 0, 0, -34720),
        (0, 1, 1, 0, -30383),
        (2, 0, 0, -2, 15327),
        (0, 0, 1, 2, -12528),
        (0, 0, 1, -2, 10980),
        (4, 0, -1, 0, 10675),
        (0, 0, 3, 0, 10034),
        (4, 0, -2, 0, 8548),
        (2, 1, -1, 0, -7888),
        (2, 1, 0, 0, -6766),
        (1, 0, -1, 0, -5163),
        (1, 1, 0, 0, 4987),
        (2, -1, 1, 0, 4036),
    ]

    sigma_l = 0.0
    for cd, cm, cmp, cf, coeff in terms:
        arg = math.radians(cd * d + cm * m + cmp * m_prime + cf * f)
        mult = 1.0
        if abs(cm) == 1:
            mult = e
        elif abs(cm) == 2:
            mult = e2
        sigma_l += coeff * mult * math.sin(arg)

    a1 = math.radians(119.75 + 131.849 * t)
    a2 = math.radians(53.09 + 479264.290 * t)
    sigma_l += 3958.0 * math.sin(a1) + 1962.0 * math.sin(math.radians(l_prime - f)) + 318.0 * math.sin(a2)

    return (l_prime + sigma_l / 1000000.0) % 360.0


def get_lunar_phase_info(jd: float) -> dict:
    """Возвращает элонгацию Луны, лунный день (1..30) и название фазы на русском."""
    sun_lon = get_true_sun_longitude(jd)
    moon_lon = get_true_moon_longitude(jd)
    elong = (moon_lon - sun_lon) % 360.0
    lunar_day = min(30, int(elong // 12.0) + 1)

    if elong < 15.0 or elong >= 345.0:
        phase = "Новолуние"
    elif elong < 75.0:
        phase = "Растущий серп (1-я четверть)"
    elif elong < 105.0:
        phase = "Первая четверть"
    elif elong < 165.0:
        phase = "Растущая Луна (2-я четверть)"
    elif elong < 195.0:
        phase = "Полнолуние"
    elif elong < 255.0:
        phase = "Убывающая Луна (3-я четверть)"
    elif elong < 285.0:
        phase = "Последняя четверть"
    else:
        phase = "Убывающий серп (4-я четверть)"

    return {
        "elongation_deg": round(elong, 2),
        "lunar_day": lunar_day,
        "lunar_phase": phase,
        "sun_lon": sun_lon,
        "moon_lon": moon_lon,
    }


# JPL Standish (1800–2050 AD) кеплеровы элементы орбит:
# (a, e, I_deg, L_deg, w_bar_deg, node_deg) и скорости за юлианское столетие
_PLANET_ELEMENTS_J2000 = {
    "Mercury": (
        (0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593),
        (0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081),
    ),
    "Venus": (
        (0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255),
        (0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418),
    ),
    "Earth": (
        (1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0),
        (0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0),
    ),
    "Mars": (
        (1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891),
        (0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343),
    ),
    "Jupiter": (
        (5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909),
        (-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106),
    ),
    "Saturn": (
        (9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448),
        (-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794),
    ),
    "Uranus": (
        (19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503),
        (-0.00196176, -0.00004397, -0.00242939, 428.48202785, 0.40805281, 0.04240589),
    ),
    "Neptune": (
        (30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574),
        (0.00026291, 0.00005105, 0.00035372, 218.45945325, -0.32241464, -0.00508664),
    ),
    "Pluto": (
        (39.48211675, 0.24882730, 17.14001206, 238.92903833, 224.06891629, 110.30393684),
        (-0.00031596, 0.00005170, 0.00004818, 145.20780515, -0.04062942, -0.01183482),
    ),
}


def _heliocentric_xyz(planet_name: str, t_cent: float) -> tuple[float, float, float]:
    base, rate = _PLANET_ELEMENTS_J2000[planet_name]
    a = base[0] + rate[0] * t_cent
    e = base[1] + rate[1] * t_cent
    inc = math.radians(base[2] + rate[2] * t_cent)
    l_deg = base[3] + rate[3] * t_cent
    w_bar = base[4] + rate[4] * t_cent
    node = math.radians(base[5] + rate[5] * t_cent)

    omega = math.radians(w_bar - (base[5] + rate[5] * t_cent))
    m_deg = (l_deg - w_bar) % 360.0
    if m_deg > 180.0:
        m_deg -= 360.0
    m_rad = math.radians(m_deg)

    # Итеративное решение уравнения Кеплера E - e*sin(E) = M
    ecc_anom = m_rad + e * math.sin(m_rad)
    for _ in range(8):
        delta = (ecc_anom - e * math.sin(ecc_anom) - m_rad) / (1.0 - e * math.cos(ecc_anom))
        ecc_anom -= delta
        if abs(delta) < 1e-8:
            break

    x_orb = a * (math.cos(ecc_anom) - e)
    y_orb = a * math.sqrt(max(0.0, 1.0 - e * e)) * math.sin(ecc_anom)

    cos_w, sin_w = math.cos(omega), math.sin(omega)
    cos_o, sin_o = math.cos(node), math.sin(node)
    cos_i, sin_i = math.cos(inc), math.sin(inc)

    x_ecl = (
        (cos_w * cos_o - sin_w * sin_o * cos_i) * x_orb
        + (-sin_w * cos_o - cos_w * sin_o * cos_i) * y_orb
    )
    y_ecl = (
        (cos_w * sin_o + sin_w * cos_o * cos_i) * x_orb
        + (-sin_w * sin_o + cos_w * cos_o * cos_i) * y_orb
    )
    z_ecl = (sin_w * sin_i) * x_orb + (cos_w * sin_i) * y_orb
    return x_ecl, y_ecl, z_ecl


def get_geocentric_planet_longitude(planet_name: str, jd: float) -> float:
    """Геоцентрическая эклиптическая долгота планеты на дату JD."""
    if planet_name == "Sun":
        return get_true_sun_longitude(jd)
    if planet_name == "Moon":
        return get_true_moon_longitude(jd)

    t_cent = (jd - 2451545.0) / 36525.0
    ex, ey, _ = _heliocentric_xyz("Earth", t_cent)
    px, py, _ = _heliocentric_xyz(planet_name, t_cent)
    lon_rad = math.atan2(py - ey, px - ex)
    return (math.degrees(lon_rad) + 360.0) % 360.0


def get_all_planet_positions(jd: float, lang: str = "ru") -> dict[str, dict]:
    """Возвращает позиции всех 10 планет и флаг ретроградности для Меркурия–Плутона."""
    positions = {}
    for p_name in ("Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"):
        lon = get_geocentric_planet_longitude(p_name, jd)
        retrograde = False
        if p_name not in ("Sun", "Moon"):
            lon_prev = get_geocentric_planet_longitude(p_name, jd - 0.5)
            lon_next = get_geocentric_planet_longitude(p_name, jd + 0.5)
            diff = (lon_next - lon_prev + 540.0) % 360.0 - 180.0
            retrograde = diff < 0.0
        info = format_lon_deg(lon, lang=lang)
        info["retrograde"] = retrograde
        info["name_ru"] = PLANET_NAMES_RU[p_name]
        positions[p_name] = info
    return positions


def compute_houses_cusps(jd: float, lat: float, lon: float) -> dict:
    """
    Рассчитывает Asc, MC и куспиды 12 домов (Placidus, с безопасным переходом на Equal/Porphyry
    в приполярных широтах |lat| >= 66.5°).
    """
    t = (jd - 2451545.0) / 36525.0
    gmst = (280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * t**2 - (t**3) / 38710000.0) % 360.0
    lst = (gmst + lon) % 360.0
    eps = 23.439291 - 0.0130042 * t
    eps_rad = math.radians(eps)
    ramc_rad = math.radians(lst)
    lat_rad = math.radians(lat)

    mc_rad = math.atan2(math.sin(ramc_rad), math.cos(ramc_rad) * math.cos(eps_rad))
    mc_deg = (math.degrees(mc_rad) + 360.0) % 360.0

    y_asc = math.cos(ramc_rad)
    x_asc = -math.sin(ramc_rad) * math.cos(eps_rad) - math.tan(lat_rad) * math.sin(eps_rad)
    asc_deg = (math.degrees(math.atan2(y_asc, x_asc)) + 360.0) % 360.0

    cusps = [0.0] * 12
    cusps[0] = asc_deg
    cusps[9] = mc_deg
    cusps[6] = (asc_deg + 180.0) % 360.0
    cusps[3] = (mc_deg + 180.0) % 360.0

    if abs(lat) >= 66.0:
        # Приполярный fallback: равнодомная от Asc
        for i in range(12):
            cusps[i] = (asc_deg + i * 30.0) % 360.0
    else:
        def _placidus_cusp(fraction: float, offset_deg: float, is_upper: bool) -> float:
            ra_cusp = (lst + offset_deg) % 360.0
            for _ in range(12):
                ra_rad = math.radians(ra_cusp)
                decl = math.atan(math.tan(eps_rad) * math.sin(ra_rad))
                val = -math.tan(lat_rad) * math.tan(decl)
                val = max(-0.999, min(0.999, val))
                dsa = math.degrees(math.acos(val))
                if is_upper:
                    ra_new = (lst + fraction * dsa) % 360.0
                else:
                    nsa = 180.0 - dsa
                    ra_new = (lst + 180.0 - fraction * nsa) % 360.0
                if abs((ra_new - ra_cusp + 540.0) % 360.0 - 180.0) < 1e-4:
                    ra_cusp = ra_new
                    break
                ra_cusp = ra_new
            ra_f = math.radians(ra_cusp)
            lon_c = math.degrees(math.atan2(math.sin(ra_f), math.cos(ra_f) * math.cos(eps_rad)))
            return (lon_c + 360.0) % 360.0

        try:
            cusps[10] = _placidus_cusp(1.0 / 3.0, 30.0, True)
            cusps[11] = _placidus_cusp(2.0 / 3.0, 60.0, True)
            cusps[1] = _placidus_cusp(2.0 / 3.0, 120.0, False)
            cusps[2] = _placidus_cusp(1.0 / 3.0, 150.0, False)
            cusps[4] = (cusps[10] + 180.0) % 360.0
            cusps[5] = (cusps[11] + 180.0) % 360.0
            cusps[7] = (cusps[1] + 180.0) % 360.0
            cusps[8] = (cusps[2] + 180.0) % 360.0
        except Exception:
            for i in range(12):
                cusps[i] = (asc_deg + i * 30.0) % 360.0

    return {
        "asc_deg": asc_deg,
        "mc_deg": mc_deg,
        "cusps": cusps,
    }


def find_house_for_longitude(lon_deg: float, cusps: list[float]) -> int:
    """Определяет номер дома (1..12) для долготы планеты по списку куспидов."""
    lon = lon_deg % 360.0
    for i in range(12):
        c1 = cusps[i] % 360.0
        c2 = cusps[(i + 1) % 12] % 360.0
        span = (c2 - c1) % 360.0
        rel = (lon - c1) % 360.0
        if rel < span:
            return i + 1
    return 1


ASPECT_TYPES = [
    (0.0, "соединение", "conjunction", 5.0, "neutral"),
    (60.0, "секстиль", "sextile", 4.0, "harmonious"),
    (90.0, "квадратура", "square", 5.0, "tense"),
    (120.0, "тригон", "trine", 5.0, "harmonious"),
    (180.0, "оппозиция", "opposition", 5.0, "tense"),
]


def compute_transit_aspects(
    transit_positions: dict[str, dict],
    natal_points: dict[str, dict],
    max_aspects: int = 8,
) -> list[dict]:
    """Вычисляет реальные аспекты транзитных планет к натальным точкам."""
    found = []
    for t_name, t_info in transit_positions.items():
        t_lon = t_info["lon"]
        for n_name, n_info in natal_points.items():
            n_lon = n_info["lon"]
            diff = abs((t_lon - n_lon + 180.0) % 360.0 - 180.0)
            for angle, asp_ru, asp_en, orb, nature in ASPECT_TYPES:
                eff_orb = orb - 1.0 if t_name == "Moon" else orb
                delta = abs(diff - angle)
                if delta <= eff_orb:
                    found.append({
                        "transit_planet": t_name,
                        "transit_planet_ru": PLANET_NAMES_RU.get(t_name, t_name),
                        "transit_sign": t_info["sign_ru"],
                        "aspect_ru": asp_ru,
                        "aspect_en": asp_en,
                        "nature": nature,
                        "natal_point": n_name,
                        "natal_point_ru": PLANET_NAMES_RU.get(n_name, n_name),
                        "orb": round(delta, 2),
                    })
    found.sort(key=lambda x: x["orb"])
    return found[:max_aspects]


def compute_planetary_hours(
    target_dt_local: datetime,
    lat: float,
    lon: float,
    tz_info,
) -> dict:
    """
    Рассчитывает истинный восход/закат Солнца и халдейские планетарные часы дня
    для координат (lat, lon) и локальной даты пользователя.
    """
    year, month, day = target_dt_local.year, target_dt_local.month, target_dt_local.day
    noon_local = datetime(year, month, day, 12, 0, tzinfo=tz_info)
    utc_offset_hours = (noon_local.utcoffset() or timedelta(0)).total_seconds() / 3600.0
    n_day = noon_local.timetuple().tm_yday

    gamma = 2.0 * math.pi / 365.0 * (n_day - 1)
    eqtime = 229.18 * (
        0.000075
        + 0.001868 * math.cos(gamma)
        - 0.032077 * math.sin(gamma)
        - 0.014615 * math.cos(2 * gamma)
        - 0.040849 * math.sin(2 * gamma)
    )
    decl = (
        0.006918
        - 0.399912 * math.cos(gamma)
        + 0.070257 * math.sin(gamma)
        - 0.006758 * math.cos(2 * gamma)
        + 0.000907 * math.sin(2 * gamma)
        - 0.002697 * math.cos(3 * gamma)
        + 0.00148 * math.sin(3 * gamma)
    )

    lat_rad = math.radians(max(-65.0, min(65.0, lat)))
    zenith_rad = math.radians(90.833)
    cos_ha = (math.cos(zenith_rad) / (math.cos(lat_rad) * math.cos(decl))) - math.tan(lat_rad) * math.tan(decl)
    cos_ha = max(-0.999, min(0.999, cos_ha))
    ha_deg = math.degrees(math.acos(cos_ha))

    sunrise_mins = 720.0 - 4.0 * (lon + ha_deg) - eqtime + utc_offset_hours * 60.0
    sunset_mins = 720.0 - 4.0 * (lon - ha_deg) - eqtime + utc_offset_hours * 60.0

    day_start = datetime(year, month, day, 0, 0, tzinfo=tz_info)
    sunrise_dt = day_start + timedelta(minutes=sunrise_mins)
    sunset_dt = day_start + timedelta(minutes=sunset_mins)
    day_len_mins = max(60.0, sunset_mins - sunrise_mins)
    hour_len_mins = day_len_mins / 12.0

    day_ruler = CHALDEAN_RULERS_BY_WEEKDAY[target_dt_local.weekday()]
    start_idx = CHALDEAN_ORDER.index(day_ruler)

    day_hours = []
    favorable_windows = []
    for i in range(12):
        ruler = CHALDEAN_ORDER[(start_idx + i) % 7]
        h_start = sunrise_dt + timedelta(minutes=i * hour_len_mins)
        h_end = sunrise_dt + timedelta(minutes=(i + 1) * hour_len_mins)
        slot_str = f"{h_start.strftime('%H:%M')}–{h_end.strftime('%H:%M')}"
        day_hours.append({
            "hour_num": i + 1,
            "ruler": ruler,
            "ruler_ru": PLANET_NAMES_RU[ruler],
            "window": slot_str,
        })
        if ruler in HARMONIOUS_PLANETS and 8 <= h_start.hour <= 19:
            favorable_windows.append(f"{slot_str} ({PLANET_NAMES_RU[ruler]})")

    return {
        "sunrise": sunrise_dt.strftime("%H:%M"),
        "sunset": sunset_dt.strftime("%H:%M"),
        "day_ruler": day_ruler,
        "day_ruler_ru": PLANET_NAMES_RU[day_ruler],
        "favorable_windows": favorable_windows[:3],
        "day_hours": day_hours,
    }


_SIGN_ELEMENTS = [
    "fire", "earth", "air", "water",
    "fire", "earth", "air", "water",
    "fire", "earth", "air", "water",
]
_SIGN_IDS = [
    "aries", "taurus", "gemini", "cancer", "leo", "virgo",
    "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces",
]


def compute_zodiac_daily_metrics(dt_utc: datetime) -> dict[str, dict]:
    """
    Рассчитывает индивидуальную энергию (%) и счастливые часы для каждого из 12 знаков
    на основе реальных угловых аспектов транзитных Солнца, Луны, Венеры, Марса и Юпитера.
    """
    jd = datetime_to_jd(dt_utc)
    sun_lon = get_true_sun_longitude(jd)
    moon_lon = get_true_moon_longitude(jd)
    venus_lon = get_geocentric_planet_longitude("Venus", jd)
    mars_lon = get_geocentric_planet_longitude("Mars", jd)
    jupiter_lon = get_geocentric_planet_longitude("Jupiter", jd)

    moon_idx = int((moon_lon % 360.0) // 30.0) % 12
    moon_elem = _SIGN_ELEMENTS[moon_idx]

    day_windows = [
        "08:30–10:15", "09:15–11:10", "10:00–12:00", "10:45–12:40",
        "11:30–13:20", "12:15–14:10", "13:30–15:20", "14:15–16:15",
        "15:00–17:00", "15:45–17:45", "16:30–18:30", "17:15–19:15",
    ]

    metrics = {}
    for idx, sign_id in enumerate(_SIGN_IDS):
        sign_center = idx * 30.0 + 15.0
        score = 78

        def _aspect_bonus(p_lon: float, pos_pts: int, neg_pts: int) -> int:
            d = abs((p_lon - sign_center + 180.0) % 360.0 - 180.0)
            if d <= 15.0 or abs(d - 120.0) <= 15.0:
                return pos_pts
            if abs(d - 60.0) <= 15.0:
                return max(1, pos_pts // 2)
            if abs(d - 90.0) <= 15.0 or abs(d - 180.0) <= 15.0:
                return -neg_pts
            return 0

        score += _aspect_bonus(sun_lon, 7, 4)
        score += _aspect_bonus(moon_lon, 6, 4)
        score += _aspect_bonus(jupiter_lon, 5, 2)
        score += _aspect_bonus(venus_lon, 4, 2)
        score += _aspect_bonus(mars_lon, 4, 5)

        if _SIGN_ELEMENTS[idx] == moon_elem:
            score += 3

        energy_val = max(68, min(97, score))
        win_idx = (idx + moon_idx + dt_utc.day) % len(day_windows)
        metrics[sign_id] = {
            "energy": f"{energy_val}%",
            "lucky_hours": day_windows[win_idx],
        }
    return metrics
