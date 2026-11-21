#nullable enable
using System;
using Android.Content;
using Android.Graphics;
using Android.Views;
using StrideGraphicsTest.Player;

namespace StrideGraphicsTest.Android;

// Visible, native Android touch HUD. The Activity receives MotionEvent multi-touch
// and forwards it here; this view draws only and does not intercept engine rendering.
public sealed class MobileControlsOverlay : View
{
    private readonly Paint fill = new Paint(PaintFlags.AntiAlias);
    private readonly Paint outline = new Paint(PaintFlags.AntiAlias);
    private readonly Paint text = new Paint(PaintFlags.AntiAlias);
    private readonly float density;

    private int moveId = -1, lookId = -1, fireId = -1, reloadId = -1;
    private float moveAnchorX, moveAnchorY, moveX, moveY;
    private float lastLookX, lastLookY;
    private float joyX, joyY, joyRadius, fireX, fireY, fireRadius, reloadX, reloadY, reloadRadius;
    private int measuredWidth, measuredHeight;

    public MobileControlsOverlay(Context context) : base(context)
    {
        density = context.Resources?.DisplayMetrics?.Density ?? 1f;
        outline.SetStyle(Paint.Style.Stroke);
        outline.StrokeWidth = 2.5f * density;
        text.Color = Color.Argb(220, 240, 250, 255);
        text.TextSize = 13f * density;
        text.SetStyle(Paint.Style.Fill);
        SetWillNotDraw(false);
        Clickable = false;
        Focusable = false;
        ContentDescription = "Left stick move, right swipe look, fire and reload buttons";
    }

    private void SizeControls()
    {
        if (Width == measuredWidth && Height == measuredHeight && measuredWidth != 0)
            return;
        measuredWidth = Width;
        measuredHeight = Height;
        if (Width <= 0 || Height <= 0) return;

        joyRadius = Math.Min(80f * density, Height * 0.165f);
        joyX = Math.Max(joyRadius + 24f * density, Width * 0.115f);
        joyY = Height - joyRadius - 19f * density;
        fireRadius = Math.Min(49f * density, Height * 0.104f);
        fireX = Width - fireRadius - 24f * density;
        fireY = Height - fireRadius - 22f * density;
        reloadRadius = Math.Min(36f * density, Height * 0.073f);
        reloadX = fireX;
        reloadY = fireY - (fireRadius + reloadRadius + 19f * density);
        if (moveId < 0) { moveAnchorX = joyX; moveAnchorY = joyY; }
    }

    protected override void OnSizeChanged(int w, int h, int oldw, int oldh)
    {
        base.OnSizeChanged(w, h, oldw, oldh);
        measuredWidth = -1;
        SizeControls();
    }

    private bool CloseTo(float x, float y, float cx, float cy, float radius)
    {
        var dx = x - cx;
        var dy = y - cy;
        return dx * dx + dy * dy <= radius * radius;
    }

    private void StartPointer(int id, float x, float y)
    {
        if (CloseTo(x, y, Width - 38f * density, 40f * density, 25f * density))
        {
            MobileTouchState.AdjustLookSensitivity(+0.25f);
        }
        else if (CloseTo(x, y, Width - 105f * density, 40f * density, 25f * density))
        {
            MobileTouchState.AdjustLookSensitivity(-0.25f);
        }
        else if (fireId < 0 && CloseTo(x, y, fireX, fireY, fireRadius * 1.42f))
        {
            fireId = id;
            MobileTouchState.SetFire(true);
        }
        else if (reloadId < 0 && CloseTo(x, y, reloadX, reloadY, reloadRadius * 1.5f))
        {
            reloadId = id;
            MobileTouchState.SetReload(true);
        }
        else if (moveId < 0 && x < Width * 0.43f && y > Height * 0.30f)
        {
            moveId = id;
            moveAnchorX = x;
            moveAnchorY = y;
            moveX = x;
            moveY = y;
            MobileTouchState.SetMovement(0, 0);
        }
        else if (lookId < 0)
        {
            lookId = id;
            lastLookX = x;
            lastLookY = y;
        }
    }

    private void MovePointer(int id, float x, float y)
    {
        if (id == moveId)
        {
            moveX = x;
            moveY = y;
            var dx = (x - moveAnchorX) / Math.Max(1f, joyRadius);
            var dy = (moveAnchorY - y) / Math.Max(1f, joyRadius);
            MobileTouchState.SetMovement(dx, dy);
        }
        else if (id == lookId)
        {
            var dx = x - lastLookX;
            var dy = y - lastLookY;
            lastLookX = x;
            lastLookY = y;
            // The FPS camera expects a fraction of the screen width/height.
            MobileTouchState.AddLook(
                dx * (95f * MobileTouchState.LookSensitivity) / Math.Max(1f, Width),
                -dy * (80f * MobileTouchState.LookSensitivity) / Math.Max(1f, Height));
        }
    }

    private void EndPointer(int id)
    {
        if (id == moveId)
        {
            moveId = -1;
            moveAnchorX = joyX;
            moveAnchorY = joyY;
            MobileTouchState.SetMovement(0, 0);
        }
        if (id == lookId) lookId = -1;
        if (id == fireId)
        {
            fireId = -1;
            MobileTouchState.SetFire(false);
        }
        if (id == reloadId)
        {
            reloadId = -1;
            MobileTouchState.SetReload(false);
        }
    }

    private void Clear()
    {
        moveId = lookId = fireId = reloadId = -1;
        moveAnchorX = joyX;
        moveAnchorY = joyY;
        MobileTouchState.SetMovement(0, 0);
        MobileTouchState.SetFire(false);
        MobileTouchState.SetReload(false);
    }

    public void ProcessTouch(MotionEvent ev)
    {
        SizeControls();
        var action = ev.ActionMasked;
        if (action == MotionEventActions.Down || action == MotionEventActions.PointerDown)
        {
            var index = ev.ActionIndex;
            StartPointer(ev.GetPointerId(index), ev.GetX(index), ev.GetY(index));
        }
        else if (action == MotionEventActions.Move)
        {
            for (var i = 0; i < ev.PointerCount; i++)
                MovePointer(ev.GetPointerId(i), ev.GetX(i), ev.GetY(i));
        }
        else if (action == MotionEventActions.Up || action == MotionEventActions.PointerUp)
        {
            var index = ev.ActionIndex;
            EndPointer(ev.GetPointerId(index));
        }
        else if (action == MotionEventActions.Cancel)
        {
            Clear();
        }
        Invalidate();
    }

    private void Circle(Canvas canvas, float x, float y, float radius, Color color)
    {
        fill.Color = color;
        canvas.DrawCircle(x, y, radius, fill);
    }

    private void Ring(Canvas canvas, float x, float y, float radius, Color color)
    {
        outline.Color = color;
        canvas.DrawCircle(x, y, radius, outline);
    }

    private void Caption(Canvas canvas, string message, float x, float y)
    {
        var width = text.MeasureText(message);
        canvas.DrawText(message, x - width / 2f, y, text);
    }

    protected override void OnDraw(Canvas? canvas)
    {
        base.OnDraw(canvas);
        if (canvas == null) return;
        SizeControls();
        if (Width <= 0 || Height <= 0) return;

        var baseX = moveId >= 0 ? moveAnchorX : joyX;
        var baseY = moveId >= 0 ? moveAnchorY : joyY;

        Circle(canvas, baseX, baseY, joyRadius, Color.Argb(45, 12, 25, 45));
        Ring(canvas, baseX, baseY, joyRadius, Color.Argb(195, 105, 215, 245));
        var dx = moveId >= 0 ? moveX - baseX : 0;
        var dy = moveId >= 0 ? moveY - baseY : 0;
        var len = MathF.Sqrt(dx * dx + dy * dy);
        if (len > joyRadius) { dx = dx / len * joyRadius; dy = dy / len * joyRadius; }
        Circle(canvas, baseX + dx, baseY + dy, joyRadius * .36f, Color.Argb(142, 75, 215, 245));
        Caption(canvas, "MOVE", baseX, baseY - joyRadius - 11f * density);

        Circle(canvas, fireX, fireY, fireRadius, fireId >= 0
            ? Color.Argb(195, 225, 91, 55) : Color.Argb(105, 225, 91, 55));
        Ring(canvas, fireX, fireY, fireRadius, Color.Argb(225, 255, 200, 162));
        Caption(canvas, "FIRE", fireX, fireY + 5f * density);

        Circle(canvas, reloadX, reloadY, reloadRadius, reloadId >= 0
            ? Color.Argb(185, 45, 158, 220) : Color.Argb(96, 45, 158, 220));
        Ring(canvas, reloadX, reloadY, reloadRadius, Color.Argb(208, 150, 220, 255));
        Caption(canvas, "RELOAD", reloadX, reloadY + 5f * density);

        text.Color = Color.Argb(185, 235, 245, 255);
        Caption(canvas, "DRAG RIGHT SIDE TO LOOK", Width * 0.63f, 29f * density);
        Ring(canvas, Width - 105f * density, 40f * density, 25f * density, Color.Argb(190, 130, 215, 255));
        Ring(canvas, Width - 38f * density, 40f * density, 25f * density, Color.Argb(190, 130, 215, 255));
        Caption(canvas, "-", Width - 105f * density, 45f * density);
        Caption(canvas, "+", Width - 38f * density, 45f * density);
        Caption(canvas, "LOOK " + MobileTouchState.LookSensitivity.ToString("0.00") + "x", Width - 75f * density, 78f * density);
        Caption(canvas, "UPDATE " + MobileTouchState.UpdateFps.ToString("0") + " FPS (approx)", Width * 0.34f, 25f * density);
        text.Color = Color.Argb(220, 240, 250, 255);
        PostInvalidateDelayed(350);  // 3 Hz readout; does not run in the renderer loop
    }
}
