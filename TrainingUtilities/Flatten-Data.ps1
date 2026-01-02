# Base folders (relative to script location)
$trainingBase = Join-Path -Path $PSScriptRoot -ChildPath "data\manga_dataset"
$greysrc = Join-Path $trainingBase "grayscale"
$colorsrc = Join-Path $trainingBase "color"

# Destination dataset root and CycleGAN-style folders
$datasetRoot = Join-Path -Path $PSScriptRoot -ChildPath "data\training_dataset"
$trainA = Join-Path $datasetRoot "trainA"   # greyscale domain (training)
$trainB = Join-Path $datasetRoot "trainB"   # color domain (training)
$valA   = Join-Path $datasetRoot "valA"     # greyscale domain (validation)
$valB   = Join-Path $datasetRoot "valB"     # color domain (validation)

# Create destination folders if missing
New-Item -Path $trainA -ItemType Directory -Force | Out-Null
New-Item -Path $trainB -ItemType Directory -Force | Out-Null
New-Item -Path $valA   -ItemType Directory -Force | Out-Null
New-Item -Path $valB   -ItemType Directory -Force | Out-Null

# Chapter range to process and validation size per chapter
$start = 1
$end = 10
$valPerChapter = 3   # number of images per chapter to reserve for validation

# Supported extensions (case-insensitive)
$exts = @('*.jpg','*.jpeg','*.png')

for ($i = $start; $i -le $end; $i++) {
    $plain = "Chapter $i"
    $padded = "Chapter $($i.ToString('D2'))"
    $prefix = "C$($i.ToString('D2'))_"

    function Process-Chapter {
        param(
            [string]$srcRoot,
            [string]$chapterPlain,
            [string]$chapterPadded,
            [string]$destTrain,
            [string]$destVal,
            [string]$filePrefix
        )

        # find the chapter folder (try plain then padded)
        $srcFolder = $null
        foreach ($chap in @($chapterPlain, $chapterPadded)) {
            $candidate = Join-Path $srcRoot $chap
            if (Test-Path $candidate) { $srcFolder = $candidate; break }
        }

        if (-not $srcFolder) {
            Write-Host "Warning: No folder found for" $chapterPlain "or" $chapterPadded "under" $srcRoot -ForegroundColor Yellow
            return
        }

        # gather files sorted by name
        Write-Host "Processing chapter folder: " $srcFolder
        $files = Get-ChildItem -Recurse -Path $srcFolder -File -Include $exts -ErrorAction SilentlyContinue | Sort-Object Name
        if (-not $files) {
            Write-Host "Warning: No image files found in" $srcFolder -ForegroundColor Yellow
            return
        }

        # split into validation and training sets
        $valFiles = $files | Select-Object -First $valPerChapter
        $trainFiles = $files | Where-Object { $valFiles -notcontains $_ }

        # copy validation files
        foreach ($f in $valFiles) {
            $newName = $filePrefix + $f.Name
            $destPath = Join-Path $destVal $newName
            Copy-Item -Path $f.FullName -Destination $destPath -Force #-WhatIf
        }

        # copy training files
        foreach ($f in $trainFiles) {
            $newName = $filePrefix + $f.Name
            $destPath = Join-Path $destTrain $newName
            Copy-Item -Path $f.FullName -Destination $destPath -Force #-WhatIf
        }

        Write-Host "Processed" $srcFolder ": val" ($valFiles.Count) "train" ($trainFiles.Count)
    }

    # process greyscale -> valA/trainA
    Process-Chapter -srcRoot $greysrc -chapterPlain $plain -chapterPadded $padded -destTrain $trainA -destVal $valA -filePrefix $prefix

    # process color -> valB/trainB
    Process-Chapter -srcRoot $colorsrc -chapterPlain $plain -chapterPadded $padded -destTrain $trainB -destVal $valB -filePrefix $prefix
}

Write-Host "Done. Training folders:" $trainA $trainB
Write-Host "Validation folders:" $valA $valB -ForegroundColor Green