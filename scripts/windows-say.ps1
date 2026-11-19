# Windows TTS backend for claude-speak. Reads UTF-8 text on stdin and speaks
# it with the built-in System.Speech (SAPI) voice. Offline, no downloads, no
# network. Text is never written to disk.
#
#   -Wpm   words per minute (same scale as macOS say / espeak); 0 = default
#   -Voice installed voice name (see tts-backend.sh list-voices); '' = default
#
# Writes its own process id to ~/.claude/claude-speak/speaker.pid so that a
# new reply, /speak-stop or /toggle-speak off can cut the current speech.
param(
    [int]$Wpm = 0,
    [string]$Voice = ''
)

[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$text = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($text)) { exit 0 }

$stateDir = Join-Path $env:USERPROFILE '.claude\claude-speak'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$pidFile = Join-Path $stateDir 'speaker.pid'
Set-Content -Path $pidFile -Value $PID -Encoding Ascii

try {
    Add-Type -AssemblyName System.Speech
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    if ($Voice) {
        try { $synth.SelectVoice($Voice) } catch { }
    }
    if ($Wpm -gt 0) {
        # SAPI rate is -10..10 with 0 near 180 wpm; about 18 wpm per step.
        $rate = [int][math]::Round(($Wpm - 180) / 18)
        if ($rate -lt -10) { $rate = -10 }
        if ($rate -gt 10) { $rate = 10 }
        $synth.Rate = $rate
    }
    $synth.Speak($text)
}
finally {
    if ((Test-Path $pidFile) -and ((Get-Content $pidFile -ErrorAction SilentlyContinue) -eq "$PID")) {
        Remove-Item $pidFile -ErrorAction SilentlyContinue
    }
}
