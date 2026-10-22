"""Create a filter2win ZIP from source files. Does not run MATLAB or exporters."""
import argparse
from pathlib import Path
import re
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
FILES = (
    "matlab/function/fifo_double.m",
    "matlab/function/filter2win.m",
    "matlab/function/filter2win_execute.m",
    "matlab/function/filter2win_initial_state.m",
    "matlab/function/filter2win_persistent_conditions.m",
    "matlab/function/filter2win_persistent_execute.m",
    "matlab/function/filter2win_persistent_prepare.m",
    "matlab/function/filter2win_persistent_transition.m",
    "matlab/function/filter2win_prepare.m",
    "matlab/function/filter2win_transition.m",
    "matlab/function/filter2win_window_view.m",
    "matlab/function/filter2win_band.m",
    "matlab/function/filter2win_features.m",
    "matlab/function/filter2win_model.m",
    "matlab/function/filter2win_persistent.m",
    "matlab/function/filter2win_settings.m",
    "matlab/function/filter2win_status_name.m",
    "matlab/function/filter2win_validate.m",
    "matlab/function/filter2win_validate_persistent.m",
    "matlab/tests/unit_test_fifo_double.m",
    "matlab/tests/unit_test_filter2win_settings.m",
    "matlab/tests/unit_test_filter2win_persistent.m",
    "matlab/tests/unit_test_filter2win_schema2.m",
    "matlab/tests/unit_test_filter2win_candidate.m",
    "matlab/tests/support/filter2win_config.m",
    "matlab/tests/support/filter2win_debug_line.m",
    "matlab/tests/support/filter2win_debug_persistent.m",
    "matlab/tests/configs/fifo_double_cases.json",
    "matlab/tests/configs/filter2win_config.json",
    "matlab/tests/configs/filter2win_expanded_reference.json",
    "matlab/tests/configs/filter2win_observation_filter.json",
    "matlab/tests/configs/filter2win_observation_reference.json",
    "matlab/tests/configs/filter2win_schema3_cases.json",
    "matlab/tests/configs/filter2win_schema2_config.json",
    "matlab/tests/configs/filter2win_schema2_cases.json",
    "matlab/tests/configs/filter2win_cases.json",
    "docs/fifo_double_theory.md",
    "docs/filter2win_theory.md",
    "docs/filter2win_schema2_theory.md",
)

README = """# filter2win {version}

Исходники MATLAB, конфигурации, обычные тесты и описание алгоритма в Markdown.
Версия пакета указана в VERSION. Исходные файлы упакованы без изменений.

## Использование

Откройте MATLAB в корне распакованного каталога:

    addpath('matlab/function');
    profile = jsondecode(fileread('matlab/tests/configs/filter2win_config.json'));
    cfg = filter2win_settings(profile);
    ctx = struct();
    [rc, ctx] = filter2win(cfg, ctx, 0, 1, false);

Состояние ctx передаётся в следующий вызов. Время последующих измерений должно
увеличиваться. Готовность выхода показывает ctx.FILTER_VALID.
Читать алгоритм следует с docs/filter2win_theory.md: там условия, приоритеты,
таблица действий и численные примеры. В схеме 3 ctx.FILTER_DEBUG показывает
event, action, phase и reason; FILTER_STATUS описывает результат такта.
Диспетчер — filter2win_persistent, расчёт условий —
filter2win_persistent_conditions, выбор — filter2win_persistent_transition,
исполнение и публикация — filter2win_persistent_execute.

## Тесты вручную

    addpath('matlab/function', 'matlab/tests', 'matlab/tests/support');
    unit_test_fifo_double;
    unit_test_filter2win_settings;
    unit_test_filter2win_persistent;
    unit_test_filter2win_schema2;
    unit_test_filter2win_candidate;

Упаковка не запускает эти тесты, MATLAB, службы или экспорт документации.
"""


def build(version, output):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", version):
        raise ValueError("Version may contain letters, numbers, dots, underscores and hyphens")
    # Read all inputs before creating the archive; a missing file leaves no partial ZIP.
    files = [(relative, (ROOT / relative).read_bytes()) for relative in FILES]
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    prefix = "filter2win-" + version
    archive = output / (prefix + ".zip")
    with ZipFile(archive, "x", compression=ZIP_DEFLATED) as bundle:
        for relative, content in files:
            bundle.writestr(prefix + "/" + relative, content)
        bundle.writestr(prefix + "/VERSION", version + "\n")
        bundle.writestr(prefix + "/README.md", README.format(version=version))
    return archive


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", required=True, type=Path, help="Directory for the ZIP")
    args = parser.parse_args()
    try:
        archive = build(args.version, args.output)
    except (OSError, ValueError) as error:
        parser.exit(1, str(error) + "\n")
    print(archive)


if __name__ == "__main__":
    main()
