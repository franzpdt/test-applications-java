param(
    [string]$BaseUrl = 'http://localhost:5000'
)

$StressDuration = 40        # seconds each stress type runs
$CycleSeconds   = 7 * 60    # 420s total cycle
$GapSeconds     = 60        # 1 min gap between stress calls

Write-Host "==> Calling project-api at $BaseUrl"
Write-Host "    Cycle: ${CycleSeconds}s | Stress duration: ${StressDuration}s | Gap between stress calls: ${GapSeconds}s"
Write-Host "    Ctrl+C to stop"

while ($true) {
    $CycleStart = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    Write-Host ""
    Write-Host "--- $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') ---"

    Write-Host "[GET] /api/projects"
    try {
        $resp = Invoke-WebRequest -Uri "$BaseUrl/api/projects" -UseBasicParsing -ErrorAction Stop
        Write-Host ($resp.Content.Substring(0, [Math]::Min(200, $resp.Content.Length)))
    } catch { Write-Host "Request failed: $_" }
    Write-Host ""

    Write-Host "[GET] /api/projects/1"
    try {
        $resp = Invoke-WebRequest -Uri "$BaseUrl/api/projects/1" -UseBasicParsing -ErrorAction Stop
        Write-Host $resp.Content
    } catch { Write-Host "Request failed: $_" }
    Write-Host ""

    Write-Host "[GET] /api/stress/memory?duration=$StressDuration"
    try {
        $resp = Invoke-WebRequest -Uri "$BaseUrl/api/stress/memory?duration=$StressDuration" -UseBasicParsing -ErrorAction Stop
        Write-Host $resp.Content
    } catch { Write-Host "Request failed: $_" }
    Write-Host ""

    Start-Sleep -Seconds $GapSeconds

    Write-Host "[GET] /api/stress/threads?duration=$StressDuration"
    try {
        $resp = Invoke-WebRequest -Uri "$BaseUrl/api/stress/threads?duration=$StressDuration" -UseBasicParsing -ErrorAction Stop
        Write-Host $resp.Content
    } catch { Write-Host "Request failed: $_" }
    Write-Host ""

    Start-Sleep -Seconds $GapSeconds

    Write-Host "[GET] /api/stress/cpu?duration=$StressDuration"
    try {
        $resp = Invoke-WebRequest -Uri "$BaseUrl/api/stress/cpu?duration=$StressDuration" -UseBasicParsing -ErrorAction Stop
        Write-Host $resp.Content
    } catch { Write-Host "Request failed: $_" }
    Write-Host ""

    $Elapsed   = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $CycleStart
    $Remaining = $CycleSeconds - $Elapsed
    if ($Remaining -gt 0) {
        Write-Host "--- next cycle in ${Remaining}s ---"
        Start-Sleep -Seconds $Remaining
    }
}
