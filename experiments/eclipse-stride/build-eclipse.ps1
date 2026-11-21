$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $root ".generated"
$project = Join-Path $out "StrideGraphicsTest"
$artifact = Join-Path $out "artifacts"
New-Item -ItemType Directory -Force -Path $artifact | Out-Null
if (Test-Path $project) { throw "Refusing to overwrite generated Eclipse project" }

# The free official template provides Stride's working Android/Vulkan toolchain
# and asset compiler. We immediately remove its FPS map, weapons, and gameplay.
# What ships is the separate, original Eclipse flight game below.
dotnet new install Stride.Templates.Games.Starters@4.4.4
if ($LASTEXITCODE -ne 0) { throw "Stride template installation failed" }
dotnet new stride-fps -n StrideGraphicsTest -o $project --platforms android
if ($LASTEXITCODE -ne 0) { throw "Stride Android template creation failed" }

$gameDir = Join-Path $project "StrideGraphicsTest.Game"
$androidDir = Join-Path $project "StrideGraphicsTest.Android"
$assetsDir = Join-Path $project "Assets"

# Remove every template scene asset except the three files required for a
# clean scene+compositor. This eliminates the FPS test room and gun model.
Get-ChildItem -LiteralPath $assetsDir -Force | Where-Object {
    $_.Name -notin @("GameSettings.sdgamesettings", "GraphicsCompositor.sdgfxcomp", "MainScene.sdscene")
} | Remove-Item -Recurse -Force

# Remove FPS starter game scripts, character/controller/gun, and activities.
Get-ChildItem -LiteralPath $gameDir -Recurse -File -Filter "*.cs" | Remove-Item -Force
Get-ChildItem -LiteralPath $androidDir -Recurse -File -Filter "*.cs" | Remove-Item -Force

Copy-Item (Join-Path $root "source/MainScene.sdscene") (Join-Path $assetsDir "MainScene.sdscene") -Force
Copy-Item (Join-Path $root "source/EclipseBridge.cs") (Join-Path $gameDir "EclipseBridge.cs") -Force
Copy-Item (Join-Path $root "source/EclipseDirector.cs") (Join-Path $gameDir "EclipseDirector.cs") -Force
Copy-Item (Join-Path $root "source/EclipseActivity.cs") (Join-Path $androidDir "EclipseActivity.cs") -Force
Copy-Item (Join-Path $root "source/FlightHud.cs") (Join-Path $androidDir "FlightHud.cs") -Force

# Engine patch version matches the proven working Stride 4.4.3 Android build.
Get-ChildItem -Path $project -Recurse -File |
    Where-Object { $_.Extension -in @(".csproj", ".props", ".targets") } |
    ForEach-Object {
        $old = [System.IO.File]::ReadAllText($_.FullName)
        $new = [regex]::Replace($old, '4\.4\.[012]', '4.4.3')
        if ($new -cne $old) { [System.IO.File]::WriteAllText($_.FullName, $new) }
    }

$settings = Join-Path $assetsDir "GameSettings.sdgamesettings"
$settingText = [System.IO.File]::ReadAllText($settings)
$settingText = $settingText.Replace("DefaultBackBufferWidth: 1280","DefaultBackBufferWidth: 960")
$settingText = $settingText.Replace("DefaultBackBufferHeight: 720","DefaultBackBufferHeight: 540")
[System.IO.File]::WriteAllText($settings, $settingText)

$compositor = Join-Path $assetsDir "GraphicsCompositor.sdgfxcomp"
$graphics = [System.IO.File]::ReadAllText($compositor)
$graphics = $graphics.Replace(
    "Color: {R: 0.40491876, G: 0.41189542, B: 0.43775, A: 1.0}",
    "Color: {R: 0.055, G: 0.075, B: 0.17, A: 1.0}")
[System.IO.File]::WriteAllText($compositor,$graphics)

$androidProject = Join-Path $androidDir "StrideGraphicsTest.Android.csproj"
$xml = [System.IO.File]::ReadAllText($androidProject)
$xml = [regex]::Replace($xml, '<ApplicationId>[^<]+</ApplicationId>',
    '<ApplicationId>com.neonfoundry.eclipse.stride.game</ApplicationId>')
$xml = $xml.Replace("<AndroidApplicationIcon>@mipmap/appicon</AndroidApplicationIcon>",
    "<AndroidApplicationIcon>@mipmap/appicon</AndroidApplicationIcon>`n" +
    "<EmbedAssembliesIntoApk>true</EmbedAssembliesIntoApk>`n" +
    "<AndroidEnableFastDeployment>false</AndroidEnableFastDeployment>")
[System.IO.File]::WriteAllText($androidProject, $xml)

# The game must not regress to the FPS starter environment, even by mistake.
if ((Get-ChildItem $assetsDir -Recurse -File | Where-Object {
    $_.FullName -match 'PrototypingBlocks|Gun|Weapons|Stairs|GridBase'
}).Count -ne 0) { throw "FPS starter assets leaked into the Eclipse build" }
if (-not (Select-String -Path (Join-Path $assetsDir "MainScene.sdscene") -Pattern "EclipseDirector" -Quiet)) {
    throw "Eclipse game director missing from scene"
}
if ((Get-ChildItem $gameDir -Recurse -File -Filter "*.cs").Count -ne 2) {
    throw "Incorrect game scripts: FPS scripts may remain"
}

# Save source before compilation so every run can be reproduced.
Compress-Archive -Path $project -DestinationPath (Join-Path $artifact "eclipse-stride-source.zip") -Force

$projectFile = Join-Path $androidDir "StrideGraphicsTest.Android.csproj"
$common = @(
    "-c", "Release", "-p:AndroidPackageFormat=apk",
    "-p:EmbedAssembliesIntoApk=true", "-p:AndroidUseAssemblyStore=true",
    "-p:RunAOTCompilation=false", "-p:PublishTrimmed=false", "--nologo"
)
Write-Host "ECLIPSE Stage 1: compile game assemblies and world scripts"
dotnet build $projectFile @common -p:StrideCompilerSkipBuild=true
if ($LASTEXITCODE -ne 0) { throw "Eclipse C# compile failed" }
Write-Host "ECLIPSE Stage 2: compile original scene, lighting, and game assets"
dotnet build $projectFile @common
if ($LASTEXITCODE -ne 0) { throw "Eclipse Stride asset build failed" }
Write-Host "ECLIPSE Stage 3: sign standalone Android APK"
dotnet build $projectFile @common -t:SignAndroidPackage
if ($LASTEXITCODE -ne 0) { throw "Eclipse signing failed" }

$apks = @(Get-ChildItem -Path $project -Recurse -File -Filter "*-Signed.apk")
if ($apks.Count -ne 1) { throw "Expected exactly one signed Eclipse APK; got $($apks.Count)" }
Add-Type -AssemblyName System.IO.Compression
$apk = $apks[0]
$zip = [System.IO.Compression.ZipFile]::OpenRead($apk.FullName)
try {
    $entries = @($zip.Entries | ForEach-Object { $_.FullName })
    if (-not ($entries | Where-Object {
        $_ -match '^lib/arm64-v8a/libassemblies\.arm64-v8a\.blob\.so$'
    })) { throw "The standalone APK is missing its .NET assembly store" }
    if (-not ($entries | Where-Object { $_ -like 'assets/data/db/bundles/*' })) {
        throw "The APK is missing compiled Stride assets"
    }
    if (-not ($entries | Where-Object { $_ -eq 'AndroidManifest.xml' })) {
        throw "Android manifest missing"
    }
    if (($entries | Where-Object { $_ -match 'PrototypingBlocks|Gun_.*\.(xk|sd)|GridMTWall' }).Count -ne 0) {
        throw "FPS demo assets are still packaged"
    }
    Write-Host "Verified Eclipse game APK: $($apk.Length) bytes; $($entries.Count) ZIP entries"
}
finally { $zip.Dispose() }
Copy-Item $apk.FullName (Join-Path $artifact "Eclipse-The-Hollow-Sky-Stride-v1.apk") -Force
Write-Host "Eclipse Android game APK ready."
