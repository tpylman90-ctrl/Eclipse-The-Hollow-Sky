using System;
using Stride.Core.Mathematics;

namespace EclipseHollowSky
{
    // Thread-safe input/HUD boundary: Android touch UI <-> Stride update thread.
    public static class EclipseBridge
    {
        private static readonly object Gate = new object();
        private static Vector2 steer;
        private static bool fire, boost, brake, launch, qualityChange;
        private static int buyUpgrade = -1;
        private static string mode = "SPLASH", message = "POWERED BY STRIDE";
        private static float progress;
        private static float hull = 3f, energy = 100, time = 90, fps, renderedFps,
            updateMs, managedMb;
        private static int drawCalls, triangles, graphicsQuality = 1;
        private static int credits, score, gateIndex, sector = 1;
        private static readonly int[] upgrades = new int[3];

        public static void Steer(float x, float y)
        {
            lock (Gate)
            {
                steer = new Vector2(Math.Clamp(x, -1, 1), Math.Clamp(y, -1, 1));
                if (steer.LengthSquared() > 1f) steer.Normalize();
            }
        }
        public static void Buttons(bool fireOn, bool boostOn, bool brakeOn)
        {
            lock (Gate) { fire = fireOn; boost = boostOn; brake = brakeOn; }
        }
        public static void Launch() { lock (Gate) launch = true; }
        public static void Buy(int which) { lock (Gate) buyUpgrade = which; }
        public static void CycleQuality() { lock (Gate) qualityChange = true; }
        public static void Input(out Vector2 stick, out bool firing, out bool boosting,
                                 out bool braking, out bool start, out int purchase, out bool nextQuality)
        {
            lock (Gate)
            {
                stick = steer; firing = fire; boosting = boost; braking = brake;
                start = launch; purchase = buyUpgrade; nextQuality = qualityChange;
                launch = false; buyUpgrade = -1; qualityChange = false;
            }
        }
        public static void Publish(string nextMode, string line, float nextHull, float nextEnergy,
                                   float nextTime, float tickFps, float actualFps, float nextUpdateMs,
                                   int nextDraws, int nextTriangles, float nextManagedMb,
                                   int nextQuality, int nextScore, int nextCredits,
                                   int nextGate, int nextSector, int[] nextUpgrades, float nextProgress)
        {
            lock (Gate)
            {
                mode = nextMode; message = line; hull = nextHull; energy = nextEnergy;
                time = nextTime; fps = tickFps; renderedFps = actualFps; updateMs = nextUpdateMs;
                drawCalls = nextDraws; triangles = nextTriangles; managedMb = nextManagedMb;
                graphicsQuality = nextQuality; score = nextScore; credits = nextCredits;
                gateIndex = nextGate; sector = nextSector; progress = nextProgress;
                for (int i = 0; i < 3; i++) upgrades[i] = nextUpgrades[i];
            }
        }
        public static void Hud(out string displayMode, out string line, out float health,
                               out float reactor, out float clock, out float updateHz, out float drawFps, out float cpuUpdateMs,
                               out int drawCount, out int triangleCount, out float heapMb,
                               out int quality, out int points, out int salvage, out int signal, out int currentSector,
                               out int[] levels, out float loadProgress)
        {
            lock (Gate)
            {
                displayMode = mode; line = message; health = hull; reactor = energy;
                clock = time; updateHz = fps; drawFps = renderedFps; cpuUpdateMs = updateMs;
                drawCount = drawCalls; triangleCount = triangles;
                heapMb = managedMb; quality = graphicsQuality;
                points = score; salvage = credits;
                signal = gateIndex; currentSector = sector;
                levels = (int[])upgrades.Clone();
                loadProgress = progress;
            }
        }
        public static void ReleaseAll()
        {
            lock (Gate) { steer = Vector2.Zero; fire = boost = brake = false; }
        }
    }
}