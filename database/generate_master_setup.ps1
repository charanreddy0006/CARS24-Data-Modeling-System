param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '00_run_complete_database_setup.sql')
)

$ErrorActionPreference = 'Stop'
$sourceFiles = @(
    '01_create_database.sql',
    '02_create_schemas.sql',
    '03_reference_tables.sql',
    '04_core_tables.sql',
    '05_vehicle_catalog.sql',
    '06_vehicle_identity.sql',
    '07_lifecycle_tables.sql',
    '08_constraints.sql',
    '09_indexes.sql',
    '10_seed_reference_data.sql',
    '11_post_execution_validation.sql'
)

$blocks = [System.Collections.Generic.List[string]]::new()
$blocks.Add('/* GENERATED FILE. Regenerate with generate_master_setup.ps1. */')
$blocks.Add('/* A session gate keeps every source batch inert when preconditions fail. */')
$blocks.Add('USE [master];')
$blocks.Add('GO')
$blocks.Add(@'
DECLARE @cars24SetupGate bit = CASE
    WHEN COALESCE(TRY_CONVERT(int, SERVERPROPERTY('ProductMajorVersion')), 0) >= 17
     AND DB_ID(N'CARS24DataModelingSystem') IS NULL
     AND COALESCE(HAS_PERMS_BY_NAME(NULL, N'SERVER', N'CREATE ANY DATABASE'), 0) = 1 THEN 1 ELSE 0 END;
EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Setup_Gate', @value = @cars24SetupGate;
IF @cars24SetupGate = 0
    THROW 51001, 'Setup blocked. Require SQL Server 2025+, CREATE ANY DATABASE permission, and an unused database name. Inspect/backup any existing database; all DDL and seed batches will be skipped.', 1;
'@)
$blocks.Add('GO')

foreach ($fileName in $sourceFiles) {
    $path = Join-Path $PSScriptRoot $fileName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required source script is missing: $path"
    }

    $blocks.Add("/* BEGIN SOURCE: $fileName */")
    $content = Get-Content -LiteralPath $path -Raw
    $batches = [regex]::Split($content, '(?im)^\s*GO\s*(?:--[^\r\n]*)?\s*$')
    foreach ($batch in $batches) {
        if ([string]::IsNullOrWhiteSpace($batch)) { continue }
        $trimmed = $batch.Trim()
        if ($trimmed -match '(?is)^USE\s+\[[^]]+\]\s*;?\s*$') {
            # A context switch does not modify database objects. It remains safe
            # if the gate is closed; every DDL, seed, and validation batch below
            # is guarded by SESSION_CONTEXT.
            $blocks.Add($trimmed)
        }
        else {
            $blocks.Add("IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Setup_Gate')) = 1`r`nBEGIN`r`n    BEGIN TRY`r`n$trimmed`r`n    END TRY`r`n    BEGIN CATCH`r`n        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Setup_Gate', @value = 0;`r`n        THROW;`r`n    END CATCH;`r`nEND;")
        }
        $blocks.Add('GO')
    }
    $blocks.Add("/* END SOURCE: $fileName */")
}

$blocks.Add("EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Setup_Gate', @value = NULL;`r`nGO")

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
$outputText = [regex]::Replace(($blocks -join "`r`n`r`n"), '(?m)[ \t]+$', '')
$encoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($resolvedOutput, $outputText, $encoding)
Write-Output "Generated $resolvedOutput from $($sourceFiles.Count) source SQL files."
