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
    "matlab/tests/configs/filter2win_test_cases.json",
    "matlab/tests/configs/filter2win_expanded_reference.json",
    "matlab/tests/configs/filter2win_observation_filter.json",
    "matlab/tests/configs/filter2win_schema2_config.json",
    "docs/fifo_double_theory.md",
    "docs/filter2win_theory.md",
    "docs/filter2win_implementation.md",
    "docs/filter2win_schema2_theory.md",
    "Principes/testing_methodology.md",
)

README = """# filter2win {version}

Исходники MATLAB, конфигурации, обычные тесты и описание алгоритма в Markdown.
Версия пакета указана в VERSION. Код упакован без изменений. Рисунки из теории
включены в docs/images, ссылки на них сделаны локальными для архива.

## Использование

Откройте MATLAB в корне распакованного каталога:

    addpath('matlab/function');
    profile = jsondecode(fileread('matlab/tests/configs/filter2win_config.json'));
    cfg = filter2win_settings(profile);
    ctx = struct();
    [rc, ctx] = filter2win(cfg, ctx, 0, 1, false);

Состояние ctx передаётся в следующий вызов. Время последующих измерений должно
увеличиваться. Готовность выхода показывает ctx.FILTER_VALID.
Начните с docs/filter2win_theory.md: это объяснение для аналитика с рисунками
и формулами. Подробности вызова и устройства — в docs/filter2win_implementation.md. В схеме 3 ctx.FILTER_DEBUG показывает
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

Данные численных проверок объединены в filter2win_test_cases.json. Настройки
фильтра отделены от независимых ожиданий тестов. Проверки поведения сохранены.

Упаковка не запускает эти тесты, MATLAB, службы или экспорт документации.
"""


def build(version, output):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", version):
        raise ValueError("Version may contain letters, numbers, dots, underscores and hyphens")
    # Read all inputs before creating the archive; a missing file leaves no partial ZIP.
    files = [(relative, (ROOT / relative).read_bytes()) for relative in FILES]
    # Store each figure once; both descriptions use links inside the archive.
    images = {}
    for theory_path in ("docs/filter2win_theory.md", "docs/filter2win_implementation.md"):
        theory = (ROOT / theory_path).read_text(encoding="utf-8")
        figures = re.findall(r"!\[[^\]]*\]\(([^)]+\.png)\)", theory)
        for link in dict.fromkeys(figures):
            source = (ROOT / "docs" / link).resolve()
            source.relative_to(ROOT.resolve())
            destination = "docs/images/" + source.name
            content = source.read_bytes()
            if destination in images and images[destination] != content:
                raise ValueError("Different images have the same name: " + source.name)
            images[destination] = content
            theory = theory.replace("(" + link + ")", "(images/" + source.name + ")")
        files = [(name, theory.encode("utf-8") if name == theory_path else content)
                 for name, content in files]
    files.extend(images.items())
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
