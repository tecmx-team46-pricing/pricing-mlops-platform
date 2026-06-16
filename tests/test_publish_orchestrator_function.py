import json
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PUBLISH_SCRIPT = ROOT / "mlops" / "scripts" / "publish_orchestrator_function.sh"


def test_publish_rejects_local_model_source_without_flag(tmp_path):
    model_repo = _minimal_model_repo(tmp_path)

    result = _run_publish(
        {
            "DRY_RUN": "true",
            "MODEL_REPO_PATH": str(model_repo),
        }
    )

    assert result.returncode != 0
    assert "ALLOW_LOCAL_MODEL_SOURCE=true" in result.stderr


def test_publish_rejects_dirty_local_model_source_without_flag(tmp_path):
    model_repo = _minimal_model_repo(tmp_path)
    (model_repo / "src" / "pricing_mlops" / "dirty.py").write_text("# dirty\n", encoding="utf-8")

    result = _run_publish(
        {
            "DRY_RUN": "true",
            "MODEL_REPO_PATH": str(model_repo),
            "ALLOW_LOCAL_MODEL_SOURCE": "true",
        }
    )

    assert result.returncode != 0
    assert "uncommitted changes" in result.stderr


def test_publish_allows_clean_local_model_source_with_flag(tmp_path):
    model_repo = _minimal_model_repo(tmp_path)
    commit_sha = _git(model_repo, "rev-parse", "HEAD").stdout.strip()

    result = _run_publish(
        {
            "DRY_RUN": "true",
            "KEEP_PACKAGE": "true",
            "MODEL_REPO_PATH": str(model_repo),
            "ALLOW_LOCAL_MODEL_SOURCE": "true",
        }
    )

    assert result.returncode == 0, result.stderr
    package_root = _package_root_from_output(result.stdout)
    model_source = json.loads((package_root / "model_source.json").read_text(encoding="utf-8"))

    assert model_source == {
        "model_commit_sha": commit_sha,
        "model_ref": "",
        "model_repo": "tecmx-team46-pricing/pricing-mlops",
        "model_source": "local",
    }
    assert (package_root / "function_app.py").is_file()
    assert (package_root / "host.json").is_file()
    assert (package_root / "requirements.txt").is_file()
    assert (package_root / "azureml" / "pricing-mlops-pipeline.yml").is_file()
    assert (package_root / "azureml" / "environment.yml").is_file()
    assert (package_root / "azureml" / "conda.yml").is_file()
    assert (package_root / "configs" / "drift_thresholds.json").is_file()
    assert (
        package_root / "platform-components" / "configs" / "drift_thresholds.json"
    ).is_file()
    assert (package_root / "platform-components" / "platform_publish_outputs.py").is_file()
    assert (package_root / "pricing-mlops-source" / "pyproject.toml").is_file()
    assert (
        package_root
        / "pricing-mlops-source"
        / "scripts"
        / "components"
        / "validate_prepare.py"
    ).is_file()
    assert (
        package_root
        / "pricing-mlops-source"
        / "scripts"
        / "components"
        / "build_monitoring_inputs.py"
    ).is_file()
    assert (
        package_root
        / "pricing-mlops-source"
        / "scripts"
        / "components"
        / "calculate_recommendation_validity.py"
    ).is_file()
    assert (
        package_root
        / "pricing-mlops-source"
        / "scripts"
        / "components"
        / "calculate_auth_history_drift.py"
    ).is_file()
    assert (
        package_root
        / "pricing-mlops-source"
        / "scripts"
        / "components"
        / "calculate_operational_decision.py"
    ).is_file()
    assert not (package_root / "pricing-mlops-source" / "notebooks").exists()
    assert (package_root / "pricing-mlops-source" / "src" / "pricing_mlops").is_dir()
    assert not (package_root / "pricing-mlops-source" / "docs").exists()
    assert not (package_root / "pricing-mlops-source" / "tests").exists()
    assert not (package_root / "pricing-mlops-source" / "data" / "samples" / "unmasked").exists()


def test_publish_can_prepare_vendored_function_package(tmp_path):
    model_repo = _minimal_model_repo(tmp_path)

    result = _run_publish(
        {
            "DRY_RUN": "true",
            "KEEP_PACKAGE": "true",
            "MODEL_REPO_PATH": str(model_repo),
            "ALLOW_LOCAL_MODEL_SOURCE": "true",
            "FUNCTION_PACKAGE_MODE": "vendored",
            "SKIP_FUNCTION_DEPENDENCY_INSTALL": "true",
        }
    )

    assert result.returncode == 0, result.stderr
    package_root = _package_root_from_output(result.stdout)

    assert "Function package mode: vendored" in result.stdout
    assert (
        package_root
        / ".python_packages"
        / "lib"
        / "site-packages"
        / ".dependency-install-skipped"
    ).is_file()


def _run_publish(env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    clean_env = {
        key: value
        for key, value in os.environ.items()
        if key
        not in {
            "ALLOW_DIRTY_LOCAL_MODEL_SOURCE",
            "ALLOW_LOCAL_MODEL_SOURCE",
            "MODEL_REPO_PATH",
            "MODEL_REPO_REF",
            "PRICING_MLOPS_REPO",
            "FUNCTION_PACKAGE_MODE",
            "SKIP_FUNCTION_DEPENDENCY_INSTALL",
        }
    }
    clean_env.update(env)
    return subprocess.run(
        [str(PUBLISH_SCRIPT), "staging"],
        cwd=ROOT,
        env=clean_env,
        text=True,
        capture_output=True,
        check=False,
    )


def _minimal_model_repo(tmp_path: Path) -> Path:
    model_repo = tmp_path / "pricing-mlops"
    (model_repo / "scripts" / "components").mkdir(parents=True)
    (model_repo / "src" / "pricing_mlops").mkdir(parents=True)
    (model_repo / "data" / "samples" / "unmasked").mkdir(parents=True)
    (model_repo / "docs").mkdir()
    (model_repo / "tests").mkdir()
    (model_repo / "pyproject.toml").write_text(
        "[project]\nname = \"pricing-mlops\"\nversion = \"0.1.0\"\n",
        encoding="utf-8",
    )
    for filename in (
        "validate_prepare.py",
        "build_monitoring_inputs.py",
        "calculate_recommendation_validity.py",
        "calculate_auth_history_drift.py",
        "calculate_operational_decision.py",
    ):
        (model_repo / "scripts" / "components" / filename).write_text(
            "print('component')\n",
            encoding="utf-8",
        )
    (model_repo / "src" / "pricing_mlops" / "__init__.py").write_text(
        "__version__ = '0.1.0'\n",
        encoding="utf-8",
    )
    (model_repo / "data" / "samples" / "unmasked" / "sample.csv").write_text(
        "sensitive\n",
        encoding="utf-8",
    )
    (model_repo / "docs" / "README.md").write_text("docs\n", encoding="utf-8")
    (model_repo / "tests" / "test_sample.py").write_text("def test_sample(): pass\n", encoding="utf-8")
    _git(model_repo, "init")
    _git(model_repo, "add", ".")
    _git(model_repo, "-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "init")
    return model_repo


def _git(cwd: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=True,
    )


def _package_root_from_output(stdout: str) -> Path:
    for line in stdout.splitlines():
        if line.startswith("Package root: "):
            return Path(line.removeprefix("Package root: ").strip())
    raise AssertionError(f"Package root not found in output:\n{stdout}")
