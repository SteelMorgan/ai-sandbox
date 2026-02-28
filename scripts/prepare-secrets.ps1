param(
  [string]$EnvFile = "secrets/.env",
  [string]$SecretsDir = "secrets"
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
  $here = $PSScriptRoot
  if (-not $here) { $here = (Resolve-Path ".").Path }
  return (Resolve-Path (Join-Path $here "..")).Path
}

function Read-DotEnv([string]$path) {
  $map = @{}
  if (-not (Test-Path -LiteralPath $path)) { return $map }

  foreach ($line in Get-Content -LiteralPath $path) {
    if ($null -eq $line) { continue }
    $t = ($line -replace "`r$","").Trim()
    if ($t.Length -eq 0) { continue }
    if ($t.StartsWith("#")) { continue }
    $idx = $t.IndexOf("=")
    if ($idx -lt 1) { continue }
    $k = $t.Substring(0, $idx).Trim()
    $v = $t.Substring($idx + 1)
    $v2 = $v.Trim()
    if (($v2.StartsWith('"') -and $v2.EndsWith('"')) -or ($v2.StartsWith("'") -and $v2.EndsWith("'"))) {
      $v2 = $v2.Substring(1, $v2.Length - 2)
    }
    $map[$k] = $v2
  }

  return $map
}

function Write-SecretFile([string]$path, [string]$value) {
  if ($null -eq $value) { $value = "" }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $bytes = $utf8NoBom.GetBytes([string]$value)
  [System.IO.File]::WriteAllBytes($path, $bytes)
}

$repoRoot = Get-RepoRoot
$secretsPath = $SecretsDir
if (-not [System.IO.Path]::IsPathRooted($secretsPath)) { $secretsPath = Join-Path $repoRoot $SecretsDir }
$envPath = $EnvFile
if (-not [System.IO.Path]::IsPathRooted($envPath)) { $envPath = Join-Path $repoRoot $EnvFile }

if (-not (Test-Path -LiteralPath $secretsPath)) {
  throw "Secrets dir not found: $secretsPath"
}
if (-not (Test-Path -LiteralPath $envPath)) {
  throw "Missing secrets env file: $envPath (copy secrets/.env.example -> secrets/.env and fill values)"
}

$m = Read-DotEnv $envPath
$ccApiKey = $m["CC_API_KEY"]
$githubToken = $m["GITHUB_TOKEN"]

Write-SecretFile (Join-Path $secretsPath "cc_api_key") $ccApiKey
Write-SecretFile (Join-Path $secretsPath "github_token") $githubToken

Write-Host "[OK] Secrets written to $secretsPath"
Write-Host "     - cc_api_key"
Write-Host "     - github_token"
