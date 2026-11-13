param([string]$OutputDirectory = '.trae/tmp/pattern-wav')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOutput = [System.IO.Path]::GetFullPath((Join-Path $taskRoot $OutputDirectory))
if (-not $taskOutput.StartsWith($taskRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Output must stay inside this project.'
}
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskCourse = Get-Content -LiteralPath (Join-Path $taskRoot 'assets/courses/course_beginner.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$taskSynth = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $taskVoice = $taskSynth.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -eq 'en-US' } | Select-Object -First 1
    if ($null -eq $taskVoice) { throw 'No US English speech voice is installed.' }
    $taskSynth.SelectVoice($taskVoice.VoiceInfo.Name)
    $taskSynth.Rate = -1
    $taskFormat = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
    $taskCount = 0
    $taskManifest = @{}
    foreach ($taskUnit in $taskCourse.units) {
        foreach ($taskLesson in $taskUnit.lessons) {
            if ($null -eq $taskLesson.patternTraining) { continue }
            foreach ($taskPhase in @('examples','substitution','recall','transfer','review')) {
                foreach ($taskExercise in $taskLesson.patternTraining.$taskPhase) {
                    if ($taskExercise.id -notmatch '^mp_[A-Za-z0-9_]+$') { throw 'Unsafe audio id.' }
                    $taskPath = Join-Path $taskOutput ($taskExercise.id + '.wav')
                    $taskSynth.SetOutputToWaveFile($taskPath, $taskFormat)
                    $taskSynth.Speak($taskExercise.sentence)
                    $taskSynth.SetOutputToNull()
                    $taskSha = [System.Security.Cryptography.SHA256]::Create()
                    try {
                        $taskDigest = $taskSha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($taskExercise.sentence.Trim()))
                        $taskManifest[$taskExercise.id] = @{ sentenceSha256 = ([System.BitConverter]::ToString($taskDigest)).Replace('-','').ToLowerInvariant(); voice = $taskVoice.VoiceInfo.Name }
                    } finally { $taskSha.Dispose() }
                    $taskCount++
                }
            }
        }
    }
    $taskManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $taskOutput 'manifest.json') -Encoding UTF8
    Write-Output "Generated $taskCount WAV recordings with $($taskVoice.VoiceInfo.Name)."
} finally { $taskSynth.Dispose() }
