$sampleRate = 22050
$bitsPerSample = 16
$numChannels = 1
$blockAlign = [int]($numChannels * $bitsPerSample / 8)
$byteRate = $sampleRate * $blockAlign
$outDir = $PSScriptRoot

function Write-WavFile {
    param(
        [string]$Path,
        [int16[]]$Samples
    )
    $dataSize = $Samples.Length * 2
    $fileSize = 44 + $dataSize

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)

    # RIFF chunk
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $bw.Write([uint32]($fileSize - 8))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))

    # fmt chunk
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $bw.Write([uint32]16)
    $bw.Write([uint16]1)               # PCM
    $bw.Write([uint16]$numChannels)
    $bw.Write([uint32]$sampleRate)
    $bw.Write([uint32]$byteRate)
    $bw.Write([uint16]$blockAlign)
    $bw.Write([uint16]$bitsPerSample)

    # data chunk
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $bw.Write([uint32]$dataSize)
    foreach ($s in $Samples) {
        $bw.Write([int16]$s)
    }

    $bw.Flush()
    [System.IO.File]::WriteAllBytes($Path, $ms.ToArray())
    $bw.Close()
}

function New-Tone {
    param(
        [double]$Freq,
        [double]$DurationSec,
        [bool]$FadeOut
    )
    $count = [int]($sampleRate * $DurationSec)
    $samples = New-Object int16[] $count
    for ($i = 0; $i -lt $count; $i++) {
        $amp = 0.5 * 32767
        if ($FadeOut) {
            $amp = $amp * (1.0 - ($i / $count))
        }
        $samples[$i] = [int16]($amp * [Math]::Sin(2.0 * [Math]::PI * $Freq * $i / $sampleRate))
    }
    return $samples
}

# correct.wav: 660Hz 0.2s + 880Hz 0.3s (fade out on second note)
$correct = (New-Tone -Freq 660 -DurationSec 0.2 -FadeOut $false) +
           (New-Tone -Freq 880 -DurationSec 0.3 -FadeOut $true)
Write-WavFile -Path (Join-Path $outDir "correct.wav") -Samples $correct

# wrong.wav: 220Hz 0.15s + 165Hz 0.25s (fade out on second note)
$wrong = (New-Tone -Freq 220 -DurationSec 0.15 -FadeOut $false) +
         (New-Tone -Freq 165 -DurationSec 0.25 -FadeOut $true)
Write-WavFile -Path (Join-Path $outDir "wrong.wav") -Samples $wrong

# celebrate.wav: 上行琶音 C5 E5 G5 C6 各 0.15s + C6 0.4s 渐弱收尾
$celebrate = (New-Tone -Freq 523 -DurationSec 0.15 -FadeOut $false) +
             (New-Tone -Freq 659 -DurationSec 0.15 -FadeOut $false) +
             (New-Tone -Freq 784 -DurationSec 0.15 -FadeOut $false) +
             (New-Tone -Freq 1047 -DurationSec 0.45 -FadeOut $true)
Write-WavFile -Path (Join-Path $outDir "celebrate.wav") -Samples $celebrate

Write-Host "Generation done."
