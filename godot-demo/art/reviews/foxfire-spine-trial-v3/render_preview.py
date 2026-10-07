"""Independent QA rasterizer for authored JSON; never a Spine export/capture.

Only the bone transforms implemented by v1's ``pose`` are supported. This is
an inspection helper, not a replacement for a complete Spine runtime.
"""
from __future__ import annotations

import json
import math
import sys
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
V1 = ROOT.parent / "foxfire-spine-trial-v1"
V2 = ROOT.parent / "foxfire-spine-trial-v2"
sys.path.insert(0, str(V1))
from build_sample import multiply, pose, sample  # noqa: E402

CANVAS = (1600, 1420)
ORIGIN = (850, 1320)
BACKGROUND = "#ded8ca"


def load_data(path):
    """Read input and retain its directory solely for preview asset lookup."""
    path = Path(path).resolve()
    data = json.loads(path.read_text())
    data["_preview_source_dir"] = str(path.parent)
    return data


@lru_cache(maxsize=64)
def _texture(path):
    with Image.open(path) as source:
        return source.convert("RGBA")


def _image(data, attachment, fallback_name):
    root = Path(data.get("_preview_source_dir", ROOT))
    folder = Path(data.get("skeleton", {}).get("images", "images"))
    path = root / folder / attachment.get("path", fallback_name)
    if not path.suffix:
        path = path.with_suffix(".png")
    return _texture(str(path.resolve()))


def _skin(data):
    skins = data["skins"]
    if isinstance(skins, dict):
        return skins.get("default", next(iter(skins.values())))
    skin = next((item for item in skins if item.get("name") == "default"), skins[0])
    return skin["attachments"]


def _rgba(value="ffffffff"):
    if isinstance(value, str):
        value = value.lstrip("#")
        if len(value) == 6:
            value += "ff"
        if len(value) != 8:
            raise ValueError(f"Expected RRGGBBAA color, received {value!r}")
        return np.array([int(value[i:i + 2], 16) / 255 for i in range(0, 8, 2)])
    return np.asarray(value, dtype=float)


def _color_keys(keys, t, default):
    if not keys or t < keys[0].get("time", 0):
        return default.copy()

    def value(key):
        if "color" in key:
            return _rgba(key["color"])
        return np.array([key.get(name, default[i]) for i, name in enumerate("rgba")])

    for left, right in zip(keys, keys[1:]):
        start, end = left.get("time", 0), right.get("time", 0)
        if start <= t < end:
            a, b = value(left), value(right)
            return a if left.get("curve") == "stepped" else a + (b - a) * ((t - start) / (end - start))
    return value(keys[-1])


def _slot_color(slot, tracks, t, attachment):
    color = _rgba(slot.get("color", "ffffffff"))
    color = _color_keys(tracks.get("rgba", tracks.get("color")), t, color)
    if "rgb" in tracks:
        color[:3] = _color_keys(tracks["rgb"], t, color)[:3]
    color[3] = sample(tracks.get("alpha"), t, "value", float(color[3]))
    return np.clip(color * _rgba(attachment.get("color", "ffffffff")), 0, 1)


def _tint(image, color):
    if np.allclose(color, 1):
        return image
    pixels = np.asarray(image, dtype=float)
    return Image.fromarray(np.rint(pixels * color).clip(0, 255).astype(np.uint8))


def _points_with_matrices(data, attachment, matrices):
    names = [bone["name"] for bone in data["bones"]]
    values = attachment["vertices"]
    count = len(attachment["uvs"]) // 2
    if len(values) == count * 2:
        # Optional plain mesh support. Find its owning slot from the skin.
        owner = next(slot for slot in data["slots"]
                     if any(candidate is attachment or candidate == attachment
                            for candidate in _skin(data).get(slot["name"], {}).values()))
        a, b, c, d, x, y = matrices[owner["bone"]]
        points = np.asarray(values, dtype=float).reshape(-1, 2)
        return points @ np.array([[a, b], [c, d]]) + [x, y]
    iterator = iter(values)
    result = []
    for _ in range(count):
        x = y = 0.0
        for _ in range(int(next(iterator))):
            index, lx, ly, weight = (next(iterator) for _ in range(4))
            a, b, c, d, tx, ty = matrices[names[int(index)]]
            x += (a * lx + c * ly + tx) * weight
            y += (b * lx + d * ly + ty) * weight
        result.append((x, y))
    if next(iterator, None) is not None:
        raise ValueError("Unexpected extra weighted mesh vertex data")
    return np.asarray(result)


def mesh_points(data, att, anim, t):
    """Return skinned mesh vertices in skeleton world coordinates (Y up)."""
    return _points_with_matrices(data, att, pose(data, anim, t))


def mesh_uv_point(data, att, anim, t, uv):
    """Skin an actual art landmark via its UV triangle's barycentric weights.

    For heel/toe/contact QA, choose UV coordinates on opaque material. Do not
    substitute the generally transparent rectangular mesh boundary.
    """
    uvs = np.asarray(att["uvs"]).reshape(-1, 2)
    points = mesh_points(data, att, anim, t)
    for indices in np.asarray(att["triangles"]).reshape(-1, 3):
        tri = uvs[indices]
        matrix = np.vstack((tri.T, np.ones(3)))
        if abs(np.linalg.det(matrix)) < 1e-12:
            continue
        weights = np.linalg.solve(matrix, [uv[0], uv[1], 1])
        if np.min(weights) >= -1e-8:
            return weights @ points[indices]
    raise ValueError(f"UV landmark is outside mesh triangles: {uv}")


def _mesh_layer(data, attachment, matrices, texture, size, scale):
    points = _points_with_matrices(data, attachment, matrices)
    points = points * [scale, -scale] + np.asarray(ORIGIN) * scale
    uvs = np.asarray(attachment["uvs"]).reshape(-1, 2) * texture.size
    layer = Image.new("RGBA", size)
    for indices in np.asarray(attachment["triangles"]).reshape(-1, 3):
        destination, source = points[indices], uvs[indices]
        low = np.floor(destination.min(axis=0)).astype(int)
        high = np.ceil(destination.max(axis=0)).astype(int) + 1
        low = np.maximum(low, 0)
        high = np.minimum(high, size)
        width, height = high - low
        if width <= 0 or height <= 0:
            continue
        matrix = np.column_stack([destination - low, np.ones(3)])
        if abs(np.linalg.det(matrix)) < 1e-8:
            continue
        inverse = np.linalg.solve(matrix, source)
        patch = texture.transform((int(width), int(height)), Image.Transform.AFFINE,
                                  tuple(inverse[:, 0]) + tuple(inverse[:, 1]),
                                  Image.Resampling.BICUBIC)
        mask = Image.new("L", patch.size)
        ImageDraw.Draw(mask).polygon([tuple(point) for point in destination - low], fill=255)
        # Copy once per triangle; alpha-compositing every triangle darkens shared edges.
        layer.paste(patch, tuple(low), mask)
    return layer


def _region_layer(attachment, matrix, texture, size, scale):
    width = attachment.get("width", texture.width)
    height = attachment.get("height", texture.height)
    rotation = math.radians(attachment.get("rotation", 0))
    cosine, sine = math.cos(rotation), math.sin(rotation)
    sx, sy = attachment.get("scaleX", 1), attachment.get("scaleY", 1)
    attachment_matrix = [cosine * sx, sine * sx, -sine * sy, cosine * sy,
                         attachment.get("x", 0), attachment.get("y", 0)]
    pixels = [width / texture.width, 0, 0, -height / texture.height, -width / 2, height / 2]
    screen = [scale, 0, 0, -scale, ORIGIN[0] * scale, ORIGIN[1] * scale]
    a, b, c, d, x, y = multiply(screen, multiply(matrix, multiply(attachment_matrix, pixels)))
    determinant = a * d - b * c
    if abs(determinant) < 1e-12:
        return Image.new("RGBA", size)
    inverse = (d / determinant, -c / determinant, (c * y - d * x) / determinant,
               -b / determinant, a / determinant, (b * x - a * y) / determinant)
    return texture.transform(size, Image.Transform.AFFINE, inverse, Image.Resampling.BICUBIC)


def render(data, anim, t, scale=.4):
    """Render regions and meshes in exact setup slot order into a transparent PIL image."""
    if scale <= 0:
        raise ValueError("scale must be positive")
    size = tuple(round(dimension * scale) for dimension in CANVAS)
    canvas = Image.new("RGBA", size)
    matrices = pose(data, anim, t)
    skin = _skin(data)
    animation = data.get("animations", {}).get(anim, {})
    if animation.get("drawOrder") or animation.get("draworder"):
        raise ValueError("Animated draw order is not implemented by this QA renderer")
    for slot in data["slots"]:
        tracks = animation.get("slots", {}).get(slot["name"], {})
        name = slot.get("attachment")
        for key in tracks.get("attachment", []):
            if key.get("time", 0) <= t:
                name = key.get("name")
        if name is None:
            continue
        attachment = skin[slot["name"]][name]
        kind = attachment.get("type", "region")
        color = _slot_color(slot, tracks, t, attachment)
        if color[3] <= 0:
            continue
        texture = _image(data, attachment, name)
        if kind == "mesh":
            layer = _mesh_layer(data, attachment, matrices, texture, size, scale)
        elif kind == "region":
            layer = _region_layer(attachment, matrices[slot["bone"]], texture, size, scale)
        else:
            raise ValueError(f"Unsupported attachment type {kind!r}")
        canvas.alpha_composite(_tint(layer, color))
    return canvas


def animation_duration(data, anim):
    def times(value):
        if isinstance(value, dict):
            if "time" in value:
                yield value["time"]
            for child in value.values():
                yield from times(child)
        elif isinstance(value, list):
            for child in value:
                yield from times(child)
    return max(times(data["animations"][anim]), default=0)


def _font(size=16):
    try:
        return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def _background(image, title):
    result = Image.new("RGB", image.size, BACKGROUND)
    result.paste(image, (0, 0), image)
    ImageDraw.Draw(result).text((10, 8), title, fill="#302a23", font=_font())
    return result


def _save_gif(frames, path, seconds):
    # GIF timestamps have 10 ms precision; distribute any rounded remainder.
    units = round(seconds * 100)
    durations = [10 * (round((i + 1) * units / len(frames)) - round(i * units / len(frames)))
                 for i in range(len(frames))]
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=durations,
                   loop=0, disposal=2)


def make_previews(data):
    durations = {name: animation_duration(data, name) for name in ("idle", "move", "basic_attack")}
    for anim, duration in durations.items():
        count = max(1, round(duration * 25))
        frames = [_background(render(data, anim, i * duration / count, .4),
                              f"V3 / {anim} / EXTERNAL QA - not Spine capture") for i in range(count)]
        _save_gif(frames, ROOT / f"external-{anim}.gif", duration)

    sheet = Image.new("RGB", (1600, 740), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    for i in range(8):
        t = durations["move"] * i / 8
        im = render(data, "move", t, .17)
        sheet.paste(im, (i * 200 - 30, 28), im)
        draw.text((i * 200 + 8, 10), f"move {t:.3f}s", fill="#302a23", font=_font())
        detail = render(data, "move", t, .6).crop((320, 515, 640, 830))
        detail.thumbnail((195, 265), Image.Resampling.LANCZOS)
        sheet.paste(detail, (i * 200, 350), detail)
    draw.text((20, 700), "EXTERNAL QA / eight gait poses and leg details / not Spine capture", fill="#302a23", font=_font())
    sheet.save(ROOT / "qa-walk-contact.png")

    sheet = Image.new("RGB", (1200, 600), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    samples = [("idle", .5), ("move", durations["move"] / 4),
               ("move", durations["move"] * .75), ("basic_attack", .3), ("basic_attack", .6)]
    for i, (anim, t) in enumerate(samples):
        small = render(data, anim, t, .085)
        sheet.paste(small, (i * 240 + 35, 40), small)
        large = render(data, anim, t, .2)
        sheet.paste(large, (i * 240 - 45, 180), large)
        draw.text((i * 240 + 10, 10), f"{anim} {t:.2f}s", fill="#302a23", font=_font(15))
    draw.text((20, 550), "EXTERNAL QA / top: .085 source scale / bottom: enlarged / not game capture", fill="#302a23", font=_font(15))
    sheet.save(ROOT / "qa-game-scale.png")

    old = load_data(V2 / "foxfire-v2.json")
    old_duration = animation_duration(old, "move")
    count = max(1, round(durations["move"] * 25))
    frames = []
    for i in range(count):
        frame = Image.new("RGB", (1120, 548), BACKGROUND)
        for column, (version, source, duration) in enumerate((("V2", old, old_duration), ("V3", data, durations["move"]))):
            im = render(source, "move", duration * i / count, .35)
            frame.paste(im, (column * 560, 32), im)
            ImageDraw.Draw(frame).text((column * 560 + 15, 10), version, fill="#302a23", font=_font(20))
        ImageDraw.Draw(frame).text((15, 520), "EXTERNAL QA / gait phases synchronized for comparison / not Spine capture", fill="#302a23", font=_font(15))
        frames.append(frame)
    _save_gif(frames, ROOT / "comparison-v2-v3.gif", durations["move"])
    return durations


if __name__ == "__main__":
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "foxfire-v3.json"
    print(json.dumps(make_previews(load_data(source)), indent=2))
