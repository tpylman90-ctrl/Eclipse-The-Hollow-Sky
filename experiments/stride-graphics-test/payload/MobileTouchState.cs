// Touch input bridge between Android's UI thread and Stride's update thread.
// Original diagnostic experiment: no engine internals or external assets changed.
using System;
using Stride.Core.Mathematics;

namespace StrideGraphicsTest.Player
{
    public static class MobileTouchState
    {
        private static readonly object Gate = new object();
        private static Vector2 movement;
        private static Vector2 lookDelta;
        private static bool firing;
        private static bool reloading;
        private static volatile bool enabled;
        private static float sensitivity = 1.0f;
        private static float updateFps;

        public static float LookSensitivity
        {
            get { lock (Gate) return sensitivity; }
        }

        public static float UpdateFps
        {
            get { lock (Gate) return updateFps; }
        }

        public static void AdjustLookSensitivity(float amount)
        {
            lock (Gate)
                sensitivity = Math.Clamp(sensitivity + amount, 0.5f, 2.5f);
        }

        public static void SetUpdateFps(float value)
        {
            lock (Gate)
                updateFps = value;
        }
        public static bool Enabled => enabled;

        public static void SetActive(bool active)
        {
            lock (Gate)
            {
                movement = Vector2.Zero;
                lookDelta = Vector2.Zero;
                firing = false;
                reloading = false;
                enabled = active;
            }
        }

        public static void SetMovement(float x, float forward)
        {
            lock (Gate)
            {
                var vector = new Vector2(x, forward);
                if (vector.LengthSquared() > 1f)
                    vector.Normalize();
                movement = vector;
            }
        }

        public static void AddLook(float horizontal, float vertical)
        {
            lock (Gate)
            {
                lookDelta += new Vector2(
                    Math.Clamp(horizontal, -18f, 18f),
                    Math.Clamp(vertical, -18f, 18f));
            }
        }

        public static void SetFire(bool held)
        {
            lock (Gate) firing = held;
        }

        public static void SetReload(bool held)
        {
            lock (Gate) reloading = held;
        }

        public static void Read(out Vector2 move, out Vector2 look, out bool fire, out bool reload)
        {
            lock (Gate)
            {
                move = movement;
                look = lookDelta;
                fire = firing;
                reload = reloading;
                lookDelta = Vector2.Zero;  // consume a drag once; not once per update repeat
            }
        }
    }
}
