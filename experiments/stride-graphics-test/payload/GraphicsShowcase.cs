// Stride Android PBR graphics trial. Adds a small hard-surface hovercraft
// and six PBR material samples to the existing playable FPS test scene.
// Assets and original Godot game stay untouched. No paid external assets.
using System;
using System.Collections.Generic;
using Stride.Core.Mathematics;
using Stride.Engine;
using Stride.Rendering;
using Stride.Rendering.Materials;
using Stride.Rendering.Materials.ComputeColors;
using Stride.Rendering.ProceduralModels;

namespace StrideGraphicsTest.GraphicsTrial
{
    public sealed class GraphicsShowcase : StartupScript
    {
        private readonly Dictionary<string, Material> palette = new Dictionary<string, Material>();
        private readonly Dictionary<string, Model> shared = new Dictionary<string, Model>();
        private Scene scene;

        public override void Start()
        {
            scene = SceneSystem.SceneInstance.RootScene;
            if (scene == null) return;
            Surface("dark",   28, 34, 43, 0.45f, 0.45f);
            Surface("paint",  22, 115, 153, 0.65f, 0.88f);
            Surface("trim",  235, 112, 42, 0.40f, 0.88f);
            Surface("steel", 158, 178, 190, 0.90f, 0.78f);
            Surface("black",  18, 31, 49, 0.70f, 0.94f);
            Surface("glass",  27, 54, 78, 0.35f, 0.96f);
            Surface("glow",   62, 224, 250, 0.16f, 0.84f);
            Surface("stone",  118, 109, 96, 0.05f, 0.19f);
            Surface("matte",  175, 179, 184, 0.00f, 0.20f);
            Surface("gloss",  175, 179, 184, 0.00f, 0.94f);
            Surface("chrome", 202, 218, 232, 1.00f, 0.97f);
            Surface("copper", 188, 99, 48, 1.00f, 0.74f);

            // Display stand at the near end of the existing room.
            Box("Showcase base", "dark", -7.5f, .18f, 5.4f, 10.8f, .32f, 9.1f);
            Box("Left guide", "trim", -12.7f, .38f, 5.4f, .09f, .04f, 8.7f);
            Box("Right guide", "glow", -2.3f, .38f, 5.4f, .09f, .04f, 8.7f);
            Box("Rear guide", "steel", -7.5f, .38f, 9.75f, 10.4f, .04f, .08f);

            // Faceted hover body with side sponsons, canopy, nacelles and vents.
            Box("Hull", "paint", -7.5f, 1.37f, 5.2f, 2.50f, .57f, 5.35f);
            Box("Keel", "black", -7.5f, 1.08f, 5.35f, 1.9f, .27f, 5.0f);
            Box("Armored nose", "steel", -7.5f, 1.31f, 2.25f, 1.90f, .43f, 1.34f);
            Box("Nose intake", "black", -7.5f, 1.55f, 2.20f, .46f, .045f, 1.06f);
            Ball("Canopy", "glass", -7.5f, 1.91f, 5.40f, 1.42f, .80f, 2.12f);
            Box("Canopy ridge", "black", -7.5f, 2.25f, 5.38f, .18f, .10f, 1.77f);
            Box("Tail wing", "steel", -7.5f, 1.87f, 8.17f, 6.05f, .12f, .47f);
            Box("Tail stripe", "trim", -7.5f, 1.96f, 8.17f, 5.90f, .035f, .10f);
            for (int side = -1; side <= 1; side += 2)
            {
                float x = -7.5f + side * 2.30f;
                Box("Side engine", "black", x, 1.22f, 5.44f, 1.18f, .56f, 5.35f);
                Box("Side armor", "paint", x, 1.55f, 4.9f, 1.28f, .20f, 3.95f);
                Box("Front flare", "trim", -7.5f + side * 1.55f, 1.38f, 3.82f, 1.15f, .15f, 1.5f);
                Box("Nozzle ring", "steel", x, 1.26f, 8.55f, 1.16f, .63f, .40f);
                Box("Nozzle center", "glow", x, 1.26f, 8.80f, .68f, .37f, .10f);
                Box("Headlight", "glow", -7.5f + side * .72f, 1.32f, 1.53f, .42f, .09f, .06f);
                for (int v = 0; v < 3; v++)
                    Box("Side vent", "black", x, 1.68f, 4.15f + v * .50f, .70f, .04f, .16f);
            }

            // Side-by-side PBR roughness and metalness comparison.
            string[] names = { "matte", "gloss", "stone", "steel", "chrome", "copper" };
            for (int i = 0; i < names.Length; i++)
            {
                float x = -14.0f + i * 3.65f;
                Box("Swatch pedestal", "dark", x, .34f, -5.3f, 2.45f, .65f, 2.45f);
                Box("Swatch highlight", "glow", x, .68f, -5.3f, 2.30f, .05f, 2.30f);
                Ball("PBR " + names[i], names[i], x, 1.55f, -5.3f, 1.5f, 1.5f, 1.5f);
            }

            // Stones and pylons diversify geometry, roughness, and shadows.
            Random random = new Random(190);
            for (int i = 0; i < 18; i++)
            {
                float x = 5.0f + (float)random.NextDouble() * 8.0f;
                float z = -4f + (float)random.NextDouble() * 11.0f;
                float diameter = .5f + (float)random.NextDouble() * 1.25f;
                Ball("Rock", "stone", x, diameter * .24f, z,
                     diameter, diameter * .50f, diameter * .85f);
            }
            for (int i = 0; i < 6; i++)
            {
                float z = -3f + 3.0f * i;
                Box("Pylon", "black", 12.1f, 1.45f, z, .50f, 2.90f, .55f);
                Box("Pylon accent", i % 2 == 0 ? "glow" : "trim", 12.1f, 2.36f, z - .29f, .37f, .12f, .04f);
            }
        }

        private void Surface(string name, byte r, byte g, byte b, float metal, float gloss)
        {
            var descriptor = new MaterialDescriptor
            {
                Attributes =
                {
                    Diffuse = new MaterialDiffuseMapFeature(new ComputeColor(new Color(r, g, b))),
                    DiffuseModel = new MaterialDiffuseLambertModelFeature(),
                    Specular = new MaterialMetalnessMapFeature(new ComputeFloat(metal)),
                    SpecularModel = new MaterialSpecularMicrofacetModelFeature(),
                    MicroSurface = new MaterialGlossinessMapFeature(new ComputeFloat(gloss)),
                }
            };
            palette.Add(name, Material.New(Game.GraphicsDevice, descriptor, Game.Content));
        }

        private Model ModelFor(bool sphere, string material)
        {
            string key = (sphere ? "sphere:" : "cube:") + material;
            if (shared.TryGetValue(key, out var model)) return model;
            PrimitiveProceduralModelBase primitive = sphere
                ? (PrimitiveProceduralModelBase)new SphereProceduralModel()
                : new CubeProceduralModel();
            model = primitive.Generate(Game.Services);
            model.Materials.Add(palette[material]);
            shared.Add(key, model);
            return model;
        }

        private void Box(string name, string material, float x, float y, float z, float sx, float sy, float sz)
            => Add(name, material, false, x, y, z, sx, sy, sz);

        private void Ball(string name, string material, float x, float y, float z, float sx, float sy, float sz)
            => Add(name, material, true, x, y, z, sx, sy, sz);

        private void Add(string name, string material, bool sphere, float x, float y, float z, float sx, float sy, float sz)
        {
            var entity = new Entity("PBR Trial / " + name) { new ModelComponent(ModelFor(sphere, material)) };
            entity.Transform.Position = new Vector3(x, y, z);
            entity.Transform.Scale = new Vector3(sx, sy, sz);
            scene.Entities.Add(entity);
        }
    }
}
