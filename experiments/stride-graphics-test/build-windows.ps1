$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $root ".generated"
$name = "StrideGraphicsTest"
$project = Join-Path $out $name
$artifacts = Join-Path $out "artifacts"

New-Item -ItemType Directory -Force -Path $artifacts | Out-Null
if (Test-Path $project) { throw "Refusing to overwrite generated project at $project" }

dotnet new install Stride.Templates.Games.Starters@4.4.4
if ($LASTEXITCODE -ne 0) { throw "Cannot install official Stride starter template" }
dotnet new stride-fps -n $name -o $project --platforms android
if ($LASTEXITCODE -ne 0) { throw "Cannot generate Stride Android scene" }

# Upgrade the starter's older engine package references to 4.4.3.
Get-ChildItem -Path $project -Recurse -File |
  Where-Object { $_.Extension -in @(".csproj", ".props", ".targets") } |
  ForEach-Object {
    $old = [System.IO.File]::ReadAllText($_.FullName)
    $new = [regex]::Replace($old, '4\.4\.[012]', '4.4.3')
    if ($new -cne $old) {
      [System.IO.File]::WriteAllText($_.FullName, $new)
    }
  }

# Give the native Android diagnostic screen launcher ownership. Keep the
# Stride Activity available behind an explicit START 3D button so a Vulkan
# crash cannot prevent the user from reading the preflight screen.
$androidDirectory = Join-Path $project "$name.Android"
$originalActivity = Join-Path $androidDirectory "$($name)Activity.cs"
$androidActivitySource = Join-Path $root "payload/StrideGraphicsTestActivity.cs"
if (-not (Test-Path $originalActivity)) { throw "Upstream Android activity was not generated" }
Copy-Item -Path $androidActivitySource -Destination $originalActivity -Force
Copy-Item -Path (Join-Path $root "payload/MobileControlsOverlay.cs") -Destination (Join-Path $androidDirectory "MobileControlsOverlay.cs") -Force

# Add shared touch input to the game project so movement uses the original
# PlayerController physics, and camera orientation uses the original FpsCamera.
$gameDir = Join-Path $project "$name.Game"
Copy-Item -Path (Join-Path $root "payload/MobileTouchState.cs") -Destination (Join-Path $gameDir "Player/MobileTouchState.cs") -Force
$playerInputFile = Join-Path $gameDir "Player/PlayerInput.cs"
$playerSource = [System.IO.File]::ReadAllText($playerInputFile)
$patches = @(
  @('var moveDirection = Input.GetLeftThumbAny(DeadZone);', 'MobileTouchState.Read(out var touchMove, out var touchLook, out var touchFire, out var touchReload);' + "`n                " + 'var moveDirection = Input.GetLeftThumbAny(DeadZone);'),
  @('// Broadcast the movement vector as a world-space Vector3', 'moveDirection += touchMove;' + "`n                " + 'if (moveDirection.LengthSquared() > 1f) moveDirection.Normalize();' + "`n                " + '// Broadcast the movement vector as a world-space Vector3'),
  @('CameraDirectionEventKey.Broadcast(cameraDirection);', 'CameraDirectionEventKey.Broadcast(cameraDirection + touchLook);'),
  @('if (Input.PointerEvents.Any(x => x.EventType == PointerEventType.Pressed))', 'if (!MobileTouchState.Enabled && Input.PointerEvents.Any(x => x.EventType == PointerEventType.Pressed))'),
  @('ShootEventKey.Broadcast(didShoot);', 'ShootEventKey.Broadcast(didShoot || touchFire);'),
  @('ReloadEventKey.Broadcast(isReloading);', 'ReloadEventKey.Broadcast(isReloading || touchReload);')
)
foreach ($patch in $patches) {
  if (-not $playerSource.Contains($patch[0])) { throw "Stride PlayerInput template changed: $($patch[0])" }
  $playerSource = $playerSource.Replace($patch[0], $patch[1])
}
[System.IO.File]::WriteAllText($playerInputFile, $playerSource)
Write-Host "Mobile touchscreen movement, camera, fire, and reload wired to original player controller."

$diagnosticsSource = Join-Path $root "payload/GraphicsPreflightActivity.cs"
Copy-Item -Path $diagnosticsSource -Destination (Join-Path $androidDirectory "GraphicsPreflightActivity.cs") -Force

# Use a unique identifier so the diagnostic APK can coexist with the original
# signed Stride test even when transient GitHub runner signing keys differ.
$androidProject = Join-Path $androidDirectory "$name.Android.csproj"
$androidProjectContent = [System.IO.File]::ReadAllText($androidProject)
$androidProjectContent = $androidProjectContent.Replace(
  "<ApplicationId>StrideGraphicsTest</ApplicationId>",
  "<ApplicationId>com.neonfoundry.stride.graphicsdiagnostic.v3</ApplicationId>")
# Critical for sideloading a .NET Android Debug APK: fast deployment defaults
# to ON and places managed assemblies on the development machine instead
# of inside the APK. GitHub-created APKs must be self-contained.
$marker = "<AndroidApplicationIcon>@mipmap/appicon</AndroidApplicationIcon>"
if (-not $androidProjectContent.Contains($marker)) {
  throw "Cannot locate generated Android project properties"
}
$androidProjectContent = $androidProjectContent.Replace(
  $marker, "$marker`n    <EmbedAssembliesIntoApk>true</EmbedAssembliesIntoApk>`n    <AndroidEnableFastDeployment>false</AndroidEnableFastDeployment>")
[System.IO.File]::WriteAllText($androidProject, $androidProjectContent)
Write-Host "Fast Deployment disabled; managed assemblies will be embedded in APK."

# Lower the initial internal framebuffer resolution; this is a diagnostic
# build for a Mali mobile GPU, not an image-quality benchmark.
$settingsFile = Join-Path $project "Assets/GameSettings.sdgamesettings"
$settingsText = [System.IO.File]::ReadAllText($settingsFile)
$settingsText = $settingsText.Replace("DefaultBackBufferWidth: 1280", "DefaultBackBufferWidth: 960")
$settingsText = $settingsText.Replace("DefaultBackBufferHeight: 720", "DefaultBackBufferHeight: 540")
[System.IO.File]::WriteAllText($settingsFile, $settingsText)

# Save the generated starter before building for diagnosis if compilation fails.
Compress-Archive -Path $project -DestinationPath (Join-Path $artifacts "stride-source.zip") -Force

$projects = @(Get-ChildItem -Path $project -Recurse -Filter "*.Android.csproj" -File)
if ($projects.Count -ne 1) {
  Get-ChildItem -Path $project -Recurse -Filter "*.csproj" | Select-Object -ExpandProperty FullName
  throw "Expected one Android project; found $($projects.Count)"
}
Write-Host "Stage 1: Compile Release Android assembly without Stride asset processing"
dotnet build $projects[0].FullName -c Release -p:StrideCompilerSkipBuild=true -p:AndroidPackageFormat=apk -p:EmbedAssembliesIntoApk=true -p:AndroidUseAssemblyStore=true -p:RunAOTCompilation=false -p:PublishTrimmed=false --nologo
if ($LASTEXITCODE -ne 0) { throw "Stage 1 Android assembly compilation failed" }

$targetAssembly = Join-Path $project "Bin/Android/Release/$name.Android.dll"
Write-Host "Stage 1 Android assembly exists: $(Test-Path $targetAssembly)"
if (Test-Path $targetAssembly) {
  Get-Item $targetAssembly | Select-Object FullName, Length | Format-List
}

Write-Host "Stage 2: Compile full Stride assets and self-contained Release Android APK"
dotnet build $projects[0].FullName -c Release -p:AndroidPackageFormat=apk -p:EmbedAssembliesIntoApk=true -p:AndroidUseAssemblyStore=true -p:RunAOTCompilation=false -p:PublishTrimmed=false -p:StrideBuildEngineLogVerbose=true --nologo
if ($LASTEXITCODE -ne 0) { throw "Stage 2 Stride Android asset build failed; check above logs" }

Write-Host "Stage 3: Sign and verify standalone Release APK"
dotnet build $projects[0].FullName -c Release -t:SignAndroidPackage -p:AndroidPackageFormat=apk -p:EmbedAssembliesIntoApk=true -p:AndroidUseAssemblyStore=true -p:RunAOTCompilation=false -p:PublishTrimmed=false --nologo
if ($LASTEXITCODE -ne 0) { throw "Release signing failed" }

$apks = @(Get-ChildItem -Path $project -Recurse -Filter "*-Signed.apk" -File)
if ($apks.Count -eq 0) { throw "Release signing completed, but no signed APK was produced" }
# Retain a distinctly named diagnostic copy even on verification failure.
# Do not present it as a working installable APK unless the checks pass.
$diagnosticDir = Join-Path $out "diagnostics"
New-Item -ItemType Directory -Force -Path $diagnosticDir | Out-Null
foreach ($apk in $apks) {
  Copy-Item -Path $apk.FullName -Destination (Join-Path $diagnosticDir "UNVERIFIED-$($apk.Name)") -Force
}
# Verify that this really can be installed by hand. Older builds were
# successful in CI but contained NO managed assembly store, causing a crash
# before the native diagnostic screen rendered.
Add-Type -AssemblyName System.IO.Compression
$verified = @()
foreach ($apk in $apks) {
  $archive = [System.IO.Compression.ZipFile]::OpenRead($apk.FullName)
  try {
    $managedEntries = @($archive.Entries | Where-Object {
      $_.FullName -match '(^assemblies/.*(\.blob|\.dll)$|^lib/arm64-v8a/lib(assembly-store|assemblies\.arm64-v8a\.blob)\.so$)'
    })
    Write-Host ("Managed assembly store entries in {0}: {1}" -f $apk.Name, $managedEntries.Count)
    if ($managedEntries.Count -eq 0) {
      $assemblyCandidates = @($archive.Entries | Where-Object { $_.FullName -match '(?i)(assembl|\.blob)' })
      Write-Host "Candidate assembly entries: $($assemblyCandidates.FullName -join ', ')"
    }
    foreach ($entry in $managedEntries) {
      Write-Host ("  {0} ({1} bytes)" -f $entry.FullName, $entry.Length)
    }
    if ($managedEntries.Count -eq 0) {
      throw "APK lacks a managed .NET assembly store; refusing to distribute incomplete APK"
    }
    $assetEntries = @($archive.Entries | Where-Object { $_.FullName -like 'assets/data/db/bundles/*' })
    if ($assetEntries.Count -eq 0) { throw "APK has no compiled Stride asset bundles" }
    $verified += $apk.FullName
  }
  finally {
    $archive.Dispose()
  }
}
foreach ($apk in $verified) {
  Copy-Item -Path $apk -Destination $artifacts -Force
  Write-Host "Verified self-contained APK: $apk"
}
