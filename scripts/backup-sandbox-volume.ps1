<#
.SYNOPSIS
  Бэкап docker volume клиентской песочницы в ./backups и добавление backups/ в .gitignore.

.USAGE
  Запусти из корня репозитория:
    powershell -ExecutionPolicy Bypass -File .\scripts\backup-sandbox-volume.ps1

  (опционально) другой volume:
    powershell -ExecutionPolicy Bypass -File .\scripts\backup-sandbox-volume.ps1 -VolumeName "agent-work-sandbox-lite"
#>

param(
  [string]$VolumeName = "agent-work-sandbox-lite",
  [string]$BackupsDirName = "backups"
)

$ErrorActionPreference = "Stop"

chcp 65001 | Out-Null

$repoRoot = (Get-Location).Path
$backupsDir = Join-Path $repoRoot $BackupsDirName
$gitignorePath = Join-Path $repoRoot ".gitignore"

if (-not (Test-Path -LiteralPath $backupsDir)) {
  New-Item -ItemType Directory -Path $backupsDir | Out-Null
}

$ignoreLine = "backups/"
$needsAppend = $true

if (Test-Path -LiteralPath $gitignorePath) {
  $raw = Get-Content -LiteralPath $gitignorePath -Raw
  if ($raw -match "(?m)^\Q$ignoreLine\E\s*$") {
    $needsAppend = $false
  }
} else {
  $raw = ""
}

if ($needsAppend) {
  $nl = "`r`n"
  $textToAppend = ($nl + $ignoreLine + $nl)
  $utf8bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::AppendAllText($gitignorePath, $textToAppend, $utf8bom)
}

& docker volume inspect $VolumeName *> $null
if ($LASTEXITCODE -ne 0) {
  throw "Docker volume '$VolumeName' не найден. Проверь имя: docker volume ls"
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$archiveName = "${VolumeName}_${ts}.tar.gz"

$backupsDirForDocker = $backupsDir.Replace("\", "/")

$dockerArgs = @(
  "run", "--rm",
  "-v", "${VolumeName}:/v:ro",
  "-v", "${backupsDirForDocker}:/backup",
  "busybox", "sh", "-lc",
  "tar -czf /backup/$archiveName -C /v ."
)

Write-Host "Делаю бэкап volume '$VolumeName' -> $BackupsDirName\$archiveName"
& docker @dockerArgs
if ($LASTEXITCODE -ne 0) {
  throw "Бэкап не выполнен (docker run завершился с кодом $LASTEXITCODE)."
}

$archivePath = Join-Path $backupsDir $archiveName
if (-not (Test-Path -LiteralPath $archivePath)) {
  throw "Архив не найден после бэкапа: $archivePath"
}

$item = Get-Item -LiteralPath $archivePath
Write-Host "Готово: $($item.FullName)"
Write-Host ("Размер: {0:N0} байт" -f $item.Length)
