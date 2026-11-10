"""D-20261110-005: compare a legacy (pre-merge) and a merged behaviour fingerprint.

Everything must be identical except native audio playback positions, which are
compared within two samples at 32 kHz (the lowest rate used). Usage:
  python -I tools/compare_fingerprints.py legacy.json merged.json [--output report.json]
"""
import argparse, json, sys

POS_TOL = 2 / 32000

def diff(a, b, path, out, pos=False):
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            if k in ("source", "display_server"):
                continue
            if k not in a or k not in b:
                out.append(f"{path}.{k}: missing on one side")
                continue
            diff(a[k], b[k], f"{path}.{k}", out, pos)
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            out.append(f"{path}: length {len(a)} != {len(b)}")
            return
        trace = path.endswith("audio_trace") or path.endswith("switch_trace")
        for i, (x, y) in enumerate(zip(a, b)):
            if trace and isinstance(x, list):
                for j, (p, q) in enumerate(zip(x, y)):
                    last = j == len(x) - 1
                    if last and isinstance(p, (int, float)) and isinstance(q, (int, float)) and not isinstance(p, bool):
                        if abs(p - q) > POS_TOL:
                            out.append(f"{path}[{i}][{j}]: {p} != {q}")
                    elif p != q:
                        out.append(f"{path}[{i}][{j}]: {p!r} != {q!r}")
                if len(x) != len(y):
                    out.append(f"{path}[{i}]: row length differs")
            else:
                diff(x, y, f"{path}[{i}]", out, pos)
    elif a != b:
        out.append(f"{path}: {a!r} != {b!r}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("legacy"); ap.add_argument("merged"); ap.add_argument("--output")
    args = ap.parse_args()
    a = json.load(open(args.legacy, encoding="utf-8"))
    b = json.load(open(args.merged, encoding="utf-8"))
    out = []
    diff(a, b, "$", out)
    stats = {}
    for name, e in a["directions"].items():
        stats[name] = {"frames": e["frame_count"], "timeline_samples": e["timeline"]["count"],
                       "edge_samples": len(e["timeline"]["edges"]), "audio_trace_rows": len(e["audio_trace"]),
                       "crops": len(e["crops"])}
    report = {"legacy": a["source"], "merged": b["source"], "differences": len(out),
              "first_differences": out[:50], "compared": stats, "audio_position_tolerance_s": POS_TOL}
    if args.output:
        json.dump(report, open(args.output, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)
    print(f"{a['source']} vs {b['source']}: {len(out)} differences")
    for line in out[:20]:
        print("  ", line)
    return 0 if not out else 1

if __name__ == "__main__":
    sys.exit(main())
