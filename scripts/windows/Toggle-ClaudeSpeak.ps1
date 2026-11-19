# One-click on/off for claude-speak on Windows, for a desktop or taskbar
# shortcut. Flips the same flag file /toggle-speak uses, stops any speech
# that is playing, and says "Claude voice on" or "Claude voice off".
param([ValidateSet('toggle', 'on', 'off')][string]$Action = 'toggle')

$stateDir = Join-Path $env:USERPROFILE '.claude\claude-speak'
$flag = Join-Path $stateDir 'enabled'
$pidFile = Join-Path $stateDir 'speaker.pid'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

if ($Action -eq 'toggle') {
    if (Test-Path $flag) { $Action = 'off' } else { $Action = 'on' }
}

# Stop current speech (only if the recorded pid is still a powershell process).
if (Test-Path $pidFile) {
    $speakerPid = (Get-Content $pidFile -ErrorAction SilentlyContinue) -replace '\D', ''
    Remove-Item $pidFile -ErrorAction SilentlyContinue
    if ($speakerPid) {
        Get-Process -Id ([int]$speakerPid) -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -eq 'powershell' } | Stop-Process -Force
    }
}

if ($Action -eq 'on') {
    New-Item -ItemType File -Force -Path $flag | Out-Null
} else {
    Remove-Item $flag -ErrorAction SilentlyContinue
}

Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.Speak("Claude voice $Action")
