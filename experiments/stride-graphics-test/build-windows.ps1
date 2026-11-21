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
$activityText = [System.IO.File]::ReadAllText($originalActivity)
if (-not $activityText.Contains("MainLauncher = true")) {
  throw "Upstream Stride Activity launcher structure changed"
}
$activityText = $activityText.Replace("MainLauncher = true", "MainLauncher = false")
$activityText = $activityText.Replace("Game.Dispose();", "Game?.Dispose();")
[System.IO.File]::WriteAllText($originalActivity, $activityText)

$diagnosticsSource = Join-Path $root "payload/GraphicsPreflightActivity.cs"
Copy-Item -Path $diagnosticsSource -Destination (Join-Path $androidDirectory "GraphicsPreflightActivity.cs") -Force

# Use a unique identifier so the diagnostic APK can coexist with the original
# signed Stride test even when transient GitHub runner signing keys differ.
$androidProject = Join-Path $androidDirectory "$name.Android.csproj"
$androidProjectContent = [System.IO.File]::ReadAllText($androidProject)
$androidProjectContent = $androidProjectContent.Replace(
  "<ApplicationId>StrideGraphicsTest</ApplicationId>",
  "<ApplicationId>com.neonfoundry.stride.graphicsdiagnostic</ApplicationId>")
[System.IO.File]::WriteAllText($androidProject, $androidProjectContent)

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
Write-Host "Stage 1: Compile Android assembly without Stride asset processing"
dotnet build $projects[0].FullName -c Debug -p:StrideCompilerSkipBuild=true -p:AndroidPackageFormat=apk --nologo
if ($LASTEXITCODE -ne 0) { throw "Stage 1 Android assembly compilation failed" }

$targetAssembly = Join-Path $project "Bin/Android/Debug/$name.Android.dll"
Write-Host "Stage 1 Android assembly exists: $(Test-Path $targetAssembly)"
if (Test-Path $targetAssembly) {
  Get-Item $targetAssembly | Select-Object FullName, Length | Format-List
}

Write-Host "Stage 2: Compile full Stride assets and Android APK"
dotnet build $projects[0].FullName -c Debug -p:AndroidPackageFormat=apk -p:StrideBuildEngineLogVerbose=true --nologo
if ($LASTEXITCODE -ne 0) { throw "Stage 2 Stride Android asset build failed; check above logs" }

$apks = @(Get-ChildItem -Path $project -Recurse -Filter "*.apk" -File)
if ($apks.Count -eq 0) { throw "Build completed, but no APK was produced" }
foreach ($apk in $apks) {
  Copy-Item -Path $apk.FullName -Destination $artifacts -Force
  Write-Host "APK: $($apk.Name)"
}
