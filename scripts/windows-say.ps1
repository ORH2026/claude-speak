# Windows TTS backend for claude-speak. Reads UTF-8 text on stdin and speaks it.
#
# Engines (chosen by ~/.claude/claude-speak/engine, see /speak-engine):
#   system (default) - built-in System.Speech (SAPI). Offline, no network.
#   fish             - Fish Audio cloud TTS (api.fish.audio), key from the
#                      FISH_API_KEY user environment variable. Falls back to
#                      the system voice on any failure. One request per reply,
#                      no retries, and a daily character cap.
#
# Text is never written to disk; Fish audio is played from memory.
#
#   -Wpm   words per minute (same scale as macOS say / espeak); 0 = default
#   -Voice installed SAPI voice name; '' = default (system engine only)
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

function Read-Setting([string]$name, [string]$default) {
    $p = Join-Path $stateDir $name
    if (Test-Path $p) {
        $v = (Get-Content $p -Raw -ErrorAction SilentlyContinue)
        if ($v) { return $v.Trim() }
    }
    return $default
}

function Speak-System([string]$t) {
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
    $synth.Speak($t)
}

# Door codes never go to an outside service: when the text mentions a code or
# pin, every run of 3-8 digits is replaced before it is sent.
function Hide-Codes([string]$t) {
    if ($t -match '(?i)\b(code|codes|pin|passcode)\b') {
        return [regex]::Replace($t, '\d{3,8}', 'number hidden')
    }
    return $t
}

# Streamed WAV arrives with placeholder RIFF/data sizes; SoundPlayer needs real ones.
function Fix-WavHeader([byte[]]$b) {
    [Array]::Copy([BitConverter]::GetBytes([uint32]($b.Length - 8)), 0, $b, 4, 4)
    $i = 12
    while ($i -lt $b.Length - 8) {
        $id = [Text.Encoding]::ASCII.GetString($b, $i, 4)
        $sz = [BitConverter]::ToUInt32($b, $i + 4)
        if ($id -eq 'data') {
            [Array]::Copy([BitConverter]::GetBytes([uint32]($b.Length - $i - 8)), 0, $b, $i + 4, 4)
            return $true
        }
        $i += 8 + $sz
    }
    return $false
}

# Returns $true if Fish spoke the text, $false to fall back to the system voice.
function Speak-Fish([string]$t) {
    $key = [Environment]::GetEnvironmentVariable('FISH_API_KEY', 'User')
    if (-not $key) { $key = $env:FISH_API_KEY }
    if (-not $key) { return $false }

    # Daily cap on characters sent, counted before the request.
    $cap = 0
    if (-not [int]::TryParse((Read-Setting 'fish-daily-cap' '20000'), [ref]$cap)) { $cap = 20000 }
    $usageFile = Join-Path $stateDir ('fish-usage-' + (Get-Date -Format 'yyyyMMdd') + '.txt')
    $used = 0
    if (Test-Path $usageFile) { [void][int]::TryParse((Get-Content $usageFile -Raw).Trim(), [ref]$used) }
    if ($used + $t.Length -gt $cap) { return $false }
    Set-Content -Path $usageFile -Value ($used + $t.Length) -Encoding Ascii
    Get-ChildItem $stateDir -Filter 'fish-usage-*.txt' | Where-Object { $_.FullName -ne $usageFile } |
        Remove-Item -ErrorAction SilentlyContinue

    $body = @{ text = $t; format = 'wav'; latency = 'balanced'; normalize = $true }
    $ref = Read-Setting 'fish-voice' ''
    if ($ref) { $body.reference_id = $ref }
    if ($Wpm -gt 0) {
        $speed = [math]::Round($Wpm / 180.0, 2)
        if ($speed -lt 0.5) { $speed = 0.5 }
        if ($speed -gt 2.0) { $speed = 2.0 }
        $body.prosody = @{ speed = $speed }
    }
    $model = Read-Setting 'fish-model' 's2.1-pro-free'
    $headers = @{ Authorization = "Bearer $key"; model = $model }
    try {
        $json = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress -Depth 4))
        $r = Invoke-WebRequest -Uri 'https://api.fish.audio/v1/tts' -Method Post -Headers $headers `
            -ContentType 'application/json; charset=utf-8' -Body $json -TimeoutSec 25 -UseBasicParsing
        $bytes = $r.Content
        if (-not ($bytes -is [byte[]]) -or $bytes.Length -lt 64) { return $false }
        if (-not (Fix-WavHeader $bytes)) { return $false }
        $player = New-Object System.Media.SoundPlayer(New-Object System.IO.MemoryStream(, $bytes))
        $player.PlaySync()
        return $true
    } catch {
        return $false
    }
}

try {
    $spoken = $false
    $engine = Read-Setting 'engine' 'system'
    if ($engine -eq 'fish') {
        $spoken = Speak-Fish (Hide-Codes $text)
    }
    # Record which engine spoke (never the text), for /speak-engine status.
    $note = if ($spoken) { 'fish' } elseif ($engine -eq 'fish') { 'system (fish fallback)' } else { 'system' }
    Set-Content -Path (Join-Path $stateDir 'last-engine.txt') -Value ((Get-Date -Format s) + ' ' + $note) -Encoding Ascii
    if (-not $spoken) { Speak-System $text }
}
finally {
    if ((Test-Path $pidFile) -and ((Get-Content $pidFile -ErrorAction SilentlyContinue) -eq "$PID")) {
        Remove-Item $pidFile -ErrorAction SilentlyContinue
    }
}
