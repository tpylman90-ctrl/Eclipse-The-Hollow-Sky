#nullable enable
using Android.App;
using Android.Content.PM;
using Android.OS;
using Android.Views;
using Stride.Engine;
using Stride.Starter;

namespace EclipseHollowSky.Android
{
    // Actual Eclipse Android app. No FPS Activity or FPS-specific input.
    [Activity(MainLauncher = true, Exported = true,
        Label = "Eclipse: The Hollow Sky",
        ScreenOrientation = ScreenOrientation.Landscape,
        Theme = "@android:style/Theme.NoTitleBar.Fullscreen",
        ConfigurationChanges = ConfigChanges.UiMode | ConfigChanges.Orientation |
                               ConfigChanges.KeyboardHidden | ConfigChanges.ScreenSize)]
    public sealed class EclipseActivity : StrideActivity
    {
        private Game? game;
        private FlightHud? hud;

        protected override void OnRun()
        {
            base.OnRun();
            RunOnUiThread(() =>
            {
                if (IsFinishing || IsDestroyed) return;
                hud = new FlightHud(this);
                Window?.AddContentView(hud, new ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MatchParent,
                    ViewGroup.LayoutParams.MatchParent));
            });
            game = new Game();
            game.Run(GameContext);
        }
        public override bool DispatchTouchEvent(MotionEvent? e)
        {
            if (e != null && hud != null)
            {
                hud.ProcessTouch(e);
                return true;
            }
            return base.DispatchTouchEvent(e);
        }
        protected override void OnPause()
        {
            EclipseBridge.ReleaseAll();
            base.OnPause();
        }
        protected override void OnDestroy()
        {
            EclipseBridge.ReleaseAll();
            hud?.Dispose();
            hud = null;
            game?.Dispose();
            base.OnDestroy();
        }
    }
}