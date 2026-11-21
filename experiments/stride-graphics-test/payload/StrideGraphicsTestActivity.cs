#nullable enable
using Android.App;
using Android.OS;
using Android.Content.PM;
using Android.Views;
using Stride.Engine;
using Stride.Starter;
using StrideGraphicsTest.Player;

namespace StrideGraphicsTest.Android;

[Activity(
    MainLauncher = false,
    Label = "Stride Mobile Graphics",
    ScreenOrientation = ScreenOrientation.Landscape,
    Theme = "@android:style/Theme.NoTitleBar.Fullscreen",
    ConfigurationChanges = ConfigChanges.UiMode | ConfigChanges.Orientation | ConfigChanges.KeyboardHidden | ConfigChanges.ScreenSize)]
public class StrideGraphicsTestActivity : StrideActivity
{
    protected Game? Game;
    private MobileControlsOverlay? overlay;

    protected override void OnRun()
    {
        base.OnRun();
        MobileTouchState.SetActive(true);
        RunOnUiThread(() =>
        {
            if (IsFinishing || IsDestroyed)
                return;
            overlay = new MobileControlsOverlay(this);
            Window?.AddContentView(overlay, new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MatchParent,
                ViewGroup.LayoutParams.MatchParent));
        });
        Game = new Game();
        Game.Run(GameContext);
    }

    public override bool DispatchTouchEvent(MotionEvent? ev)
    {
        // Route multiple fingers to touch controls, so taps used for walking
        // and camera rotation don't inadvertently fire the starter weapon.
        if (ev != null && overlay != null)
        {
            overlay.ProcessTouch(ev);
            return true;
        }
        return base.DispatchTouchEvent(ev);
    }

    protected override void OnPause()
    {
        MobileTouchState.SetActive(false);
        base.OnPause();
    }

    protected override void OnResume()
    {
        base.OnResume();
        MobileTouchState.SetActive(true);
    }

    protected override void OnDestroy()
    {
        MobileTouchState.SetActive(false);
        overlay?.Dispose();
        overlay = null;
        Game?.Dispose();
        base.OnDestroy();
    }
}
