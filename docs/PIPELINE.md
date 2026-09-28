# MATLAB pipeline v1

## Launch and scope

Run `tcpserver5555` from the repository root in MATLAB. The script derives all
paths from its own location. The endpoint listens only on 127.0.0.1:5555.
Stop it with `pipeline.stop()`. Do not stop/restart while a job is executing.
Only one pipeline server may own the runtime job directory in production.

This is a serial, cooperative MATLAB timer queue, not a separate worker process.
A blocking MATLAB operation may delay network callbacks. There is no hard task
deadline, process isolation or forced interruption. Local users are trusted;
loopback binding is not authentication. The 8192-character limit is checked
after receiving a complete line, not a bound on TCP receive-buffer memory.

## Wire protocol

UTF-8 JSON Lines: one JSON object followed by LF, one response per request.
The legacy raw MATLAB-code protocol is intentionally removed: no network eval.

```json
{"v":1,"op":"ping"}
{"v":1,"op":"submit","id":"review_001","action":"all"}
{"v":1,"op":"status","id":"review_001"}
{"v":1,"op":"cancel","id":"review_001"}
```

IDs match `[A-Za-z0-9][A-Za-z0-9_-]{0,63}`. Actions: all, environment,
unit, integration, png, liveeditor. Queue capacity: 16 waiting jobs.
Submitting the same ID/action returns its existing report without rerunning it;
reusing the ID for another action fails. Use a new ID to rerun.
`ok` means protocol acceptance, NOT successful computation.

States: queued, running, passed, failed, cancelled, interrupted. Cancellation
is observed between stages, not inside an executing stage. Restart marks old
queued/running reports interrupted; jobs are never automatically replayed.
Cancellation of an already terminal job does not change its outcome.

## Stages and evidence

`all` runs all five stages even if a prior stage fails, recording every failure.
`unit` automatically initializes environment first. Environment writes static
contexts in the job directory and initializes the existing unit geometry engine.
Unit discovery uses matlabtests/unit_test_*.m; every test gets a separate log
and result. Existing missing dependencies remain failures, not skips.

Integration currently registers the deterministic filter2win trajectory with
101 samples and seed 1729. It checks time ordering, NaN throughout the dropout
interval 117–168 seconds, finite initial normal segment, absence of Inf and
window bounds. Additional NaN during anomalous-measurement blind operation is
allowed by the kernel contract. RMSE uses finite samples
and always reports missing/finite counts. This is a scenario regression, not
proof of correctness of all trajectory algorithms or statistical accuracy.
PNG uses the same calculation and writes actual kernel-output snapshots.
Integration and PNG currently each recalculate the scenario independently.
Extend the registered stage implementation for additional scenarios; arbitrary
file paths and MATLAB expressions are not accepted through the protocol.

Live Editor discovers every docs/liveeditor/*_theory.m, runs Code Analyzer and
exports each file to PDF with Run=false. It does not execute arbitrary examples,
inspect rendered formulas or approve mathematical meaning. All reports keep
visual_review=pending. PDF export success is not visual acceptance.

Each job stores request.json, atomic report.json, stage logs, per-test results,
MAT datasets, metrics, PNG and PDF in runtime/pipeline/ID. Working directory,
MATLAB path and RNG state are restored. Arbitrary global side effects in legacy
tests are not isolated. Reports and artifacts persist after client disconnect.
Source revision/hashes and HTML rendering are not yet captured by this service.

## Documentation workflow

The documentation translator remains the sole converter from *_theory.txt.
For an existing source update: generate the documentation PNGs using
generate_filter2win_doc_images (default runtime destination), run
docs/translate_docs.py and docs/test_translate_docs.py with Python, then submit
liveeditor or all for MATLAB validation. Per-job PNGs do not overwrite published
runtime images automatically. This prevents a validation job from silently
changing already published documentation. Review generated PDFs separately.

## Client

matlabtests/pipeline_client.py uses Python standard library only. Example:

```text
python matlabtests/pipeline_client.py all --id review_001 --timeout 600
```

Exit status is zero only for passed. Timeout/disconnect does not cancel the
server job: reconnect and query its ID. Server progress can also be read from
the atomic report file while MATLAB is busy. Python transport tests use a
temporary server on port 5556; do not run concurrent production work then.