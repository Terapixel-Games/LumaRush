param(
	[ValidateSet("all", "rush_combo_push", "rush_powerup_recovery")]
	[string]$Scenario = "all",
	[string]$GodotBin = "godot",
	[int]$Frames = 1200,
	[string]$Persona = "manic",
	[string]$ReportsDir = "reports/perf"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ResolvedReportsDir = Join-Path $ProjectRoot $ReportsDir
New-Item -ItemType Directory -Force -Path $ResolvedReportsDir | Out-Null

function Resolve-GodotCommand([string]$RequestedBin) {
	$command = Get-Command $RequestedBin -ErrorAction Stop
	$resolved = $command.Source
	if ([System.IO.Path]::GetFileName($resolved).ToLowerInvariant() -eq "godot.exe") {
		$consoleBin = Join-Path (Split-Path $resolved -Parent) "godot_console.exe"
		if (Test-Path $consoleBin) {
			return $consoleBin
		}
	}
	return $resolved
}

function Invoke-PerfScenario([string]$ScenarioId, [int]$ScenarioFrames, [string]$ScenarioPersona) {
	$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
	$metricsPath = Join-Path $ResolvedReportsDir "lumarush-$ScenarioId-$timestamp.json"
	Write-Host "Running perf scenario $ScenarioId..."
	$previousErrorActionPreference = $ErrorActionPreference
	$nativePreferenceWasPresent = $null -ne (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue)
	$previousNativePreference = $false
	if ($nativePreferenceWasPresent) {
		$previousNativePreference = $PSNativeCommandUseErrorActionPreference
	}
	try {
		$ErrorActionPreference = "Continue"
		if ($nativePreferenceWasPresent) {
			$PSNativeCommandUseErrorActionPreference = $false
		}
		$output = @(& $ResolvedGodotBin `
			--headless `
			--path $ProjectRoot `
			--script "res://tools/capture/ScenarioDriver.gd" `
			-- `
			--mode=perf `
			--strictness=hybrid `
			--persona=$ScenarioPersona `
			--scenario_id=$ScenarioId `
			--frames=$ScenarioFrames `
			--seed=6601 `
			--metrics_json=$metricsPath 2>&1 | ForEach-Object { $_.ToString() })
		$exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
	}
	finally {
		$ErrorActionPreference = $previousErrorActionPreference
		if ($nativePreferenceWasPresent) {
			$PSNativeCommandUseErrorActionPreference = $previousNativePreference
		}
	}
	if ($output) {
		Write-Host ($output | Out-String).Trim()
	}
	if ($exitCode -ne 0) {
		throw "Perf scenario failed: $ScenarioId"
	}
	$metrics = Get-Content -LiteralPath $metricsPath -Raw | ConvertFrom-Json
	Write-Host (
		"metrics={0} max={1:n2}ms p95={2:n2}ms p99={3:n2}ms hitches33={4} hitches50={5}" -f
		$metricsPath,
		[double]$metrics.perf_max_frame_ms,
		[double]$metrics.perf_p95_frame_ms,
		[double]$metrics.perf_p99_frame_ms,
		[int]$metrics.perf_hitch_count_33ms,
		[int]$metrics.perf_hitch_count_50ms
	)
}

$ResolvedGodotBin = Resolve-GodotCommand $GodotBin
$scenarios = if ($Scenario -eq "all") {
	@("rush_combo_push", "rush_powerup_recovery")
}
else {
	@($Scenario)
}

foreach ($scenarioId in $scenarios) {
	Invoke-PerfScenario $scenarioId $Frames $Persona
}

Write-Host "Perf scenarios completed."
