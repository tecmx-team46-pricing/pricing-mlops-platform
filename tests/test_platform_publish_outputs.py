import importlib.util
import json
from pathlib import Path
import sys
import types


ROOT = Path(__file__).resolve().parents[1]
PUBLISH_COMPONENT = ROOT / "mlops" / "components" / "platform_publish_outputs.py"


def _load_publish_component():
    spec = importlib.util.spec_from_file_location("platform_publish_outputs", PUBLISH_COMPONENT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_platform_publish_validates_auth_monitoring_contract_before_upload(tmp_path):
    module = _load_publish_component()
    _write_required_artifacts(tmp_path, module.REQUIRED_AUTH_MONITORING_ARTIFACTS)
    config_path = tmp_path / "configs" / "drift_thresholds.json"
    config_path.parent.mkdir(parents=True)
    config_path.write_text('{"version":"2026-05-07"}\n', encoding="utf-8")
    blob_service = FakeBlobService()

    published = module._publish_from_dir(
        blob_service=blob_service,
        run_dir=tmp_path,
        environment="staging",
        run_owner="team46",
        run_id="20260616T000000Z-test",
        input_blob_path="incoming/current.csv",
        compute_target="azure-ml",
        trigger_type="manual",
        model_repo="tecmx-team46-pricing/pricing-mlops",
        model_ref="feature/monitoring",
        model_commit_sha="abc123",
        monitoring_config_version="2026-05-07",
        monitoring_config_path=config_path,
        containers={
            "curated": "curated",
            "runs": "runs",
            "snapshots": "snapshots",
            "drift_logs": "drift-logs",
            "reports": "reports",
            "artifacts": "artifacts",
        },
    )

    assert "reports/auth_recommendation_validity_report.md" in published
    assert blob_service.uploads["reports"][0].endswith("/reports/auth_recommendation_validity_report.md")
    assert blob_service.uploads["runs"][0].endswith("/model_run_log.json")
    run_log = json.loads((tmp_path / "model_run_log.json").read_text(encoding="utf-8"))
    assert run_log["config_version"] == "2026-05-07"
    assert run_log["monitoring_config_path"] == "configs/drift_thresholds.json"
    assert run_log["monitoring_config_sha256"]
    assert run_log["model_repo"] == "tecmx-team46-pricing/pricing-mlops"
    assert run_log["model_ref"] == "feature/monitoring"
    assert run_log["git_commit_hash"] == "abc123"


def test_platform_publish_rejects_incomplete_auth_monitoring_contract(tmp_path):
    module = _load_publish_component()
    artifacts = [
        path
        for path in module.REQUIRED_AUTH_MONITORING_ARTIFACTS
        if path != "reports/auth_recommendation_validity_report.md"
    ]
    _write_required_artifacts(tmp_path, artifacts)

    try:
        module._publish_from_dir(
            blob_service=FakeBlobService(),
            run_dir=tmp_path,
            environment="staging",
            run_owner="team46",
            run_id="20260616T000000Z-test",
            input_blob_path="incoming/current.csv",
            compute_target="azure-ml",
            trigger_type="manual",
            model_repo="",
            model_ref="",
            model_commit_sha="",
            monitoring_config_version="2026-05-07",
            monitoring_config_path=None,
            containers={
                "curated": "curated",
                "runs": "runs",
                "snapshots": "snapshots",
                "drift_logs": "drift-logs",
                "reports": "reports",
                "artifacts": "artifacts",
            },
        )
    except FileNotFoundError as exc:
        assert "reports/auth_recommendation_validity_report.md" in str(exc)
    else:
        raise AssertionError("Incomplete artifact contract should fail before upload")


def test_platform_publish_uses_managed_identity_client_id(monkeypatch):
    module = _load_publish_component()
    captured = {}

    class FakeManagedIdentityCredential:
        def __init__(self, *, client_id=None):
            captured["client_id"] = client_id

    class FakeDefaultAzureCredential:
        def __init__(self, **kwargs):
            captured["default_kwargs"] = kwargs

    monkeypatch.setitem(
        sys.modules,
        "azure.identity",
        types.SimpleNamespace(
            ManagedIdentityCredential=FakeManagedIdentityCredential,
            DefaultAzureCredential=FakeDefaultAzureCredential,
        ),
    )
    monkeypatch.setenv("MLOPS_USE_MANAGED_IDENTITY_CREDENTIAL", "true")
    monkeypatch.setenv("AZURE_ML_JOB_IDENTITY_CLIENT_ID", "managed-client-id")

    credential = module._azure_credential()

    assert isinstance(credential, FakeManagedIdentityCredential)
    assert captured["client_id"] == "managed-client-id"


def _write_required_artifacts(root: Path, relative_paths) -> None:
    for relative_path in relative_paths:
        path = root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("placeholder\n", encoding="utf-8")


class FakeBlobService:
    def __init__(self):
        self.uploads = {}

    def get_blob_client(self, *, container, blob):
        self.uploads.setdefault(container, []).append(blob)
        return FakeBlobClient()


class FakeBlobClient:
    def upload_blob(self, handle, overwrite):
        assert overwrite is True
        assert handle.read()
