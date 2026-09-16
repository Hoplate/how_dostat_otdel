$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GamePath = Join-Path $ProjectRoot 'game'
$Version = '4.5.2'
$Tools = Join-Path $ProjectRoot '.tools\godot'
$Engine = Join-Path $Tools "Godot_v$Version-stable_win64.exe"
try {
    if ($env:GODOT_BIN) {
        $Engine = $env:GODOT_BIN
        if (-not (Test-Path -LiteralPath $Engine)) {
            throw "GODOT_BIN does not exist: $Engine"
        }
    } elseif (-not (Test-Path -LiteralPath $Engine)) {
        Write-Host "Downloading the official portable Godot $Version engine..."
        Write-Host 'The engine stays inside this project. No administrator rights are required.'
        New-Item -ItemType Directory -Force -Path $Tools | Out-Null
        $Zip = Join-Path $Tools 'engine.zip'
        $Url = "https://github.com/godotengine/godot-builds/releases/download/$Version-stable/Godot_v$Version-stable_win64.exe.zip"
        Invoke-WebRequest -Uri $Url -OutFile $Zip -UseBasicParsing
        Expand-Archive -LiteralPath $Zip -DestinationPath $Tools -Force
        Remove-Item -LiteralPath $Zip
        if (-not (Test-Path -LiteralPath $Engine)) {
            throw 'The downloaded archive did not contain the expected engine executable.'
        }
    }
    Write-Host 'Importing native game resources...'
    & $Engine --headless --path $GamePath --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw "Import failed (exit $LASTEXITCODE)." }
    Start-Process -FilePath $Engine -ArgumentList @('--path', ('"' + $GamePath + '"')) -WorkingDirectory $GamePath
} catch {
    Write-Error $_
    exit 1
}
