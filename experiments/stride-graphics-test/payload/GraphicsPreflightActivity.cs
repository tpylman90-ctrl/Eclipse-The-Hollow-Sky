using System;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using Android.Views;
using Android.Widget;

namespace StrideGraphicsTest.Android;

[Activity(
    MainLauncher = true,
    Exported = true,
    Label = "Stride Graphics Diagnostics",
    ScreenOrientation = ScreenOrientation.Landscape,
    Theme = "@android:style/Theme.Material.NoActionBar",
    ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
public sealed class GraphicsPreflightActivity : Activity
{
    private const string PreferencesFile = "stride_graphics_diagnostic";
    private const string LastStageKey = "last_stage";
    private TextView? message;

    protected override void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);
        var prefs = GetSharedPreferences(PreferencesFile, FileCreationMode.Private);
        var root = new LinearLayout(this) { Orientation = Orientation.Vertical };
        root.SetPadding(26, 20, 26, 20);

        var scroll = new ScrollView(this);
        message = new TextView(this) { TextSize = 15 };
        message.SetPadding(4, 4, 4, 14);
        root.AddView(message, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MatchParent, 0, 1));

        var button = new Button(this) { Text = "START STRIDE 3D" };
        button.Click += (_, _) =>
        {
            try
            {
                prefs?.Edit()?.PutString(LastStageKey, "3D launch requested; renderer status unknown")?.Apply();
                Android.Util.Log.Info("StrideGraphicsTest", "User requested Stride engine launch.");
                StartActivity(new Intent(this, typeof(StrideGraphicsTestActivity)));
            }
            catch (Exception error)
            {
                prefs?.Edit()?.PutString(LastStageKey, "Android launch error: " + error)?.Apply();
                Android.Util.Log.Error("StrideGraphicsTest", error.ToString());
                RefreshInfo();
            }
        };
        root.AddView(button, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MatchParent, ViewGroup.LayoutParams.WrapContent));

        var refresh = new Button(this) { Text = "REFRESH DEVICE DIAGNOSTICS" };
        refresh.Click += (_, _) => RefreshInfo();
        root.AddView(refresh, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MatchParent, ViewGroup.LayoutParams.WrapContent));

        scroll.AddView(root);
        SetContentView(scroll);
        RefreshInfo();
    }

    protected override void OnResume()
    {
        base.OnResume();
        if (message != null)
            RefreshInfo();
    }

    private void RefreshInfo()
    {
        var prefs = GetSharedPreferences(PreferencesFile, FileCreationMode.Private);
        var lastStage = prefs?.GetString(LastStageKey, "No previous Stride launch recorded") ?? "Unknown";
        string vulkan = "Not advertised by the device";
        string featureSummary = "No Vulkan feature declaration found";
        try
        {
            var features = PackageManager?.GetSystemAvailableFeatures();
            if (features != null)
            {
                foreach (var feature in features)
                {
                    if (feature?.Name == "android.hardware.vulkan.version")
                    {
                        int raw = feature.Version;
                        int major = (int)(((uint)raw >> 22) & 0x3ff);
                        int minor = (int)(((uint)raw >> 12) & 0x3ff);
                        int patch = raw & 0xfff;
                        vulkan = major + "." + minor + "." + patch;
                        featureSummary = "Android declares Vulkan hardware API version";
                        break;
                    }
                }
            }
        }
        catch (Exception error)
        {
            vulkan = "Cannot query: " + error.GetType().Name;
        }

        if (message != null)
            message.Text =
                "STRIDE 4.4 ANDROID GRAPHICS TEST — PREFLIGHT\n\n" +
                "This screen uses Android UI, not the Stride renderer.\n\n" +
                "Device: " + Build.Manufacturer + " " + Build.Model + "\n" +
                "Android: " + Build.VERSION.Release + " / API " + (int)Build.VERSION.SdkInt + "\n" +
                "Vulkan: " + vulkan + "\n" +
                featureSummary + "\n" +
                "Stride 4.4 requires Vulkan 1.3 and additional GPU features.\n\n" +
                "Last attempt: " + lastStage + "\n\n" +
                "Tap START STRIDE 3D. If it immediately closes, reopen this app, " +
                "take a screenshot of this screen, and tell me the Vulkan version shown. " +
                "A Vulkan version alone cannot prove all required device features.\n";
    }
}
