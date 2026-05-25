set nocount on;

declare @aml_identity_name sysname = N'$(AmlIdentityName)';
declare @function_identity_name sysname = N'$(FunctionIdentityName)';

if len(@aml_identity_name) > 0 and not exists (select 1 from sys.database_principals where name = @aml_identity_name)
begin
  declare @create_aml_user nvarchar(max) = N'create user ' + quotename(@aml_identity_name) + N' from external provider';
  exec sp_executesql @create_aml_user;
end;

if len(@function_identity_name) > 0 and not exists (select 1 from sys.database_principals where name = @function_identity_name)
begin
  declare @create_function_user nvarchar(max) = N'create user ' + quotename(@function_identity_name) + N' from external provider';
  exec sp_executesql @create_function_user;
end;

if len(@aml_identity_name) > 0 and is_rolemember(N'db_datareader', @aml_identity_name) = 0
begin
  declare @add_aml_reader nvarchar(max) = N'alter role db_datareader add member ' + quotename(@aml_identity_name);
  exec sp_executesql @add_aml_reader;
end;

if len(@aml_identity_name) > 0 and is_rolemember(N'db_datawriter', @aml_identity_name) = 0
begin
  declare @add_aml_writer nvarchar(max) = N'alter role db_datawriter add member ' + quotename(@aml_identity_name);
  exec sp_executesql @add_aml_writer;
end;

if len(@function_identity_name) > 0 and is_rolemember(N'db_datareader', @function_identity_name) = 0
begin
  declare @add_function_reader nvarchar(max) = N'alter role db_datareader add member ' + quotename(@function_identity_name);
  exec sp_executesql @add_function_reader;
end;
