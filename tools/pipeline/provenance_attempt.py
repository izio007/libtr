"""Client attempt evidence, not proof of server execution provenance."""
import json
from pathlib import Path

from provenance_snapshot import capture, changed_inputs, digest, encoded
from artifact_registry import build as build_registry
from traceability_builder import publish
from check_preflight import validate


def accompanied(root, specification_path, output, request, execute, git='git'):
    root = Path(root).resolve()
    specification_path = Path(specification_path).resolve()
    output = Path(output).resolve()
    if output.is_relative_to(root / 'runtime' / 'pipeline'):
        raise ValueError('Attempt must be outside server job directories')
    if (not specification_path.is_relative_to(root)
            or specification_path.is_relative_to(root / 'runtime')):
        raise ValueError('Specification must be inside project outside runtime')
    specification_bytes = specification_path.read_bytes()
    spec = json.loads(specification_bytes)
    declaration = specification_path.relative_to(root).as_posix()
    if not any((root / item['path']).resolve() == specification_path for item in spec['inputs']):
        spec['inputs'].append(dict(path=declaration, role='input_declaration'))
    manifest = capture(root, spec, output, git)
    if (output / 'inputs' / declaration).read_bytes() != specification_bytes:
        raise RuntimeError('Specification changed during capture; no submission')
    request_bytes = encoded(request)
    (output / 'request.json').write_bytes(request_bytes)
    record = dict(schema_version=1, request=request,
                  request_sha256=digest(request_bytes),
                  input_manifest_sha256=digest((output / 'manifest.json').read_bytes()),
                  applicability='UNCONFIRMED', loaded_code_identity='unconfirmed',
                  verification_status='NOT_RUN', server_response=None, client_error=None)
    record['preflight'] = dict(state='NOT_RUN')
    try:
        if 'check_mapping' in spec:
            record['preflight'] = dict(state='FAILED')
            record['preflight'] = validate(output, manifest, spec['check_mapping'], request)
        response = execute()
        record['server_response'] = response
    except Exception as error:
        record['client_error'] = dict(type=type(error).__name__, message=str(error))
        raise
    finally:
        try:
            changes = changed_inputs(root, manifest)
            record['input_comparison'] = dict(changed=changes, error=None)
        except Exception as error:
            record['input_comparison'] = dict(changed=None, error=str(error))
        with (output / 'attempt.json').open('xb') as stream:
            stream.write(encoded(record))
        inventory = dict(state='NOT_RUN', error=None,
                         attempt_sha256=digest((output / 'attempt.json').read_bytes()))
        if record['server_response'] is not None:
            try:
                registry = build_registry(root, output / 'attempt.json')
                publish(root, output / 'artifacts.json', registry)
                inventory.update(state='PASS', registry_sha256=digest(
                    (output / 'artifacts.json').read_bytes()))
            except Exception as error:
                inventory.update(state='FAILED', error=dict(
                    type=type(error).__name__, message=str(error)))
        publish(root, output / 'artifact_status.json', inventory)
    clean = (record['input_comparison'] == dict(changed=[], error=None)
             and inventory['state'] == 'PASS')
    return response, clean