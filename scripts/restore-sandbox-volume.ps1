<#
.SYNOPSIS
  Восстановление одного или нескольких docker volume песочницы из ./backups.

.USAGE
  Запусти из корня репозитория:
    powershell -ExecutionPolicy Bypass -File .\scripts\restore-sandbox-volume.ps1

  Конкретный volume из последнего архива:
    powershell -ExecutionPolicy Bypass -File .\scripts\restore-sandbox-volume.ps1 -VolumeNames "agent-work-sandbox-lite"

  Явно указать архив для одного volume:
    powershell -ExecutionPolicy Bypass -File .\scripts\restore-sandbox-volume.ps1 -VolumeNames "agent-home-global" -ArchivePaths ".\backups\agent-home-global_20260309_101500.tar.gz"

  Несколько volume с явными архивами в том же порядке:
    powershell -ExecutionPolicy Bypass -File .\scripts\restore-sandbox-volume.ps1 -VolumeNames "agent-work-sandbox-lite","agent-home-global" -ArchivePaths ".\backups\agent-work-sandbox-lite_20260309_101500.tar.gz",".\backups\agent-home-global_20260309_101500.tar.gz"
#>

param(
  # Список volume для восстановления. По умолчанию — все volume этой песочницы.
  [string[]]$VolumeNames = @("agent-work-sandbox-lite", "agent-home-global"),

  # Явные пути к архивам .tar.gz. Если не заданы, берется последний архив по имени volume.
  [string[]]$ArchivePaths = @(),

  [string]$BackupsDirName = "backups",

  # Если указан, содержимое volume будет удалено перед восстановлением.
  [switch]$Force
)

$ErrorActionPreference = "Stop"

chcp 65001 | Out-Null

function Assert-DockerAvailable {
  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if (-not $docker) {
    throw "Команда 'docker' не найдена. Установи Docker Desktop/Engine и повтори."
  }
}

function Ensure-Volume([string]$Name) {
  & docker volume inspect $Name *> $null
  if ($LASTEXITCODE -eq 0) {
    return
  }

  Write-Host "Создаю Docker volume '$Name'..."
  & docker volume create $Name *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "Не удалось создать Docker volume '$Name'."
  }
}

function Resolve-ArchivePath([string]$VolumeName, [string]$BackupsDir, [string[]]$ExplicitArchivePaths, [int]$Index) {
  if ($ExplicitArchivePaths.Count -gt 0) {
    if ($ExplicitArchivePaths.Count -ne $VolumeNames.Count) {
      throw "Если указан -ArchivePaths, число архивов должно совпадать с числом volume в -VolumeNames."
    }

    $candidate = $ExplicitArchivePaths[$Index]
    $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction Stop
    return $resolved.Path
  }

  $latest = Get-ChildItem -LiteralPath $BackupsDir -File |
    Where-Object { $_.Name -like "${VolumeName}_*.tar.gz" } |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

  if (-not $latest) {
    throw "Не найден архив для volume '$VolumeName' в каталоге '$BackupsDir'."
  }

  return $latest.FullName
}

$repoRoot = (Get-Location).Path
$backupsDir = Join-Path $repoRoot $BackupsDirName

if (-not (Test-Path -LiteralPath $backupsDir)) {
  throw "Каталог с бэкапами не найден: $backupsDir"
}

Assert-DockerAvailable

for ($i = 0; $i -lt $VolumeNames.Count; $i++) {
  $volumeName = $VolumeNames[$i]
  $archivePath = Resolve-ArchivePath -VolumeName $volumeName -BackupsDir $backupsDir -ExplicitArchivePaths $ArchivePaths -Index $i
  $archiveName = Split-Path -Leaf $archivePath
  $archiveDir = Split-Path -Parent $archivePath
  $archiveDirForDocker = $archiveDir.Replace("\", "/")

  Ensure-Volume $volumeName

  $restoreCommand = if ($Force) {
    "find /v -mindepth 1 -maxdepth 1 -exec rm -rf {} \; && tar -xzf /backup/$archiveName -C /v"
  } else {
    "tar -xzf /backup/$archiveName -C /v"
  }

  $dockerArgs = @(
    "run", "--rm",
    "-v", "${volumeName}:/v",
    "-v", "${archiveDirForDocker}:/backup:ro",
    "busybox", "sh", "-lc",
    $restoreCommand
  )

  Write-Host "Восстанавливаю volume '$volumeName' из '$archiveName'..."
  & docker @dockerArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Восстановление volume '$volumeName' не выполнено (docker run завершился с кодом $LASTEXITCODE)."
  }

  Write-Host "Готово: volume '$volumeName' восстановлен."
}
