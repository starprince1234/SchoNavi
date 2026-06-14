param(
    [switch]$SkipVector,
    [string]$Project = "schonavi",
    [string]$Config = "dev_personal"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$agentRoot = Join-Path $repoRoot "web/backend_agent"
$dataDir = Join-Path $agentRoot "data"
$artifactDir = Join-Path $repoRoot "artifacts"
$artifactPath = Join-Path $artifactDir "backend_agent_data.tar.gz"

if (-not (Get-Command doppler -ErrorAction SilentlyContinue)) {
    throw "Doppler CLI is required locally."
}

$python = Join-Path $agentRoot ".venv/Scripts/python.exe"
if (-not (Test-Path $python)) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCommand) {
        throw "Python is required locally."
    }
    $python = $pythonCommand.Source
}

if (-not (Test-Path (Join-Path $agentRoot "raw_data"))) {
    throw "Missing raw_data directory: $agentRoot/raw_data"
}

$rawDbs = Get-ChildItem -LiteralPath (Join-Path $agentRoot "raw_data") -Filter "*.db" -File
if ($rawDbs.Count -eq 0) {
    throw "No raw SQLite DB files found in $agentRoot/raw_data"
}

New-Item -ItemType Directory -Force -Path $dataDir, $artifactDir | Out-Null

$env:DATABASE_URL = "sqlite:///data/app.db"
$env:CHROMA_PATH = "data/chroma"
$env:SOURCE_DB_DIR = "raw_data"
$env:SOURCE_DB_GLOB = "*.db"
$env:DATA_DIR = "data"
$env:PIPELINE_REPORT_DIR = "data/pipeline_reports"

Push-Location $agentRoot
try {
    $args = @(
        "run", "--project", $Project, "--config", $Config,
        "--preserve-env=DATABASE_URL,CHROMA_PATH,SOURCE_DB_DIR,SOURCE_DB_GLOB,DATA_DIR,PIPELINE_REPORT_DIR",
        "--",
        $python, "-m", "app.jobs.rebuild_all"
    )
    if ($SkipVector) {
        $args += "--skip-vector"
    }
    & doppler @args
    if ($LASTEXITCODE -ne 0) {
        throw "Local backend agent data build failed."
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path (Join-Path $dataDir "app.db"))) {
    throw "Build finished but data/app.db was not created."
}

if (-not $SkipVector -and -not (Test-Path (Join-Path $dataDir "chroma"))) {
    throw "Build finished but data/chroma was not created."
}

if (Test-Path $artifactPath) {
    Remove-Item -LiteralPath $artifactPath -Force
}

tar -czf $artifactPath -C $agentRoot data
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create artifact: $artifactPath"
}

$artifact = Get-Item -LiteralPath $artifactPath
Write-Host "Built backend agent data artifact: $($artifact.FullName) ($([Math]::Round($artifact.Length / 1MB, 2)) MB)"
