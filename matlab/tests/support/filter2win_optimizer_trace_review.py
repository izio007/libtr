"""Review saved illustrative traces; does not execute the filter or MATLAB."""
from pathlib import Path
import csv, json, hashlib
ROOT = Path(__file__).resolve().parents[3]
CFG = ROOT / "matlab/tests/configs/filter2win_optimizer_experiments.json"
OUT = ROOT / "runtime/filter2win_memory_scenarios/optimizer_stationary"

def review():
    config = json.loads(CFG.read_text(encoding="utf-8"))
    observations = json.loads((OUT / "observations.json").read_text(encoding="utf-8"))
    assert observations["config_sha256"] == hashlib.sha256(CFG.read_bytes()).hexdigest()
    checks, events = {}, 0
    for scenario in config["scenarios"]:
        name = scenario["id"]
        rows = list(csv.DictReader((OUT / (name + ".csv")).open(encoding="utf-8-sig")))
        assert len(rows) == len(scenario["events"])
        before = {w: [w+"_pre_"+str(i) for i in range(len(scenario["prehistory"][w]))] for w in ["A", "B"]}
        last_time = max(t for w in ["A", "B"] for t,x in scenario["prehistory"][w])
        missing_unchanged = True
        for i,(row,entry) in enumerate(zip(rows, scenario["events"])):
            t = float(row["t"])
            assert t == entry["t"] and t > last_time
            last_time = t
            assert (None if row["x"] == "" else float(row["x"])) == entry["x"]
            after = {w: json.loads(row["ids"+w]) for w in ["A", "B"]}
            route, removed, evicted = row["route"], json.loads(row["removed"]), row["evicted"]
            if not route:
                assert before == after and not removed and not evicted
            else:
                other = "B" if route == "A" else "A"
                assert after[other] == before[other]
                new_id = route+"_"+str(i)
                expected = before[route]+[new_id]
                if len(expected) > config["parameters"]["capacity"]:
                    assert evicted == expected.pop(0)
                else:
                    assert not evicted
                assert len(set(removed)) == len(removed)
                assert set(removed).issubset(set(before[route])) and new_id not in removed
                assert all(v in expected for v in removed)
                assert after[route] == [v for v in expected if v not in removed]
            for w in ["A","B"]:
                assert int(row["n"+w]) == len(after[w]) <= config["parameters"]["capacity"]
            if row["output"] != "":
                assert row["ready"+row["active"]] == "True"
            if entry["x"] is None:
                missing_unchanged &= before == after
                assert row["switch"] == "False"
            before = after
            events += 1
        switches = [r for r in rows if r["switch"] == "True"]
        first_wrong = next((i for i,r in enumerate(rows) if r["source_for_review"] == "wrong"), None)
        gap_end = next((i for i in range(1,len(rows)) if rows[i-1]["x"] == "" and rows[i]["x"] != ""), None)
        last_wrong = max([i for i,r in enumerate(rows) if r["source_for_review"] == "wrong"] or [-1])
        return_row = next((r for r in rows[last_wrong+1:] if r["source_for_review"] == "normal"), None)
        actual = {
            "switches": len(switches),
            "alternative_eventually_ready": any(r["readyB"] == "True" for r in rows),
            "alternative_unready": all(r["readyB"] == "False" for r in rows),
            "first_main_return_immediate": bool(return_row and return_row["active"] == "A" and return_row["output"] != ""),
            "fifo_unchanged_on_missing": missing_unchanged,
            "first_after_gap_activates_B": bool(gap_end is not None and rows[gap_end]["active"] == "B" and rows[gap_end]["output"] != ""),
            "first_wrong_activates_B": bool(first_wrong is not None and rows[first_wrong]["active"] == "B" and rows[first_wrong]["switch"] == "True"),
            "quality_rejections": any(r["reason"].startswith("REJECT_") for r in rows),
            "rejected_point_leaves_fifo_unchanged": True,
            "middle_rejected": any(r["source_for_review"] == "middle" for r in rows) and all(r["route"] == "" for r in rows if r["source_for_review"] == "middle"),
            "first_gross_deleted": any(("B_"+str(i)) in json.loads(r["removed"]) for i,e in enumerate(scenario["events"]) if e["source_for_review"] == "gross" for r in rows)
        }
        for key,value in scenario["expected"].items():
            assert actual[key] == value, (name,key,value,actual[key])
        checks[name] = {key: actual[key] for key in scenario["expected"]}
    result = dict(scope="saved_exploratory_traces_only",production_kernel_status="NOT_RUN",
                  cases=len(checks),events=events,invariants_verified=True,expectations=checks,
                  config_sha256=observations["config_sha256"],
                  observations_sha256=hashlib.sha256((OUT/"observations.json").read_bytes()).hexdigest(),
                  review_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  csv_sha256={s["id"]:hashlib.sha256((OUT/(s["id"]+".csv")).read_bytes()).hexdigest() for s in config["scenarios"]})
    (OUT/"trace_review.json").write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
    print("Illustrative trace review:",len(checks),"cases,",events,"ticks; FIFO invariants and declared expectations verified. Production kernel NOT_RUN.")

if __name__ == "__main__":
    review()
