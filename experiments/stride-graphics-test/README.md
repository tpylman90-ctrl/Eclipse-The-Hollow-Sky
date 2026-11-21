# Stride Android graphics smoke test (isolated)

This experiment is **not part of Eclipse: The Hollow Sky**. The existing Godot project at the repository root remains the game. Do not merge these graphics experiments into the Godot runtime.

## Goal

Find out whether **Stride 4.4.3** can generate, compile, and package a real 3D scene for Android **entirely in GitHub Actions**, without purchasing a Unity license or using Kaggle GPU training time.

First pass: the upstream **Stride FPS starter** scene, in landscape mode with graphics profile 10.0. It is an initial 3D renderer and packaging smoke test, **not** a calibrated graphics-quality comparison with Godot. It exercises the starter's scene, camera, geometry, materials, and lighting. The source is generated from the official MIT-licensed template and uploaded as a build artifact.

## Run

1. Open **Actions** > **Stride Android Graphics Smoke** > **Run workflow**.
2. Select the default `main` branch.
3. When complete, open the workflow run and download the `stride-android-graphics-test` artifact. It should contain an APK and the generated starter source (ZIP) if build succeeds.
4. Install the APK on an Android device, launch it, and note whether 3D geometry is visible, rendering artifacts/crashes, and approximate FPS/device heating. Return screenshots to compare with an equivalent Godot scene.

Automatic runs also occur when this isolated test's workflow, script, or README changes. Standard hosted GitHub Actions runners are used; no Kaggle GPU quota is requested.

## What the CI verifies

- Installs .NET 10, the Android workload, and the pinned Stride template.
- Creates a separate Stride Android FPS sample using official CLI templates.
- Builds a **debug Android APK** (debug signing is expected from the .NET Android tooling).
- Collects APKs and uploads the generated Stride source for review.

A successful CI build does **not** prove Vulkan 1.3 device compatibility, runtime stability, visual quality, or 60 FPS. Those require installing on the actual phone. If the Android toolchain/packaging fails, the workflow logs identify the step to fix.

## Safety and isolation

- All generated Stride files stay under `experiments/stride-graphics-test/.generated/` (ignored by Git for local runs); there are no edits to root `project.godot`, `scenes/`, `scripts/`, or game workflows.
- Uses free, publicly available Stride templates and SDK packages.
- No production game assets, release signing credentials, or GPU training workloads.
- No claims of a verified APK until the GitHub Actions run completes successfully.
