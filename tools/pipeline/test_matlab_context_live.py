"""Explicit live regression; not part of automatic unittest discovery."""
import json
import subprocess
import sys
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[2]
    tests = root / 'matlab/tests'
    probe = tests / 'unit_test_context_hot_probe.m'
    helper = tests / 'context_hot_probe_helper.m'
    if probe.exists() or helper.exists():
        raise RuntimeError('Probe paths already exist')
    token = 'context_hot_' + __import__('uuid').uuid4().hex[:12]
    try:
        for version in (1, 2):
            helper.write_text('function x=context_hot_probe_helper\n'
                              'persistent calls; if isempty(calls), calls=0; end\n'
                              f'calls=calls+1; x=[{version} calls];\nend\n', encoding='utf-8')
            probe.write_text('function unit_test_context_hot_probe\n'
                             "assert(evalin('base','exist(''context_dirty'',''var'')')==0);\n"
                             'global context_dirty_global; assert(isempty(context_dirty_global));\n'
                             f'assert(isequal(context_hot_probe_helper(),[{version} 1]));\n'
                             "assignin('base','context_dirty',1); context_dirty_global=1;\n"
                             "fid=fopen('host_pid.txt','w'); fprintf(fid,'%d',feature('getpid')); fclose(fid);\nend\n",
                             encoding='utf-8')
            subprocess.run([sys.executable, str(root/'tools/pipeline/pipeline_client.py'),
                            'unit', '--test', 'unit_test_context_hot_probe', '--id',
                            token + '_' + str(version), '--timeout', '90',
                            '--test-sha256', 'current'], check=True)
        folders = [root/'runtime/pipeline'/(token+'_'+str(v)) for v in (1, 2)]
        pids = [(folder/'host_pid.txt').read_text() for folder in folders]
        assert pids[0] == pids[1], pids
        for folder in folders:
            assert json.loads((folder/'report.json').read_bytes())['state'] == 'passed'
        print('PASS same PID, refreshed sources and clean state:', pids[0], token)
    finally:
        probe.unlink(missing_ok=True)
        helper.unlink(missing_ok=True)


if __name__ == '__main__':
    main()