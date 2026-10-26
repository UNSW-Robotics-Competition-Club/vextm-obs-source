$ErrorActionPreference = 'Stop'
$root   = Split-Path $PSScriptRoot
$src    = $root
$obsTag = '33.0.0'
$obs    = "$PSScriptRoot\obs-$obsTag"
$out    = $PSScriptRoot
$obsBin = 'C:\Program Files\obs-studio\bin\64bit'
$vcvars = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
$clang  = (Get-Command clang-cl -ErrorAction SilentlyContinue).Source
if (-not $clang) { $clang = "$env:USERPROFILE\scoop\apps\llvm\current\bin\clang-cl.exe" }

# Fetch just the libobs and w32-pthreads headers for the target OBS release
if (-not (Test-Path "$obs\libobs")) {
    # git writes progress to stderr, which Stop would treat as fatal
    $ErrorActionPreference = 'Continue'
    git clone --depth 1 --branch $obsTag --filter=blob:none --sparse `
        https://github.com/obsproject/obs-studio.git $obs
    git -C $obs sparse-checkout set libobs deps/w32-pthreads
    if ($LASTEXITCODE) { throw "fetching OBS headers failed" }
    $ErrorActionPreference = 'Stop'
}

# Import env from vcvars64
cmd /c "`"$vcvars`" >nul 2>nul && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') { Set-Item "env:$($Matches[1])" $Matches[2] }
}

# Build import libs straight from the installed OBS 33 DLLs so we link
# against exactly what OBS exports
foreach ($name in 'obs', 'w32-pthreads') {
    $exports = & dumpbin /exports "$obsBin\$name.dll" |
        Where-Object { $_ -match '^\s+\d+\s+[0-9A-F]+\s+[0-9A-F]{8}\s+(\S+)' } |
        ForEach-Object { $Matches[1] }
    @("LIBRARY $name", 'EXPORTS') + $exports | Set-Content "$out\$name.def" -Encoding ascii
    & lib /nologo /machine:x64 /def:"$out\$name.def" /out:"$out\$name.lib" | Out-Null
}

# colorbars.c inlines an 8 MB GIMP pixel dump (offline.c) that exhausts
# MSVC's compiler heap, so build that one object with clang-cl instead
& $clang /nologo /c /O2 /MD `
    "$src\colorbars.c" /Fo"$out\colorbars.obj" | Write-Host
if ($LASTEXITCODE) { throw "colorbars build failed" }

$srcs = 'platform-windows.c', 'vextm-source.c', 'vextm-thread.c' | ForEach-Object { "$src\$_" }
& cl /nologo /O2 /MD /W3 /std:c11 /experimental:c11atomics `
    /D_CRT_SECURE_NO_WARNINGS /DHAVE_STRUCT_TIMESPEC `
    /I"$out\inc" /I"$obs\libobs" /I"$obs\deps\w32-pthreads" `
    $srcs "$out\colorbars.obj" /Fo"$out\\" /LD /Fe"$out\vextm-source.dll" `
    /link "$out\obs.lib" "$out\w32-pthreads.lib" kernel32.lib user32.lib | Write-Host
if ($LASTEXITCODE) { throw "build failed" }

# Package the installer if NSIS is available
$makensis = (Get-Command makensis -ErrorAction SilentlyContinue).Source
if (-not $makensis) { $makensis = "$env:USERPROFILE\scoop\apps\nsis\current\Bin\makensis.exe" }
if (Test-Path $makensis) {
    Push-Location $root
    & $makensis /V2 "/DDLL_PATH=$out\vextm-source.dll" setup.nsi | Write-Host
    Pop-Location
    if ($LASTEXITCODE) { throw "installer build failed" }
} else {
    Write-Host "makensis not found, skipping installer"
}
