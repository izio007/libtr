# MATLAB test pipeline

Paths below are relative to the repository root.

## Run tests

Start the dedicated MATLAB host once using `tools/matlab/tcpserver5555.m`.
Existing jobs and the queue belong to that process; routine tests reuse it.

Use the same command for every registered suite:

```sh
tools/runner.sh matlab/tests/configs/filter2win_runner.json
tools/runner.sh matlab/tests/configs/filter2win_consumers_runner.json
tools/runner.sh matlab/tests/configs/filter2win_integration_runner.json
tools/runner.sh matlab/tests/configs/all_unit_runner.json
```

`filter2win` executes settings, persistent/schema-3 and schema-2 leaf tests.
Consumers execute the scenario, model and plot tests as separate stages.
Integration executes kernel isolation followed by those three consumer tests.
`all_unit` sends one broad unit request; MATLAB discovers `unit_test_*.m`.
Python stops a suite at its first failed stage. The broad MATLAB unit request
continues its discovered tests and records their failures.

Python-only checks do not require MATLAB:

```sh
tools/runner.sh matlab/tests/configs/pipeline_engine_runner.json
tools/runner.sh matlab/tests/configs/runner_contract.json
```

The JSON configuration contains `schema_version`, `suite` and `timeout_seconds`.
Suite names are registered in `tools/pipeline/declarative_runner.py`.

## Reports

One client report is written to `runtime/pipeline_runs/<id>/report.json`.
Each stage contains its state, duration and returned `value`. MATLAB values
include the job ID, server report path and returned stage metrics. Failures
contain their type, message and traceback. No separate result store is used.

The server keeps `request.json`, `report.json`, logs and generated data inside
`runtime/pipeline/<job-id>`. A passed job is execution evidence for those checks;
it does not approve documents or establish correctness outside their scope.
Reports survive client disconnection. Timeout does not cancel the MATLAB job.

## Host and internal protocol

`pipeline_client.py` is an internal transport/provenance client for explicit
maintenance and live protocol checks. Routine users use `tools/runner.sh`.
The server listens on `127.0.0.1:5555` and accepts UTF-8 JSON Lines.
There is no network evaluation of MATLAB expressions.

```json
{"v":1,"op":"ping"}
{"v":1,"op":"submit","id":"review_001","action":"unit","test":"unit_test_matmul3"}
{"v":1,"op":"status","id":"review_001"}
{"v":1,"op":"cancel","id":"review_001"}
```

Actions are `all`, `environment`, `unit`, `integration`, `documents`,
`liveeditor`, `mapping` and `mapping5000`. `all` runs environment, unit and
integration only. Integration computes its data and images together once;
there is no separate `png` action. Documentation validation and Live Editor
export are explicit maintenance actions, never part of ordinary test execution.
Generated documentation must exist before those actions are requested.

IDs match `[A-Za-z0-9][A-Za-z0-9_-]{0,63}`. The queue holds at most 16 waiting
jobs. An identical ID/action/test/version returns the existing report;
conflicting reuse is rejected. `ok` denotes protocol acceptance, not calculation
success. Lifecycle states are queued, running, passed, failed, cancelled and
interrupted. Cancellation is cooperative between stages.

This is a serial MATLAB timer queue. A blocking operation can delay callbacks;
there is no hard process deadline or forced interruption. Local users are
trusted, and loopback binding is not authentication. The input-length check
is performed after reception of a complete line.

For an idle, deliberate shutdown, create `runtime/pipeline/stop-server`, wait
for the owned host to exit and remove the marker before the next start. Do not
replace an active host as part of testing or packaging. Restart marks unfinished
reports interrupted and never automatically replays jobs.
