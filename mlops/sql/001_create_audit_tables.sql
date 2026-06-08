set nocount on;

if object_id(N'dbo.model_run_log', N'U') is null
begin
  create table dbo.model_run_log (
    run_id nvarchar(128) not null primary key,
    environment nvarchar(64) null,
    owner nvarchar(128) null,
    status nvarchar(64) null,
    row_count int null,
    drift_status nvarchar(64) null,
    started_at_utc nvarchar(64) null,
    finished_at_utc nvarchar(64) null,
    model_version nvarchar(256) null,
    input_blob_path nvarchar(1024) null,
    artifact_manifest_uri nvarchar(2048) null,
    publish_status nvarchar(64) null,
    trigger_type nvarchar(64) null,
    model_repo nvarchar(256) null,
    model_ref nvarchar(256) null,
    model_commit_sha nvarchar(128) null,
    updated_at_utc datetime2 not null default sysutcdatetime()
  );
end;

if object_id(N'dbo.model_output_snapshot_metadata', N'U') is null
begin
  create table dbo.model_output_snapshot_metadata (
    run_id nvarchar(128) not null primary key,
    environment nvarchar(64) null,
    snapshot_uri nvarchar(2048) null,
    row_count int null,
    drift_status nvarchar(64) null,
    output_schema_version nvarchar(128) null,
    created_at_utc nvarchar(64) null,
    updated_at_utc datetime2 not null default sysutcdatetime()
  );
end;

if object_id(N'dbo.data_quality_log', N'U') is null
begin
  create table dbo.data_quality_log (
    quality_log_id bigint identity(1,1) not null primary key,
    run_id nvarchar(128) not null,
    environment nvarchar(64) null,
    check_name nvarchar(128) not null,
    check_status nvarchar(64) not null,
    observed_value nvarchar(512) null,
    threshold_value nvarchar(512) null,
    created_at_utc datetime2 not null default sysutcdatetime()
  );
end;

if not exists (select 1 from sys.indexes where name = N'ix_model_run_log_environment_status' and object_id = object_id(N'dbo.model_run_log'))
begin
  create index ix_model_run_log_environment_status on dbo.model_run_log(environment, status);
end;

if not exists (select 1 from sys.indexes where name = N'ix_model_run_log_model_ref' and object_id = object_id(N'dbo.model_run_log'))
begin
  create index ix_model_run_log_model_ref on dbo.model_run_log(model_repo, model_ref, model_commit_sha);
end;
