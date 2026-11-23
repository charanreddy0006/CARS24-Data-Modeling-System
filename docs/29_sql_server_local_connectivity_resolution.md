# SQL Server Local Connectivity Resolution

> **Later runtime update (2026-11-22):** The operator subsequently connected from normal Windows CMD under `chakri\chara` using Shared Memory (`sqlcmd -S "lpc:.\SQLEXPRESS" -E -C`) and completed the pre-generation checks and Phases 01-03 successfully. Earlier Codex-shell failures below were environment/account-specific and are not the current execution status. The operator separately reports Phase 04 COMMITTED / PASS with 12 independent zero-failure read-only checks; its connection method was not specified here. Phases 05-06 and the independent validator have not been run.

**Date:** 2026-11-21
**Outcome:** Earlier Codex-environment connection attempts failed; a later normal Windows CMD connection succeeded for Phase 01/02 execution.

## Executive summary of the original diagnostics

The intended local instance is identified from the Windows SQL instance map as `SQLEXPRESS` → `MSSQL17.SQLEXPRESS`; its service is `MSSQL$SQLEXPRESS`. The service is running, but TCP/IP and Named Pipes are disabled. Shared Memory is enabled, yet local Windows-authenticated client attempts fail with `The target principal name is incorrect. Cannot generate SSPI context` or SQLCMD encryption/provider errors. No connection succeeded and the SQL Server/database identity could not be queried.

This process runs as `chakri\CodexSandboxOffline` and is not a Windows administrator. SQL Server Configuration Manager 17 is installed, but enabling protocols and restarting SQL Server require an administrator. No system configuration was changed and the service was not restarted.

## Actual instance and installed tools

- Windows service: `MSSQL$SQLEXPRESS`; display name `SQL Server (SQLEXPRESS)`; Running; Automatic (delayed start).
- Service executable: `C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\Binn\sqlservr.exe -sSQLEXPRESS`.
- Service account: `NT Service\MSSQL$SQLEXPRESS`.
- Registry instance mapping: `SQLEXPRESS` → `MSSQL17.SQLEXPRESS`.
- Product: SQL Server Express Edition `17.0.1000.7`.
- Configuration Manager: `C:\Windows\System32\SQLServerManager17.msc`.
- SQLCMD found at the ODBC 18 client tools path; its help reports SQLCMD version 17.0.1000.7 and it loads Microsoft ODBC Driver 18. SQL PowerShell `Invoke-Sqlcmd` from SQLPS is also installed.
- ODBC Driver 18 DLL: `C:\Windows\System32\msodbcsql18.dll`, file/product version `18.6.2.1`. `Get-OdbcDriver` inventory enumeration returned Access Denied, so other installed ODBC driver entries were not verified.
- SQL Browser: Stopped/Disabled. A fixed local TCP port would not require Browser.
- Current Windows process identity: `chakri\CodexSandboxOffline`; administrator membership check: false.

## Instance network configuration inspected

The instance ID was discovered from `HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL`; protocol settings were then inspected under the matching `MSSQL17.SQLEXPRESS` instance path rather than inferred from the service name.

| Setting | Observed value |
|---|---|
| Shared Memory (`Sm`) | Enabled |
| TCP/IP (`Tcp`) | Disabled |
| Named Pipes (`Np`) | Disabled |
| TCP `ListenOnAllIPs` | Enabled (`1`) |
| TCP `IPAll` static port | Blank |
| TCP `IPAll` dynamic port | Blank / no listener observed |
| Named-pipe path configured | `\\.\pipe\MSSQL$SQLEXPRESS\sql\query` |

All individual TCP address entries are disabled. The machine has multiple non-loopback addresses as well as `127.0.0.1` (`IP14`) and `::1` (`IP13`). Therefore enabling TCP while retaining `ListenOnAllIPs=1` could expose the SQL listener on non-loopback interfaces. A loopback-only configuration is required for the stated local-development goal.

Port `14330` had no TCP endpoint in `Get-NetTCPConnection` and did not appear in the inspected IPv4/IPv6 excluded-port ranges at the time of inspection. Recheck it immediately before configuration; availability can change.

The SQL Server Configuration Manager snap-in is present. The `ComputerManagement17` WMI provider query returned `Invalid class` / `Provider load failure`, so it was not used to change configuration. Reading the instance `ERRORLOG` was denied by filesystem permissions. No startup or listener details beyond the service command line and registry values are claimed.

The instance startup-parameter registry subkey read returned `Requested registry access is not allowed`; therefore startup arguments beyond the service command line are unverified.

## Connection attempts and results

All connection attempts were local and used integrated authentication. The only SQL text supplied was a read-only identity query against `master`, intended to return server, instance, version, login, current database, and target database state. The query did not successfully execute.

- SQLCMD local Shared Memory/local-instance attempts (including `lpc:.\SQLEXPRESS`) failed with `Encryption not supported on the client`, `No credentials are available in the security package`, and `Client unable to establish connection`.
- An explicit local named-pipe attempt to the configured pipe returned the same SQLCMD encryption/provider/connection errors. Registry configuration confirms Named Pipes are disabled.
- SQL PowerShell attempts through `.`/`(local)`/`lpc:` local instance names failed with `The target principal name is incorrect. Cannot generate SSPI context`.
- A SQL PowerShell connection string using `Encrypt=True;TrustServerCertificate=True` for the verified local instance also failed with the SSPI error. Certificate trust did not resolve Windows authentication. The installed SQLPS cmdlet does not expose a `TrustServerCertificate` parameter; the option was limited to the connection string.
- No TCP endpoint exists to test. The standard ports and proposed `14330` had no listener at inspection time.

**Authentication root cause:** the precise SPN/Kerberos/Windows credential cause is **unverified**. The observed SSPI principal-name error is consistent with an authentication identity/SPN problem, but this environment cannot establish which one because no login succeeded. Do not treat certificate trust or protocol enablement as an authentication fix.

## Changes and database impact

- TCP/IP, Named Pipes, registry, service, firewall, TLS, authentication mode, SPNs, and Windows security settings: **unchanged**.
- Service restart: **none**.
- Preflight, generation, and final validator: **not run**.
- Database identity, existence/state, login mapping, fixture state, and data contents: **unverified**.
- No SQL statement succeeded; no database content was accessed or changed.

## Administrator action recommended at time of the original diagnostics

1. At a time when interruption of any existing SQL Server users/tasks is acceptable, open `SQLServerManager17.msc` as a Windows administrator.
2. Under **SQL Server Network Configuration → Protocols for SQLEXPRESS**, enable TCP/IP. In TCP/IP properties, set **Listen All = No**. Keep Named Pipes disabled unless separately required.
3. In **IP Addresses**, enable only the `127.0.0.1` entry (observed registry entry `IP14`). Set its **TCP Dynamic Ports** value blank and **TCP Port** to `14330`, after rechecking that the port is unused. Keep every non-loopback IP entry disabled. Leave `IPAll` unused/blank with Listen All set to No. This avoids binding to the observed non-loopback interfaces.
4. Apply the change and restart only `MSSQL$SQLEXPRESS` if Configuration Manager requires it. The current process cannot inspect active SQL sessions, so the administrator/operator must first confirm the restart will not interrupt other local work. SQL Browser can remain stopped for a fixed port. No firewall rule is needed for loopback-only connectivity.
5. Verify that SQL Server listens only on `127.0.0.1:14330`. Then separately resolve the SSPI failure with the domain/SQL administrator: verify the service SPN for the actual service account and check for missing/duplicate SPNs or an unavailable Windows logon context. Do not change SPNs or bypass authentication as part of this report.
6. Once an approved authenticated connection works, run the read-only identity query and confirm exact server, instance, login, current database, and target database state before any Day 3 preflight.

Day 3 remains **INCOMPLETE and BLOCKED**. This report establishes the local configuration findings and the precise administrator action; it does not establish database connectivity or readiness.

## Follow-up recorded at time of the original diagnostics — 2026-11-21

The latest read-only registry inspection now reports TCP enabled with `ListenOnAllIPs=0`; only the loopback `127.0.0.1` entry is enabled, with static port `14330` and dynamic ports blank. `Test-NetConnection 127.0.0.1 -Port 14330` succeeded. This is a changed observed state since the earlier inspection above. Who changed it and when are unknown; this attempt made no registry, service, firewall, protocol, TLS, SPN, or authentication changes. SQL Browser remains stopped/disabled.

SQLCMD identity queries to `lpc:.\SQLEXPRESS` and `tcp:127.0.0.1,14330` still failed with ODBC Driver 18 encryption/provider errors (`Encryption not supported on the client`, `No credentials are available in the security package`, and connection failure). An explicit integrated-authentication `Invoke-Sqlcmd` connection to loopback TCP, with connection-scoped certificate trust, failed with `The target principal name is incorrect. Cannot generate SSPI context`. The TCP socket is reachable, but SQL Server Windows authentication remains unresolved. No authenticated identity query succeeded; no database statement succeeded, and database identity, state, and contents remain unverified. Preflight, generation, and validation were not run.

The previous administrator troubleshooting recommendations remain applicable for the SSPI issue. After an authorized authentication path works, first run only a read-only identity query and confirm the exact instance and target database state before any Day 3 script.


## Subsequent normal CMD runtime verification (2026-11-21)

The operator later verified a successful SQLCMD connection from normal Windows CMD under `chakri\chara` to `chakri\SQLEXPRESS` using Shared Memory (`sqlcmd -S "lpc:.\SQLEXPRESS" -E -C`). The pre-generation checks passed, and Phases 01 and 02 committed with PASS results. The earlier Codex shell attempts ran under a different Windows account and their failures do not describe this successful connection. Phases 03-06 and the independent final validator have not been executed. Current progress and counts are recorded in `docs/23_day3_preflight_execution_report.md`, `docs/24_day3_synthetic_generation_execution_report.md`, and `docs/26_day3_completion_report.md`.
