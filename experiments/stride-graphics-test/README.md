# Stride Android graphics test — isolated from Eclipse

The main repository is still the **Eclipse: The Hollow Sky** Godot game. This directory and its dedicated GitHub Actions workflow are an independent engine experiment. No edits are made to root `project.godot`, game assets, scenes, scripts or original workflows.

## Goal
Verify that Stride can generate, compile and package an actual 3D Android starter scene **using only GitHub**, without Unity licensing, a PC, or Kaggle GPU time.

## Current baseline
- Stride **first-person-shooter starter template 4.4.4**, with Stride engine package references brought up to the **4.4.3** maintenance release.
- The template's default scene, camera, graphics profile, materials and lighting; no fabricated benchmarks or custom PBR showcase yet.
- Android **debug APK**, produced by .NET 10 Android tooling when build succeeds.
- **Windows GitHub-hosted runner** for Android builds. An Ubuntu runner was trialed first; the Stride asset compiler's internal NuGet restore could not validate old dependency signing certificates. Package signature checking was **not disabled**.
- The test scene is generated at build time under `.generated/StrideGraphicsTest/` from the upstream MIT-licensed starter, and saved as `stride-source.zip` for inspection.

## Use
1. Go to the **Actions** tab in this repository and open **Stride Android Graphics Smoke**.
2. Choose **Run workflow** on `main`, or inspect the push-triggered run.
3. Download **stride-android-graphics-test** under Artifacts. Successful runs contain the APK and a source ZIP; failed builds may contain source only.
4. Install the APK if present and open on your Android phone. Capture a screenshot and report rendering anomalies, crash behavior and perceived smoothness. Runtime FPS/compatibility cannot be certified by GitHub compilation alone.

This is a **minimal rendering and packaging smoke test**, not yet a proper apples-to-apples comparison with Godot 4.5. Device benchmarks and a richer original PBR scene can follow after Android build and launch are verified.

If building reports known-vulnerable transitive NuGet dependencies, treat the APK as an isolated developer test, not a production or distributable game release. Do not change package-signature validation settings to bypass certificate errors.
