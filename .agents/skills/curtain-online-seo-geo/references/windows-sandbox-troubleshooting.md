# Windows Sandbox Troubleshooting

Use this reference when local `functions.shell_command` calls fail before the project command runs.

## Known Symptoms

Treat these as Codex Windows sandbox/runtime issues, not project issues:

- `windows sandbox: spawn setup refresh`
- `codex-windows-sandbox-setup.exe ... os error 740`
- `要求的作業需要提升的權限`
- `windows sandbox: runner error: CreateProcessAsUserW failed: 1312`
- `windows sandbox: CreateProcessWithLogonW failed`

## Fast Triage

First try one simple non-escalated command:

```powershell
$PWD.Path
```

If it fails with a sandbox setup/runner error, use `sandbox_permissions: "require_escalated"` for diagnosis. This is a tool-runtime workaround, not a project permission requirement.

Check the newest sandbox log:

```powershell
$sandboxDir = Join-Path $env:USERPROFILE '.codex\.sandbox'
$log = Get-ChildItem -LiteralPath $sandboxDir -Filter 'sandbox*.log' |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
Get-Content -LiteralPath $log.FullName -Tail 160
```

## Fix `os error 740`

If the log shows `codex-windows-sandbox-setup.exe` failed with `os error 740`, add a per-user `RUNASINVOKER` compatibility flag for the current sandbox setup helper:

```powershell
$setup = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE '.vscode\extensions') -Recurse -Filter 'codex-windows-sandbox-setup.exe' |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $setup) { throw 'codex-windows-sandbox-setup.exe not found' }

$key = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
New-ItemProperty -Path $key -Name $setup.FullName -Value 'RUNASINVOKER' -PropertyType String -Force | Out-Null
```

Retest:

```powershell
$PWD.Path
```

## If `1312` Remains

If setup now succeeds but commands still fail with:

```text
CreateProcessAsUserW failed: 1312
```

check whether setup actually completed:

```powershell
Get-Content -LiteralPath $log.FullName -Tail 80
Get-LocalUser | Where-Object { $_.Name -match 'CodexSandbox' } |
  Select-Object Name,Enabled,LastLogon,PasswordRequired
```

Observed behavior on this project machine:

- `RUNASINVOKER` fixed the `os error 740` setup failure.
- The setup helper then completed successfully.
- `CodexSandboxOffline` logged in successfully.
- WFP/firewall sandbox setup succeeded.
- `CreateProcessAsUserW failed: 1312` still remained at command-runner launch.

When this exact state recurs, stop spending time on sandbox repair inside the task. Continue project work with `sandbox_permissions: "require_escalated"` for shell commands and explain briefly that the Windows sandbox runner is failing independently of the repo.

## Do Not Do During Project Work

- Do not delete `CodexSandboxOffline`, `CodexSandboxOnline`, or `CodexSandboxUsers` unless the user explicitly approves a full Codex sandbox reset.
- Do not kill VS Code/Codex processes from inside the task unless the user explicitly approves interruption.
- Do not keep retrying full project tasks in non-escalated sandbox after repeated `1312`; use escalated commands and keep moving.
- Do not treat this as a PowerShell 7, npm, FTP, or repository bug unless command output points there after sandbox is bypassed.
