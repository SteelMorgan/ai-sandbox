<#
.SYNOPSIS
  Бэкап одного или нескольких docker volume песочницы в ./backups.

.USAGE
  Запусти из корня репозитория:
    powershell -ExecutionPolicy Bypass -File .scriptsackup-sandbox-volume.ps1

  Конкретный volume:
    powershell -ExecutionPolicy Bypass -File .scriptsackup-sandbox-volume.ps1 -VolumeNames "agent-work-sandbox-lite"

  Несколько volume:
    powershell -ExecutionPolicy Bypass -File .scriptsackup-sandbox-volume.ps1 -VolumeNames "agent-work-sandbox-lite","agent-home-global"
#>

param(
  # Список volume для бэкапа. По умолчанию — все volume этой песочницы.
  [string[]]$VolumeNames = @("agent-work-sandbox-lite", "agent-home-global"),
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
  if ($raw -match "(?m)^Q$ignoreLineEs*$") {
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

$backupsDirForDocker = $backupsDir.Replace("\", "/")
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$anyFailed = $false

foreach ($VolumeName in $VolumeNames) {
  & docker volume inspect $VolumeName *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Docker volume '$VolumeName' не найден — пропускаю. Проверь: docker volume ls"
    $anyFailed = $true
    continue
  }

  $archiveName = "${VolumeName}_${ts}.tar.gz"

  $dockerArgs = @(
    "run", "--rm",
    "-v", "${VolumeName}:/v:ro",
    "-v", "${backupsDirForDocker}:/backup",
    "busybox", "sh", "-lc",
    "tar -czf /backup/$archiveName -C /v ."
  )

  Write-Host "Делаю бэкап volume '$VolumeName' -> $BackupsDirName$archiveName"
  & docker @dockerArgs
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Бэкап volume '$VolumeName' не выполнен (docker run завершился с кодом $LASTEXITCODE)."
    $anyFailed = $true
    continue
  }

  $archivePath = Join-Path $backupsDir $archiveName
  if (-not (Test-Path -LiteralPath $archivePath)) {
    Write-Warning "Архив не найден после бэкапа: $archivePath"
    $anyFailed = $true
    continue
  }

  $item = Get-Item -LiteralPath $archivePath
  Write-Host "Готово: $($item.FullName)"
  Write-Host ("Размер: {0:N0} байт" -f $item.Length)
}

if ($anyFailed) {
  throw "Один или несколько volume не удалось сохранить. Смотри предупреждения выше."
}
