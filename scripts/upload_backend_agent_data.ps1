param(
    [string]$HostName,
    [string]$User = "root",
    [int]$Port = 22,
    [string]$Password,
    [string]$RemoteRoot = "/opt/schonavi",
    [string]$ArtifactPath
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (-not $ArtifactPath) {
    $ArtifactPath = Join-Path $repoRoot "artifacts/backend_agent_data.tar.gz"
}
$ArtifactPath = (Resolve-Path $ArtifactPath).Path

if (-not $HostName) {
    $HostName = & doppler secrets get SERVER_HOST --project schonavi --config prd --plain --raw
}
if (-not $User) {
    $User = & doppler secrets get SERVER_USER --project schonavi --config prd --plain --raw
}
if (-not $Password) {
    $Password = & doppler secrets get SERVER_PASSWORD --project schonavi --config prd --plain --raw
}
if (-not $Port) {
    $Port = [int](& doppler secrets get SERVER_SSH_PORT --project schonavi --config prd --plain --raw)
}

$plink = "D:\PuTTY\plink.exe"
$pscp = "D:\PuTTY\pscp.exe"

if (-not (Test-Path $plink) -or -not (Test-Path $pscp)) {
    throw "Expected PuTTY tools at D:\PuTTY\plink.exe and D:\PuTTY\pscp.exe"
}

Write-Host "Uploading $ArtifactPath to ${User}@${HostName}:$RemoteRoot/backend_agent_data.tar.gz"
& $pscp -P $Port -pw $Password $ArtifactPath "${User}@${HostName}:$RemoteRoot/backend_agent_data.tar.gz"
if ($LASTEXITCODE -ne 0) {
    throw "Upload failed."
}

$remoteScript = @'
set -euo pipefail
cd '__REMOTE_ROOT__'
mkdir -p backend_agent
rm -rf backend_agent/data.next
mkdir -p backend_agent/data.next
tar -xzf backend_agent_data.tar.gz -C backend_agent/data.next
if [ ! -f backend_agent/data.next/data/app.db ]; then
  echo 'artifact missing data/app.db' >&2
  exit 1
fi
container_id=""
container_id="$(docker ps -a --filter 'label=com.docker.compose.project=schonavi' --filter 'label=com.docker.compose.service=backend' --format '{{.ID}}' | head -n 1)"
if [ -z "$container_id" ]; then
  container_id="$(docker ps -a --filter 'name=schonavi-backend' --format '{{.ID}}' | head -n 1)"
fi
if [ -z "$container_id" ]; then
  echo 'backend container not found; deploy backend first' >&2
  exit 1
fi
docker stop "$container_id" >/dev/null || true
if [ -d backend_agent/data ]; then
  rm -rf backend_agent/data.prev
  mv backend_agent/data backend_agent/data.prev
fi
mv backend_agent/data.next/data backend_agent/data
rm -rf backend_agent/data.next
docker start "$container_id" >/dev/null
echo 'Backend agent data installed and backend restarted.'
'@
$remoteScript = $remoteScript.Replace("__REMOTE_ROOT__", $RemoteRoot)

$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript))
& $plink -ssh "$User@$HostName" -P $Port -pw $Password -batch "printf '%s' '$encoded' | base64 -d | bash"
if ($LASTEXITCODE -ne 0) {
    throw "Remote install failed."
}
