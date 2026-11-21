#nullable enable
using System;
using Android.Content;
using Android.Graphics;
using Android.Views;
using EclipseHollowSky;

namespace EclipseHollowSky.Android
{
    // Android-first gameplay HUD. The renderer remains native Stride Vulkan.
    // Multitouch: left stick for strafing/climbing, fire/boost/brake on right.
    public sealed class FlightHud : View
    {
        private readonly Paint ink = new Paint(PaintFlags.AntiAlias);
        private readonly Paint outline = new Paint(PaintFlags.AntiAlias);
        private readonly float density;
        private int stickId = -1, fireId = -1, boostId = -1, brakeId = -1;
        private float anchorX, anchorY, thumbX, thumbY, padX, padY, padRadius;
        private float fireX, fireY, boostX, boostY, brakeX, brakeY, buttonRadius;
        private bool firing, boosting, braking;
        private string mode = "SPLASH";
        private int[] upgrades = new int[3];

        public FlightHud(Context context) : base(context)
        {
            density = context.Resources?.DisplayMetrics?.Density ?? 1f;
            outline.SetStyle(Paint.Style.Stroke);
            outline.StrokeWidth = 2.4f * density;
            Clickable = true;
            SetWillNotDraw(false);
        }

        private void Layout()
        {
            padRadius = Math.Min(74f * density, Height * .17f);
            buttonRadius = Math.Min(46f * density, Height * .105f);
            padX = Math.Max(padRadius + 16f * density, Width * .13f);
            padY = Height - padRadius - 18f * density;
            fireX = Width - buttonRadius - 74f * density; // keep clear of Android right-side system navigation
            fireY = Height - buttonRadius - 20f * density;
            boostX = fireX - buttonRadius * 2.15f;
            boostY = fireY - buttonRadius * .25f;
            brakeX = fireX;
            brakeY = fireY - buttonRadius * 2.25f;
            if (stickId < 0) { anchorX = padX; anchorY = padY; }
        }

        private static bool Near(float x, float y, float cx, float cy, float r)
        {
            float dx = x - cx, dy = y - cy;
            return dx * dx + dy * dy <= r * r;
        }

        private void Down(int id, float x, float y)
        {
            if (mode != "FLIGHT")
            {
                if (mode != "MENU" && mode != "RESULT") return;
                if (y > Height * .69f && y < Height * .86f &&
                    x > Width * .08f && x < Width * .54f)
                    EclipseBridge.CycleQuality();
                else if (y > Height * .69f && x > Width * .60f)
                    EclipseBridge.Launch();
                else if (y > Height * .50f && y < Height * .73f)
                {
                    int choice = (int)(x / Math.Max(1, Width / 3f));
                    EclipseBridge.Buy(Math.Clamp(choice, 0, 2));
                }
                return;
            }
            if (fireId < 0 && Near(x, y, fireX, fireY, buttonRadius * 1.35f))
            { fireId = id; firing = true; }
            else if (boostId < 0 && Near(x, y, boostX, boostY, buttonRadius * 1.30f))
            { boostId = id; boosting = true; }
            else if (brakeId < 0 && Near(x, y, brakeX, brakeY, buttonRadius * 1.30f))
            { brakeId = id; braking = true; }
            else if (stickId < 0 && x < Width * .48f)
            {
                stickId = id; anchorX = x; anchorY = y;
                thumbX = x; thumbY = y;
            }
            Sync();
        }

        private void Move(int id, float x, float y)
        {
            if (id == stickId)
            {
                thumbX = x; thumbY = y;
                float horizontal = (x - anchorX) / Math.Max(1, padRadius);
                float climb = (anchorY - y) / Math.Max(1, padRadius);
                EclipseBridge.Steer(horizontal, climb);
            }
        }

        private void Up(int id)
        {
            if (id == stickId)
            {
                stickId = -1;
                EclipseBridge.Steer(0, 0);
            }
            if (id == fireId) { fireId = -1; firing = false; }
            if (id == boostId) { boostId = -1; boosting = false; }
            if (id == brakeId) { brakeId = -1; braking = false; }
            Sync();
        }

        private void Sync() => EclipseBridge.Buttons(firing, boosting, braking);
        private void Release()
        {
            stickId = fireId = boostId = brakeId = -1;
            firing = boosting = braking = false;
            EclipseBridge.ReleaseAll();
            Sync();
        }

        public void ProcessTouch(MotionEvent ev)
        {
            Layout();
            var action = ev.ActionMasked;
            if (action == MotionEventActions.Down || action == MotionEventActions.PointerDown)
            {
                int index = ev.ActionIndex;
                Down(ev.GetPointerId(index), ev.GetX(index), ev.GetY(index));
            }
            else if (action == MotionEventActions.Move)
            {
                for (int index = 0; index < ev.PointerCount; index++)
                    Move(ev.GetPointerId(index), ev.GetX(index), ev.GetY(index));
            }
            else if (action == MotionEventActions.Up || action == MotionEventActions.PointerUp)
            {
                int index = ev.ActionIndex;
                Up(ev.GetPointerId(index));
            }
            else if (action == MotionEventActions.Cancel) Release();
            Invalidate();
        }

        private void FillRect(Canvas c, float l, float t, float r, float b, Color color)
        {
            ink.Color = color;
            ink.SetStyle(Paint.Style.Fill);
            c.DrawRoundRect(l,t,r,b,9f*density,9f*density,ink);
        }
        private void Text(Canvas c,string value,float x,float y,float size, Color color, bool centered=false)
        {
            ink.Color = color;
            ink.TextSize = size*density;
            ink.SetStyle(Paint.Style.Fill);
            ink.SetTypeface(Typeface.Create("sans-serif-condensed", TypefaceStyle.Bold));
            if(centered) x -= ink.MeasureText(value)/2f;
            c.DrawText(value,x,y,ink);
        }
        private void Control(Canvas c,float x,float y,float radius,string label,Color color,bool held)
        {
            ink.Color = Color.Argb(held?190:110,color.R,color.G,color.B);
            c.DrawCircle(x,y,radius,ink);
            outline.Color=Color.Argb(230,202,238,251);
            c.DrawCircle(x,y,radius,outline);
            Text(c,label,x,y+5*density,13,Color.White,true);
        }
        protected override void OnDraw(Canvas? c)
        {
            base.OnDraw(c);
            if(c == null || Width < 1 || Height < 1) return;
            Layout();
            EclipseBridge.Hud(out string newMode, out string status, out float hp,
                out float reactor,out float clock,out float fps,
                out float drawFps, out float cpuMs, out int drawCalls, out int triangles,
                out float heapMb, out int graphicsQuality,
                out int points,out int salvage,out int signal,out int sector,out int[] levels,
                out float loadProgress);
            mode=newMode;upgrades=levels;

            var white = Color.Argb(248,234,247,251);
            var cyan = Color.Argb(250,62,227,245);
            var orange=Color.Argb(251,252,152,81);
            var faint=Color.Argb(170,166,191,215);

            if (mode == "SPLASH")
            {
                FillRect(c,0,0,Width,Height,Color.Argb(255,5,11,25));
                Text(c,"STRIDE", Width*.50f, Height*.46f, 52,white,true);
                Text(c,"GAME ENGINE", Width*.50f, Height*.54f, 16,cyan,true);
                Text(c,"POWERED BY STRIDE  /  ECLIPSE: THE HOLLOW SKY",
                    Width*.50f,Height*.82f,12,faint,true);
            }
            else if (mode == "LOADING" || mode == "SORTIE_LOADING")
            {
                FillRect(c,0,0,Width,Height,Color.Argb(255,7,14,30));
                Text(c,"ECLIPSE",Width*.50f,Height*.32f,40,white,true);
                Text(c,"THE HOLLOW SKY",Width*.50f,Height*.41f,20,cyan,true);
                Text(c,mode=="LOADING" ? "LOADING GAME WORLD" : "PREPARING SORTIE",
                    Width*.50f,Height*.54f,17,orange,true);
                Text(c,status,Width*.50f,Height*.62f,13,white,true);
                float barLeft=Width*.22f,barRight=Width*.78f;
                FillRect(c,barLeft,Height*.69f,barRight,Height*.73f,
                    Color.Argb(255,28,47,67));
                FillRect(c,barLeft,Height*.69f,
                    barLeft+(barRight-barLeft)*Math.Clamp(loadProgress,0f,1f),
                    Height*.73f,cyan);
                Text(c,Math.Round(loadProgress*100).ToString("0")+"%",
                    Width*.50f,Height*.81f,13,faint,true);
            }
            else if(mode=="FLIGHT")
            {
                FillRect(c,12*density,16*density,Math.Min(Width*.81f,660*density),133*density,Color.Argb(185,8,18,39));
                Text(c,"ECLIPSE  /  SECTOR "+sector,22*density,45*density,17,white);
                Text(c,"SIGNAL "+(signal+1).ToString("00")+"/07   HULL "+hp.ToString("0")+
                    "   ENERGY "+reactor.ToString("0"),22*density,69*density,13,cyan);
                Text(c,"SCORE "+points+"    TIME "+clock.ToString("0")+
                    "    RENDER "+drawFps.ToString("0")+" FPS   UPDATE "+fps.ToString("0")+"/s",
                    22*density,89*density,11,faint);
                Text(c,"UPD "+cpuMs.ToString("0.0")+"ms   DRAWS "+drawCalls+
                    "   TRIS "+triangles+"   MANAGED "+heapMb.ToString("0")+" MB",
                    22*density,110*density,11,cyan);
                Text(c,new[]{"PERF","BAL","HIGH"}[Math.Clamp(graphicsQuality,0,2)],
                    22*density,130*density,10,faint);
                if(status!="FOLLOW THE SIGNALS")
                    Text(c,status,Width*.50f,Height*.16f,16,orange,true);

                float bx=stickId>=0?anchorX:padX,by=stickId>=0?anchorY:padY;
                Control(c,bx,by,padRadius,"FLY",cyan,false);
                float dx=stickId>=0?thumbX-bx:0,dy=stickId>=0?thumbY-by:0;
                float d=MathF.Sqrt(dx*dx+dy*dy);
                if(d>padRadius){dx=dx/d*padRadius;dy=dy/d*padRadius;}
                ink.Color=Color.Argb(185,115,235,251);
                c.DrawCircle(bx+dx,by+dy,padRadius*.34f,ink);
                Text(c,"STRAFE / CLIMB",bx,by-padRadius-11*density,11,white,true);
                Control(c,fireX,fireY,buttonRadius,"FIRE",orange,firing);
                Control(c,boostX,boostY,buttonRadius,"BOOST",cyan,boosting);
                Control(c,brakeX,brakeY,buttonRadius*.85f,"BRAKE",faint,braking);
            }
            else
            {
                FillRect(c,0,0,Width,Height,Color.Argb(204,5,13,31));
                Text(c,"ECLIPSE",Width*.08f,Height*.23f,50,white);
                Text(c,"THE HOLLOW SKY",Width*.08f,Height*.33f,27,cyan);
                Text(c,mode=="RESULT"?"SORTIE COMPLETE":"MAIN MENU // AETHER HANGAR",
                    Width*.08f,Height*.43f,17,orange);
                Text(c,status,Width*.08f,Height*.50f,14,white);
                Text(c,"BANKED SALVAGE: "+salvage+"      RUN SCORE: "+points,
                    Width*.08f,Height*.59f,14,white);
                string[] names={"HULL","WEAPON","REACTOR"};
                for(int i=0;i<3;i++)
                {
                    float column=Width/3f, left=i*column+8*density,top=Height*.53f;
                    FillRect(c,left,top,left+column-16*density,top+45*density,
                        Color.Argb(210,15,52,72));
                    Text(c,names[i]+" LV "+levels[i],left+10*density,top+21*density,13,cyan);
                    Text(c,levels[i]>=3?"MAX":("BUY "+(100*(levels[i]+1)*(levels[i]+1))),
                        left+10*density,top+38*density,10,white);
                }
                FillRect(c,Width*.08f,Height*.70f,Width*.53f,Height*.84f,
                    Color.Argb(233,17,63,81));
                Text(c,"GRAPHICS: "+new[]{"PERFORMANCE","BALANCED","QUALITY"}[
                    Math.Clamp(graphicsQuality,0,2)]+"  (TAP TO CHANGE)",
                    Width*.105f,Height*.79f,16,cyan);
                FillRect(c,Width*.60f,Height*.76f,Width*.89f,Height*.93f,
                    Color.Argb(246,41,115,139));
                Text(c,mode=="RESULT"?"RELAUNCH":"LAUNCH SORTIE",
                    Width*.745f,Height*.865f,21,white,true);
                Text(c,"7 SIGNALS  /  DRONES  /  WARDEN",Width*.08f,Height*.91f,13,faint);
            }
            PostInvalidateDelayed(250);
        }
    }
}