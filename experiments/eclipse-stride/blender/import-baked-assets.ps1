param(
    [Parameter(Mandatory=$true)][string]$AssetsRoot,
    [Parameter(Mandatory=$true)][string]$ResourcesRoot,
    [Parameter(Mandatory=$true)][string]$GameRoot,
    [Parameter(Mandatory=$true)][string]$BakeRoot
)
$ErrorActionPreference = "Stop"
# Stride asset compiler takes real, cached Blender GLBs and PNGs. Game Studio
# is not required to execute these builds on GitHub Actions.
$names = @("EclipseSkiff", "EclipseIsland")
$modelDir = Join-Path $AssetsRoot "Models"
$matDir = Join-Path $AssetsRoot "Materials"
$texDir = Join-Path $AssetsRoot "Textures"
$resDir = Join-Path $ResourcesRoot "Blender"
foreach ($p in @($modelDir, $matDir, $texDir, $resDir)) {
    New-Item -ItemType Directory -Force -Path $p | Out-Null
}
$fixed = @{
    EclipseSkiff = @{
        Model = "627b3512-d4cb-41b9-8d3b-5d7800000001"
        Material = "627b3512-d4cb-41b9-8d3b-5d7800000002"
        Texture = "627b3512-d4cb-41b9-8d3b-5d7800000003"
        Slot = "627b3512-d4cb-41b9-8d3b-5d7800000004"
    }
    EclipseIsland = @{
        Model = "627b3512-d4cb-41b9-8d3b-5d7800000011"
        Material = "627b3512-d4cb-41b9-8d3b-5d7800000012"
        Texture = "627b3512-d4cb-41b9-8d3b-5d7800000013"
        Slot = "627b3512-d4cb-41b9-8d3b-5d7800000014"
    }
}
$roots = @()
foreach ($name in $names) {
    foreach ($suffix in @(".glb","_albedo_ao.png")) {
        $p = Join-Path $BakeRoot ($name + $suffix)
        if (-not (Test-Path $p)) { throw "Missing baked Blender artifact $p" }
        Copy-Item $p $resDir -Force
    }
    $ids = $fixed[$name]
    $modelId = $ids.Model
    $textureId = $ids.Texture
    $materialId = $ids.Material
    $slotId = $ids.Slot
    $sdm3d = @"
!Model
Id: $modelId
SerializedVersion: {Stride: 2.1.0.0}
Tags: []
Source: !file ../../Resources/Blender/$name.glb
Skeleton: null
PivotPosition: {X: 0.0, Y: 0.0, Z: 0.0}
Materials:
    $slotId\:
        Name: BAKED
        MaterialInstance:
            Material: ${materialId}:Materials/${name}Baked
DeduplicateMaterials: false
Modifiers: {}
"@
    # YAML mappings are keyed by a stable 32-digit item ID (without dashes).
    $sdm3d = $sdm3d.Replace("${slotId}\:", ($slotId -replace "-","") + ":")
    [System.IO.File]::WriteAllText((Join-Path $modelDir "$name.sdm3d"), $sdm3d)
    $sdtex = @"
!Texture
Id: $textureId
SerializedVersion: {Stride: 2.0.0.0}
Tags: []
Source: !file ../../Resources/Blender/${name}_albedo_ao.png
Type: !ColorTextureType
    ColorKeyColor: {R: 255, G: 0, B: 255, A: 255}
    Alpha: Interpolated
IsStreamable: false
"@
    [System.IO.File]::WriteAllText((Join-Path $texDir "$name.sdtex"), $sdtex)
    $sdmat = @"
!MaterialAsset
Id: $materialId
SerializedVersion: {Stride: 2.0.0.0}
Tags: []
Attributes:
    Diffuse: !MaterialDiffuseMapFeature
        DiffuseMap: !ComputeTextureColor
            Texture: ${textureId}:Textures/$name
            FallbackValue:
                Value: {R: 1.0, G: 1.0, B: 1.0, A: 1.0}
            Scale: {X: 1.0, Y: 1.0}
            Offset: {X: 0.0, Y: 0.0}
            Swizzle: null
    DiffuseModel: !MaterialDiffuseLambertModelFeature {}
    Overrides:
        UVScale: {X: 1.0, Y: 1.0}
Layers: {}
"@
    [System.IO.File]::WriteAllText((Join-Path $matDir "${name}Baked.sdmat"), $sdmat)
    $roots += ("    - " + $modelId + ":/StrideGraphicsTest.Game/Models/" + $name)
}
$package = Join-Path $GameRoot "StrideGraphicsTest.Game.sdpkg"
if (-not (Test-Path $package)) {
    throw "Stride game package missing at $package"
}
$pkg = [System.IO.File]::ReadAllText($package)
if ($pkg -match '(?m)^RootAssets:\s*\[\]') {
    $pkg = [regex]::Replace($pkg,'(?m)^RootAssets:\s*\[\]', "RootAssets:`n$($roots -join "`n")")
} elseif ($pkg -match '(?m)^RootAssets:\s*$') {
    $pkg = [regex]::Replace($pkg,'(?m)^RootAssets:\s*$',
        "RootAssets:`n$($roots -join "`n")")
} elseif ($pkg -notmatch '(?m)^RootAssets:') {
    $pkg += "`nRootAssets:`n$($roots -join "`n")`n"
} else {
    throw "Unexpected RootAssets package structure, refusing to alter build roots"
}
[System.IO.File]::WriteAllText($package,$pkg)
Write-Host "Blender GLBs and UV-baked atlas material assets added as Stride compiler roots."
