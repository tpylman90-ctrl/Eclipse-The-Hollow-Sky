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
        private float tickHz = 60, messageTimer;
        private string message = "HANGAR READY";
        private GameMode mode = GameMode.Hangar;
        private string savePath;

        private enum GameMode { Hangar, Flight, Result }

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
            CreateMaterials();
            CreateSky();
            CreateSkiff();
            CreateSector();
            x = 0; y = 14; z = 18;
            SetCraftTransform();
            FollowCamera();
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
            // Distant sun + cloud banks: scale is worldspace, deliberately sparse
            // for Android GPU limits. Lighting comes from this scene's sun and fill.
            Orb("Eclipse / far sun", "amber", -220, 170, -870, 45, 45, 45);
            Random rng = new Random(23314);
            for (int i = 0; i < 68; i++)
            {
                float cz = 40f - i * 19f;
                float cx = (i % 2 == 0 ? -1 : 1) * (47f + (float)rng.NextDouble() * 80f);
                float cy = -28f + (float)rng.NextDouble() * 22f;
                Orb("Violet cloudbank " + i, "cloud", cx, cy, cz,
                    23f + (float)rng.NextDouble() * 24f,
                    4f + (float)rng.NextDouble() * 9f,
                    13f + (float)rng.NextDouble() * 19f);
            }
        }

        private void CreateSkiff()
        {
            ship = new Entity("THE AETHER SKIFF");
            scene.Entities.Add(ship);
            // Distinctive swept wings, twin booster nacelles, armor and canopy.
            Box("Fuselage", "hull", 0, 0, -.3f, 1.6f, .45f, 4.9f, ship);
            Box("Armored spine", "armor", 0, .27f, -.55f, 1.05f, .20f, 3.3f, ship);
            Box("Tapered snout", "armor", 0, -.12f, -3.25f, .83f, .28f, 2.0f, ship);
            Box("Keel", "hull", 0, -.3f, 1.1f, .92f, .31f, 3.0f, ship);
            Orb("Canopy", "glass", 0, .51f, -.55f, .73f, .42f, 1.56f, ship);
            Box("Canopy ridge", "aether", 0, .90f, -.57f, .045f, .04f, 1.90f, ship);
            Box("Wing left", "hull", -2.55f, -.13f, .54f, 4.0f, .11f, 1.8f, ship);
            Box("Wing right", "hull", 2.55f, -.13f, .54f, 4.0f, .11f, 1.8f, ship);
            Box("Rear stabilizer", "armor", 0, .11f, 2.22f, 5.0f, .12f, .35f, ship);
            for (int side = -1; side <= 1; side += 2)
            {
                float px = side * 2.65f;
                Box("Outer pod", "armor", px, -.17f, 1.0f, .85f, .45f, 2.45f, ship);
                Box("Engine cowling", "hull", side * 1.38f, -.26f, 2.10f, .70f, .58f, 1.47f, ship);
                Orb("Aether plume", "aether", side * 1.38f, -.27f, 2.97f, .34f, .31f, .81f, ship);
                Box("Wing accent", "aether", side * 2.2f, .01f, .12f, 1.93f, .035f, .21f, ship);
                Box("Nose emitter", "amber", side * .45f, .02f, -4.12f, .30f, .10f, .10f, ship);
            }
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
            // Freestanding rock islands with ruin columns, wind-carved bridges,
            // crystals and open air between. No invisible track/road exists.
            for (int i = 0; i < 40; i++)
            {
                float wz = -17 - i * 24f;
                float wx = (i % 2 == 0 ? -1 : 1) * (31f + (float)rand.NextDouble() * 58f);
                float wy = -6f + (float)rand.NextDouble() * 31f;
                float scale = 7f + (float)rand.NextDouble() * 10f;
                Orb("Floating rock mass", "rock", wx, wy, wz, scale, scale * .47f, scale * .94f);
                Orb("Cliff underside", "cliff", wx, wy - scale * .37f, wz, scale * .61f, scale * .73f, scale * .66f);
                Box("Ruin platform", "ivory", wx, wy + scale * .36f, wz,
                    scale * 1.05f, .95f, scale * .78f);
                for (int k = 0; k < 2; k++)
                {
                    float dx = (k == 0 ? -1 : 1) * scale * .32f;
                    Box("Ancient pillar", "ruin", wx + dx, wy + scale * .36f + 3.5f, wz,
                        1.7f, 7.0f + (i % 3), 1.8f);
                    Orb("Aether crystal", "aether", wx + dx, wy + scale * .36f + 7.3f, wz,
                        .9f, 2.5f, .9f);
                }
            }
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
            messageTimer = 4f; mode = GameMode.Flight;
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
                                out bool brake, out bool start, out int purchase);
            if (Input.IsKeyDown(Keys.A)) stick.X -= 1;
            if (Input.IsKeyDown(Keys.D)) stick.X += 1;
            if (Input.IsKeyDown(Keys.W)) stick.Y += 1;
            if (Input.IsKeyDown(Keys.S)) stick.Y -= 1;
            if (Input.IsKeyDown(Keys.Space)) boost = true;
            if (Input.IsKeyDown(Keys.LeftShift)) brake = true;
            if (Input.IsMouseButtonDown(MouseButton.Left)) fire = true;
            if (Input.IsKeyPressed(Keys.Enter)) start = true;
            if (mode != GameMode.Flight)
            {
                if (purchase >= 0) BuyUpgrade(purchase);
                if (start) ResetSortie();
                FollowCamera();
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
            SetCraftTransform(); FollowCamera();
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
            string current = mode == GameMode.Hangar ? "HANGAR" :
                             mode == GameMode.Result ? "RESULT" : "FLIGHT";
            EclipseBridge.Publish(current, messageTimer > 0 ? message : "FOLLOW THE SIGNALS",
                                  hull, energy, Math.Max(0, timeLeft), tickHz, score, bank,
                                  gateIndex, sector, upgrades);
        }
    }
}