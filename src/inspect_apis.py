from pathlib import Path

import pandas as pd
import requests

DATA = Path("../data")
RAW = Path("../data/raw")
RAW.mkdir(exist_ok=True)

ODATA = "https://cbpfapi.unocha.org/vo1/odata"

# name: (url, CSV to compare fields against, or None)
SOURCES = {
    "cbpf_poolfund": (f"{ODATA}/Poolfund", None),
    "cbpf_contributions": (f"{ODATA}/Contribution", "CBPF_Contributions.csv"),
    "cbpf_projects": (f"{ODATA}/ProjectSummary", "CBPF_Projects.csv"),
    "cerf_allocations": (
        "https://cerfgms-webapi.unocha.org/v1/hdxproject/all.json",
        "CERF_Donor_allocations.csv",
    ),
}


def records(body):
    """OData wraps rows in 'value'; the CERF endpoint returns a bare list."""
    if isinstance(body, dict):
        return body.get("value", [])
    return body if isinstance(body, list) else []


def check(name, url, csv=None):
    print(f"\n== {name}\n{url}")
    try:
        r = requests.get(url, timeout=180, headers={"User-Agent": "Mozilla/5.0"})
    except requests.RequestException as e:
        print("request failed:", e)
        return
    print(r.status_code, r.headers.get("content-type"), f"{len(r.content):,} bytes")
    if not r.ok:
        print(r.text[:300])
        return

    try:
        rows = records(r.json())
    except ValueError:
        print("not JSON:", r.text[:300])
        return

    (RAW / f"probe_{name}.json").write_text(r.text, encoding="utf-8")
    print("records:", len(rows))
    if not rows:
        return

    api = {c.lower(): c for c in pd.json_normalize(rows[:50]).columns}
    print("fields:", sorted(api.values()))

    if csv and (DATA / csv).exists():
        mine = {c.strip().lower(): c.strip() for c in pd.read_csv(DATA / csv, nrows=0).columns}
        print("in both:", len(api.keys() & mine.keys()))
        print("only in CSV:", sorted(mine[k] for k in mine.keys() - api.keys()))
        print("only in API:", sorted(api[k] for k in api.keys() - mine.keys()))


if __name__ == "__main__":
    for name, (url, csv) in SOURCES.items():
        check(name, url, csv)