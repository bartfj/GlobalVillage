param([string]$OutputDirectory = '.trae/tmp/mother-pattern-wav')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$taskRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$taskOutput = [System.IO.Path]::GetFullPath((Join-Path $taskRoot $OutputDirectory))
if (-not $taskOutput.StartsWith($taskRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Output must stay inside this project.'
}
$taskCourse = Get-Content -LiteralPath (Join-Path $taskRoot 'assets/courses/course_mother_pattern.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($taskCourse.id -ne 'motherPattern') { throw 'Wrong audio course.' }
$taskItems = [ordered]@{}
foreach ($taskUnit in $taskCourse.units) {
    foreach ($taskLesson in $taskUnit.lessons) {
        foreach ($taskItem in @($taskLesson.patternLesson.dialogue) + @($taskLesson.patternLesson.vocabulary)) {
            if ($taskItem.audioId -notmatch '^mp_[a-z0-9_]+$' -or [string]::IsNullOrWhiteSpace($taskItem.text) -or $taskItems.Contains($taskItem.audioId)) { throw 'Invalid or duplicate audio entry.' }
            $taskItems[$taskItem.audioId] = $taskItem.text.Trim()
        }
        foreach ($taskExercise in @($taskLesson.exercises) + @($taskLesson.patternLesson.examples) + @($taskLesson.patternLesson.review)) {
            $taskId = if ($taskExercise.audioId) { $taskExercise.audioId } else { $taskExercise.id }
            if ($taskId -notmatch '^mp_[a-z0-9_]+$' -or [string]::IsNullOrWhiteSpace($taskExercise.sentence) -or $taskItems.Contains($taskId)) { throw 'Invalid or duplicate audio entry.' }
            $taskItems[$taskId] = $taskExercise.sentence.Trim()
        }
    }
}
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskSynth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$taskManifest = @{}
$taskSources = @{}
try {
    $taskVoice = $taskSynth.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -eq 'en-US' } | Select-Object -First 1
    if ($null -eq $taskVoice) { throw 'No US English voice installed.' }
    $taskSynth.SelectVoice($taskVoice.VoiceInfo.Name)
    $taskSynth.Rate = -1
    $taskFormat = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
    foreach ($taskEntry in $taskItems.GetEnumerator()) {
        $taskId = $taskEntry.Key
        $taskText = $taskEntry.Value
        $taskFile = Join-Path $taskOutput ($taskId + '.wav')
        if ($taskSources.ContainsKey($taskText)) {
            Copy-Item -LiteralPath $taskSources[$taskText] -Destination $taskFile
        } else {
            $taskSynth.SetOutputToWaveFile($taskFile, $taskFormat)
            $taskSynth.Speak($taskText)
            $taskSynth.SetOutputToNull()
            $taskSources[$taskText] = $taskFile
        }
        $taskSha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $taskDigest = $taskSha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($taskText))
            $taskManifest[$taskId] = @{ sentenceSha256 = ([System.BitConverter]::ToString($taskDigest)).Replace('-','').ToLowerInvariant(); voice = $taskVoice.VoiceInfo.Name }
        } finally { $taskSha.Dispose() }
    }
    $taskManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $taskOutput 'manifest.json') -Encoding UTF8
    Write-Output "Generated $($taskItems.Count) WAV recordings, $($taskSources.Count) distinct texts, with $($taskVoice.VoiceInfo.Name)."
} finally { $taskSynth.Dispose() }
