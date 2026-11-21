using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using Stride.Core.Mathematics;
using Stride.Engine;
using Stride.Input;
using Stride.Rendering;
using Stride.Rendering.Materials;
using Stride.Rendering.Materials.ComputeColors;
using Stride.Rendering.ProceduralModels;

namespace EclipseHollowSky
{
    // ECLIPSE: THE HOLLOW SKY -- first native Stride flight/combat sector.
    // No FPS map, gun, player-character physics, or test assets are instantiated.
    // This is arcade skiff flight, not road-locked movement.
    public sealed class EclipseDirector : SyncScript
    {
        private const int BeaconCount = 7;
        private const float BeaconSpacing = 125f;
        private Scene scene;
        private Entity ship;
        private Entity camera;
        private readonly Dictionary<string, Material> materials = new Dictionary<string, Material>();
        private readonly Dictionary<string, Model> primitives = new Dictionary<string, Model>();
        private readonly List<Beacon> beacons = new List<Beacon>();
        private readonly List<Hostile> hostiles = new List<Hostile>();
        private readonly List<Bolt> bolts = new List<Bolt>();
        private int[] upgrades = new int[3];
        private int bank, maxScore, score, salvage, gateIndex, hull, sector = 1;
        private float x, y, z, energy = 100f, timeLeft = 90f, shotCooldown, flashClock;
        private float tickHz = 60, messageTimer, benchElapsed;
        private int quality = 1;
        private string qualityPath;
        private readonly List<(Entity Root, float CenterZ, bool IsCloud)> streaming =
            new List<(Entity, float, bool)>();
        private string message = "HANGAR READY";
        private GameMode mode = GameMode.Splash;
        private int loadingStep;
        private float loadingProgress;
        private float transitionSeconds = 1.25f;
        private bool sortiePrepared;
        private string savePath;

        private enum GameMode { Splash, Loading, Menu, SortieLoading, Flight, Result }

        private sealed class Beacon
        {
            public Vector3 Center;
            public Entity Marker;
        }
        private sealed class Hostile
        {
            public Entity Root;
            public Vector3 Base;
            public int Health;
            public bool Boss;
        }
        private sealed class Bolt
        {
            public Entity Root;
            public float Life;
        }

        public override void Start()
        {
            scene = SceneSystem.SceneInstance.RootScene;
            camera = scene.Entities.FirstOrDefault(e => e.Name == "EclipseChaseCamera");
            savePath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "eclipse_hollow_sky_stride_progress.txt");
            LoadProgress();
            qualityPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "eclipse_stride_graphics_v3.txt");
            try
            {
                if (File.Exists(qualityPath) && int.TryParse(File.ReadAllText(qualityPath), out int saved))
                    quality = Math.Clamp(saved, 0, 2);
            }
            catch (IOException) { quality = 1; }
            // Keep the game paused while Android displays the Stride splash.
            // Scene construction runs in loading phases AFTER the splash.
            x = 0; y = 14; z = 18;
            message = "POWERED BY STRIDE";
            Publish();
        }

        private void CreateMaterials()
        {
            Palette("hull", 40, 65, 79, .72f, .72f);
            Palette("armor", 134, 163, 177, .82f, .66f);
            Palette("glass", 24, 74, 107, .40f, .94f);
            Palette("aether", 45, 221, 222, .10f, .89f);
            Palette("amber", 241, 146, 79, .34f, .82f);
            Palette("rock", 61, 81, 99, .06f, .23f);
            Palette("cliff", 97, 112, 132, .08f, .32f);
            Palette("ivory", 167, 180, 189, .30f, .48f);
            Palette("ruin", 78, 99, 115, .32f, .40f);
            Palette("cloud", 110, 102, 144, .02f, .29f);
            Palette("enemy", 172, 58, 60, .65f, .70f);
            Palette("elite", 147, 67, 192, .58f, .73f);
        }

        private void Palette(string name, byte r, byte g, byte b, float metal, float gloss)
        {
            var descriptor = new MaterialDescriptor
            {
                Attributes =
                {
                    Diffuse = new MaterialDiffuseMapFeature(new ComputeColor(new Color(r, g, b))),
                    DiffuseModel = new MaterialDiffuseLambertModelFeature(),
                    Specular = new MaterialMetalnessMapFeature(new ComputeFloat(metal)),
                    SpecularModel = new MaterialSpecularMicrofacetModelFeature(),
                    MicroSurface = new MaterialGlossinessMapFeature(new ComputeFloat(gloss))
                }
            };
            materials[name] = Material.New(Game.GraphicsDevice, descriptor, Game.Content);
        }

        private Model Primitive(string shape, string material)
        {
            string key = shape + ":" + material;
            if (primitives.TryGetValue(key, out var existing)) return existing;
            PrimitiveProceduralModelBase generator =
                shape == "sphere" ? (PrimitiveProceduralModelBase)new SphereProceduralModel()
                                  : new CubeProceduralModel();
            Model generated = generator.Generate(Game.Services);
            generated.Materials.Add(materials[material]);
            primitives.Add(key, generated);
            return generated;
        }

        private Entity Node(string label, string shape, string material, Vector3 position,
                            Vector3 size, Entity parent = null)
        {
            var entity = new Entity(label) { new ModelComponent(Primitive(shape, material)) };
            entity.Transform.Position = position;
            entity.Transform.Scale = size;
            if (parent != null)
                entity.Transform.Parent = parent.Transform;
            else
                scene.Entities.Add(entity);
            return entity;
        }
        private Entity Box(string label, string mat, float px, float py, float pz,
                           float sx, float sy, float sz, Entity parent = null) =>
            Node(label, "cube", mat, new Vector3(px, py, pz), new Vector3(sx, sy, sz), parent);
        private Entity Orb(string label, string mat, float px, float py, float pz,
                           float sx, float sy, float sz, Entity parent = null) =>
            Node(label, "sphere", mat, new Vector3(px, py, pz), new Vector3(sx, sy, sz), parent);

        private void CreateSky()
        {
            Orb("Eclipse / distant sun", "amber", -220, 170, -870, 45, 45, 45);
            var rng = new Random(23314);
            // Four shared cloud meshes replace 68 independent sphere submissions.
            for (int group = 0; group < 4; group++)
            {
                var b = new EclipseGeometry.Batch();
                for (int i = group * 17; i < (group + 1) * 17; i++)
                {
                    float cz = 40f - i * 19f;
                    float cx = (i % 2 == 0 ? -1 : 1) *
                        (49f + (float)rng.NextDouble() * 83f);
                    float cy = -26f + (float)rng.NextDouble() * 22f;
                    b.Cloud(cx, cy, cz, 24f + (float)rng.NextDouble() * 25f,
                        17f + (float)rng.NextDouble() * 25f);
                }
                var entity = b.Build("Layered cloudbank " + group, scene,
                    Game.GraphicsDevice, materials);
                streaming.Add((entity, 40f - (group * 17 + 8) * 19f, true));
            }
            ApplyQuality();
        }

        private void CreateSkiff()
        {
            ship = new Entity("THE AETHER SKIFF");
            scene.Entities.Add(ship);
            var build = new EclipseGeometry.Batch();
            build.Skiff();
            var visible = build.Build("Skiff / batched hard-surface chassis", scene,
                Game.GraphicsDevice, materials);
            visible.Transform.Parent = ship.Transform;
        }

        private Vector3 GateAt(int index)
        {
            float offsetX = MathF.Sin(index * 1.18f) * 21f + MathF.Cos(index * .62f) * 5f;
            float offsetY = 13f + MathF.Sin(index * 1.35f) * 7f;
            return new Vector3(offsetX, offsetY, -(index + 1) * BeaconSpacing);
        }

        private void CreateSector()
        {
            var rand = new Random(1002026);
            for (int index = 0; index < BeaconCount; index++)
            {
                Vector3 gate = GateAt(index);
                var mark = new Entity("SIGNAL " + (index + 1).ToString("00"));
                mark.Transform.Position = gate;
                scene.Entities.Add(mark);
                // Aether ring with open center for a free-flight skiff.
                Box("Gate top", "aether", 0, 10, 0, 29, .65f, 1.0f, mark);
                Box("Gate bottom", "aether", 0, -10, 0, 29, .65f, 1.0f, mark);
                Box("Gate left", "ivory", -15, 0, 0, 1.2f, 19.0f, 1.5f, mark);
                Box("Gate right", "ivory", 15, 0, 0, 1.2f, 19.0f, 1.5f, mark);
                Box("Left beacon", "amber", -15, 9.7f, 0, 2f, 2f, 2f, mark);
                Box("Right beacon", "amber", 15, 9.7f, 0, 2f, 2f, 2f, mark);
                beacons.Add(new Beacon { Center = gate, Marker = mark });
                SpawnHostile(gate + new Vector3(-11, 2, 45), false);
                SpawnHostile(gate + new Vector3(13, -3, 26), false);
                if (index == 4)
                    SpawnHostile(gate + new Vector3(0, 2, -35), true);
            }
            // Eight frustum-cullable sector chunks, each with one mesh per
            // shared material. Angular rock formations and temple ruins are
            // triangulated together instead of hundreds of object submissions.
            for (int group = 0; group < 8; group++)
            {
                var builder = new EclipseGeometry.Batch();
                for (int i = group * 5; i < (group + 1) * 5; i++)
                {
                    float wz = -17 - i * 24f;
                    float wx = (i % 2 == 0 ? -1 : 1) *
                        (31f + (float)rand.NextDouble() * 58f);
                    float wy = -6f + (float)rand.NextDouble() * 31f;
                    float size = 7f + (float)rand.NextDouble() * 10f;
                    builder.Island(wx, wy, wz, size, 100 + i * 13);
                }
                var root = builder.Build("Wind-cut islands " + group, scene,
                    Game.GraphicsDevice, materials);
                streaming.Add((root, -17f - (group * 5 + 2f) * 24f, false));
            }
            ApplyQuality();
        }

        private void SpawnHostile(Vector3 pos, bool elite)
        {
            var root = new Entity(elite ? "WARDEN" : "HUNTER DRONE");
            root.Transform.Position = pos;
            scene.Entities.Add(root);
            float size = elite ? 1.8f : 1f;
            Orb("Drone armored core", elite ? "elite" : "enemy", 0, 0, 0,
                1.8f * size, .8f * size, 2.0f * size, root);
            Box("Drone wing", "ruin", 0, -.12f, .15f,
                5.4f * size, .18f * size, 1.0f * size, root);
            Orb("Drone visor", "amber", 0, .10f, -1.0f * size,
                1.05f * size, .29f * size, .20f * size, root);
            for (int sign = -1; sign <= 1; sign += 2)
                Orb("Drone reactor", "aether", sign * 2.4f * size, -.13f, .85f * size,
                    .45f * size, .30f * size, .60f * size, root);
            hostiles.Add(new Hostile { Root = root, Base = pos, Health = elite ? 8 : 2, Boss = elite });
        }

        private void ApplyQuality()
        {
            float islandDistance = quality == 0 ? 270f : quality == 1 ? 470f : 830f;
            float cloudDistance = quality == 0 ? 330f : quality == 1 ? 620f : 950f;
            foreach (var chunk in streaming)
                chunk.Root.Get<ModelComponent>().Enabled =
                    Math.Abs(chunk.CenterZ - z) < (chunk.IsCloud ? cloudDistance : islandDistance);
            var sun = scene.Entities.FirstOrDefault(e => e.Name == "WarmLowSun");
            var direct = sun?.Get<LightComponent>()?.Type as Stride.Rendering.Lights.LightDirectional;
            if (direct != null) direct.Shadow.Enabled = quality == 2;
        }

        private void ChangeQuality()
        {
            quality = (quality + 1) % 3;
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(qualityPath));
                File.WriteAllText(qualityPath, quality.ToString(CultureInfo.InvariantCulture));
            }
            catch (IOException) { /* Gameplay can continue without persisting UI preferences. */ }
            ApplyQuality();
            // Stride 4.4 can resize its Android off-screen backbuffer. Keep
            // resolution and scenery distance as independent GPU budget levers.
            try
            {
                var graphics = Game.GraphicsDeviceManager;
                graphics.PreferredBackBufferWidth = quality == 0 ? 720 : quality == 1 ? 960 : 1280;
                graphics.PreferredBackBufferHeight = quality == 0 ? 405 : quality == 1 ? 540 : 720;
                graphics.ApplyChanges();
                message = "GRAPHICS " + new[] { "PERFORMANCE", "BALANCED", "QUALITY" }[quality];
            }
            catch (Exception)
            {
                message = "SCENERY QUALITY CHANGED - KEEPING DEVICE RESOLUTION";
            }
        }

        private void SetCraftTransform()
        {
            ship.Transform.Position = new Vector3(x, y, z);
            ship.Transform.Rotation = Quaternion.RotationYawPitchRoll(
                Math.Clamp(x / 110f, -.26f, .26f),
                0, -Math.Clamp(x / 76f, -.26f, .26f));
        }

        private void FollowCamera()
        {
            if (camera == null) return;
            camera.Transform.Position = new Vector3(x * .76f, y + 5.8f, z + 22f);
            camera.Transform.Rotation = Quaternion.RotationYawPitchRoll(0, -.115f, 0);
        }

        private void LoadProgress()
        {
            try
            {
                if (File.Exists(savePath))
                {
                    string[] parts = File.ReadAllText(savePath).Split(',');
                    if (parts.Length >= 5)
                    {
                        bank = Math.Max(0, int.Parse(parts[0], CultureInfo.InvariantCulture));
                        maxScore = Math.Max(0, int.Parse(parts[1], CultureInfo.InvariantCulture));
                        for (int i = 0; i < 3; i++)
                            upgrades[i] = Math.Clamp(int.Parse(parts[i + 2], CultureInfo.InvariantCulture), 0, 3);
                    }
                }
            }
            catch { bank = 0; maxScore = 0; upgrades = new int[3]; }
        }
        private void SaveProgress()
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(savePath));
                File.WriteAllText(savePath,
                    $"{bank},{maxScore},{upgrades[0]},{upgrades[1]},{upgrades[2]}");
            }
            catch { /* Never interrupt flight due to inaccessible storage. */ }
        }

        private void ResetSortie()
        {
            score = 0; salvage = 0; gateIndex = 0; sector = 1;
            hull = 3 + upgrades[0];
            x = 0; y = 14; z = 18;
            energy = 100 + upgrades[2] * 30;
            timeLeft = 90; shotCooldown = 0; message = "SIGNAL 01 / LAUNCH";
            messageTimer = 4f;
            foreach (var drone in hostiles)
            {
                drone.Health = drone.Boss ? 8 : 2;
                drone.Root.Transform.Scale = Vector3.One;
                drone.Root.Transform.Position = drone.Base;
            }
            foreach (var bolt in bolts) bolt.Root.Transform.Scale = Vector3.Zero;
            bolts.Clear();
            SetCraftTransform(); FollowCamera();
        }

        private void Complete(bool won)
        {
            if (mode != GameMode.Flight) return;
            mode = GameMode.Result;
            bank += salvage;
            maxScore = Math.Max(maxScore, score);
            SaveProgress();
            message = won ? "SECTOR CLEARED - SALVAGE BANKED" : "SKIFF LOST - SALVAGE BANKED";
            messageTimer = 99;
        }

        private void BuyUpgrade(int index)
        {
            if (index < 0 || index > 2 || upgrades[index] >= 3) return;
            int price = 100 * (upgrades[index] + 1) * (upgrades[index] + 1);
            if (bank < price)
            {
                message = "NOT ENOUGH SALVAGE";
                return;
            }
            bank -= price;
            upgrades[index]++;
            SaveProgress();
            message = new[] { "HULL REINFORCED", "PLASMA UPGRADED", "REACTOR ENHANCED" }[index];
        }

        private void SpawnBolt()
        {
            var bolt = Orb("Aether plasma bolt", "aether", x, y, z - 5f, .35f, .35f, 1.5f);
            bolts.Add(new Bolt { Root = bolt, Life = 1.85f });
        }

        private void RunCombat(float delta)
        {
            for (int i = bolts.Count - 1; i >= 0; i--)
            {
                Bolt bolt = bolts[i];
                bolt.Life -= delta;
                Vector3 pos = bolt.Root.Transform.Position;
                pos.Z -= delta * 160f;
                bolt.Root.Transform.Position = pos;
                bool hit = false;
                foreach (var drone in hostiles)
                {
                    if (drone.Health <= 0) continue;
                    Vector3 where = drone.Root.Transform.Position;
                    float radius = drone.Boss ? 5f : 3.2f;
                    if (Math.Abs(pos.Z - where.Z) < 3.0f &&
                        Math.Abs(pos.X - where.X) < radius &&
                        Math.Abs(pos.Y - where.Y) < radius)
                    {
                        drone.Health -= 1 + upgrades[1];
                        if (drone.Health <= 0)
                        {
                            drone.Root.Transform.Scale = Vector3.Zero;
                            score += drone.Boss ? 125 : 35;
                            salvage += drone.Boss ? 100 : 18;
                            message = drone.Boss ? "WARDEN DOWN" : "DRONE DESTROYED";
                            messageTimer = 1.4f;
                        }
                        hit = true;
                        break;
                    }
                }
                if (hit || bolt.Life <= 0)
                {
                    bolt.Root.Transform.Scale = Vector3.Zero;
                    bolts.RemoveAt(i);
                }
            }
            foreach (var drone in hostiles)
            {
                if (drone.Health <= 0) continue;
                if (Math.Abs(drone.Base.Z - z) > 105f) continue;
                Vector3 position = drone.Base;
                float oscillate = (float)Game.UpdateTime.Total.TotalSeconds;
                position.X += MathF.Sin(oscillate * .82f + drone.Base.Z) * 2.5f;
                position.Y += MathF.Cos(oscillate * .97f + drone.Base.Z) * 1.8f;
                drone.Root.Transform.Position = position;
                if (Math.Abs(z - position.Z) < 2.8f &&
                    Math.Abs(x - position.X) < (drone.Boss ? 5f : 3.5f) &&
                    Math.Abs(y - position.Y) < 3.5f && flashClock <= 0)
                {
                    hull--;
                    flashClock = 1.2f;
                    message = "HULL HIT";
                    messageTimer = 1.5f;
                    if (hull <= 0) Complete(false);
                }
            }
        }

        public override void Update()
        {
            float dt = (float)Game.UpdateTime.Elapsed.TotalSeconds;
            if (dt <= 0) return;
            dt = Math.Min(dt, .05f);
            tickHz = tickHz * .92f + .08f / dt;
            EclipseBridge.Input(out var stick, out bool fire, out bool boost,
                                out bool brake, out bool start, out int purchase, out bool cycleQuality);
            if (Input.IsKeyDown(Keys.A)) stick.X -= 1;
            if (Input.IsKeyDown(Keys.D)) stick.X += 1;
            if (Input.IsKeyDown(Keys.W)) stick.Y += 1;
            if (Input.IsKeyDown(Keys.S)) stick.Y -= 1;
            if (Input.IsKeyDown(Keys.Space)) boost = true;
            if (Input.IsKeyDown(Keys.LeftShift)) brake = true;
            if (Input.IsMouseButtonDown(MouseButton.Left)) fire = true;
            if (Input.IsKeyPressed(Keys.Enter)) start = true;
            if (mode == GameMode.Splash)
            {
                transitionSeconds -= dt;
                if (transitionSeconds <= 0f)
                {
                    mode = GameMode.Loading;
                    loadingStep = 0;
                    loadingProgress = 0f;
                    // Keep the real loading screen visible long enough to read
                    // even when the small procedural scene initializes quickly.
                    transitionSeconds = 0.85f;
                    message = "INITIALIZING THE HOLLOW SKY";
                }
                Publish();
                return;
            }

            if (mode == GameMode.Loading)
            {
                // This is actual scene initialization, not a decorative timer.
                // One phase is performed per update so Android can repaint the
                // progress screen between the expensive asset-creation phases.
                switch (loadingStep)
                {
                    case 0: message = "PREPARING MATERIALS"; CreateMaterials(); break;
                    case 1: message = "FORMING THE SKIES"; CreateSky(); break;
                    case 2: message = "ASSEMBLING AETHER SKIFF"; CreateSkiff(); break;
                    case 3: message = "BUILDING SECTOR 01"; CreateSector(); break;
                    case 4:
                        message = "CALIBRATING FLIGHT CAMERA";
                        SetCraftTransform();
                        FollowCamera();
                        break;
                    default:
                        transitionSeconds -= dt;
                        if (transitionSeconds <= 0f)
                        {
                            mode = GameMode.Menu;
                            message = "HANGAR READY - CHOOSE YOUR SORTIE";
                            loadingProgress = 1f;
                        }
                        else
                        {
                            message = "FINALIZING GAME WORLD";
                            loadingProgress = 0.97f;
                        }
                        Publish();
                        return;
                }
                loadingStep++;
                loadingProgress = Math.Clamp(loadingStep / 6f, 0f, 0.92f);
                Publish();
                return;
            }

            if (mode == GameMode.Menu || mode == GameMode.Result)
            {
                if (purchase >= 0) BuyUpgrade(purchase);
                if (cycleQuality) ChangeQuality();
                if (start)
                {
                    EclipseBridge.ReleaseAll();
                    mode = GameMode.SortieLoading;
                    sortiePrepared = false;
                    loadingProgress = 0f;
                    transitionSeconds = 0.90f;
                    message = "PREPARING SECTOR 01";
                }
                Publish();
                return;
            }

            if (mode == GameMode.SortieLoading)
            {
                if (!sortiePrepared)
                {
                    // Real sortie reset: enemies, ammo, skiff, gate progress,
                    // health and timers are all reset while the loader is shown.
                    ResetSortie();
                    sortiePrepared = true;
                    loadingProgress = 0.82f;
                    message = "CHECKING THRUSTERS AND WEAPONS";
                }
                transitionSeconds -= dt;
                if (transitionSeconds <= 0f)
                {
                    loadingProgress = 1f;
                    mode = GameMode.Flight;
                    message = "SIGNAL 01 - LAUNCH";
                    messageTimer = 2.8f;
                }
                Publish();
                return;
            }

            if (messageTimer > 0) messageTimer -= dt;
            if (flashClock > 0) flashClock -= dt;
            float speed = boost && energy >= 1f ? 60f : brake ? 17f : 35f;
            energy = Math.Clamp(energy + dt * (boost && speed > 35 ? -23 : 9),
                                0, 100 + upgrades[2] * 30);
            x = Math.Clamp(x + Math.Clamp(stick.X, -1, 1) * dt * 37f, -42f, 42f);
            y = Math.Clamp(y + Math.Clamp(stick.Y, -1, 1) * dt * 30f, -5f, 45f);
            z -= speed * dt;
            timeLeft -= dt;
            SetCraftTransform(); FollowCamera(); ApplyQuality();
            benchElapsed += dt;
            if (benchElapsed >= 10f)
            {
                benchElapsed = 0;
                // Output a compact per-device 10 second sample to app-private
                // storage, alongside visible HUD counters for screenshot QA.
                try
                {
                    string csv = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture) + "," +
                        quality + "," + Game.DrawTime.FramePerSecond.ToString("F1", CultureInfo.InvariantCulture) +
                        "," + Game.GraphicsDevice.FrameDrawCalls + "," +
                        Game.GraphicsDevice.FrameTriangleCount + "," +
                        (GC.GetTotalMemory(false) / (1024 * 1024)) + Environment.NewLine;
                    File.AppendAllText(Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                        "eclipse_stride_v3_benchmark.csv"), csv);
                }
                catch (IOException) { /* No file access must never end a sortie. */ }
            }
            shotCooldown -= dt;
            if (fire && shotCooldown <= 0)
            {
                SpawnBolt();
                shotCooldown = .25f / (1f + upgrades[1] * .15f);
            }
            RunCombat(dt);
            if (mode != GameMode.Flight) { Publish(); return; }
            if (gateIndex < beacons.Count && z < beacons[gateIndex].Center.Z)
            {
                Vector3 gate = beacons[gateIndex].Center;
                if (Math.Abs(x - gate.X) <= 13.7f && Math.Abs(y - gate.Y) <= 9.6f)
                {
                    score += 100;
                    salvage += 22;
                    energy = Math.Min(100 + upgrades[2] * 30, energy + 22);
                    message = "SIGNAL " + (gateIndex + 1).ToString("00") + " SECURED";
                }
                else
                {
                    hull--;
                    message = "SIGNAL MISSED - HULL DAMAGE";
                }
                messageTimer = 2.6f;
                gateIndex++;
                if (gateIndex >= BeaconCount) Complete(true);
                else if (gateIndex > 0) sector = 1 + gateIndex / 4;
            }
            if (hull <= 0 || timeLeft <= 0) Complete(false);
            Publish();
        }

        private void Publish()
        {
            string current = mode switch
            {
                GameMode.Splash => "SPLASH",
                GameMode.Loading => "LOADING",
                GameMode.Menu => "MENU",
                GameMode.SortieLoading => "SORTIE_LOADING",
                GameMode.Flight => "FLIGHT",
                _ => "RESULT"
            };
            string line = mode == GameMode.Flight && messageTimer <= 0f
                ? "FOLLOW THE SIGNALS" : message;
            EclipseBridge.Publish(current, line, hull, energy, Math.Max(0, timeLeft),
                                  tickHz, Game.DrawTime.FramePerSecond,
                                  (float)Game.UpdateTime.TimePerFrame.TotalMilliseconds,
                                  (int)Game.GraphicsDevice.FrameDrawCalls,
                                  (int)Game.GraphicsDevice.FrameTriangleCount,
                                  GC.GetTotalMemory(false) / (1024f * 1024f),
                                  quality, score, bank, gateIndex, sector, upgrades,
                                  loadingProgress);
        }
    }
}