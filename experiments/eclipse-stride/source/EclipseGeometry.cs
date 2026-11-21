using System;
using System.Collections.Generic;
using Stride.Core.Mathematics;
using Stride.Engine;
using Stride.Graphics;
using Stride.Rendering;

namespace EclipseHollowSky
{
    // V3: build one draw mesh per material per sector chunk instead of hundreds
    // of independent procedural spheres, cubes and draw submissions.
    internal static class EclipseGeometry
    {
        internal sealed class Batch
        {
            private readonly Dictionary<string, List<VertexPositionNormalTexture>> vertices =
                new Dictionary<string, List<VertexPositionNormalTexture>>();
            private readonly Dictionary<string, List<int>> indices =
                new Dictionary<string, List<int>>();

            public void Triangle(string material, Vector3 a, Vector3 b, Vector3 c)
            {
                Vector3 normal = Vector3.Cross(b - a, c - a);
                if (normal.LengthSquared() < 0.000001f) return;
                normal.Normalize();
                if (!vertices.TryGetValue(material, out var list))
                {
                    list = new List<VertexPositionNormalTexture>();
                    vertices.Add(material, list);
                    indices.Add(material, new List<int>());
                }
                int start = list.Count;
                list.Add(new VertexPositionNormalTexture(a, normal, new Vector2(0, 0)));
                list.Add(new VertexPositionNormalTexture(b, normal, new Vector2(1, 0)));
                list.Add(new VertexPositionNormalTexture(c, normal, new Vector2(1, 1)));
                indices[material].Add(start);
                indices[material].Add(start + 1);
                indices[material].Add(start + 2);
            }

            public void Quad(string mat, Vector3 a, Vector3 b, Vector3 c, Vector3 d)
            {
                Triangle(mat, a, b, c);
                Triangle(mat, a, c, d);
            }

            public void Box(string mat, float x, float y, float z, float w, float h, float d)
            {
                float l=x-w*.5f, r=x+w*.5f, b=y-h*.5f, t=y+h*.5f,
                    n=z-d*.5f, f=z+d*.5f;
                Quad(mat,new Vector3(l,b,n),new Vector3(l,t,n),new Vector3(r,t,n),new Vector3(r,b,n));
                Quad(mat,new Vector3(r,b,f),new Vector3(r,t,f),new Vector3(l,t,f),new Vector3(l,b,f));
                Quad(mat,new Vector3(l,t,n),new Vector3(l,t,f),new Vector3(r,t,f),new Vector3(r,t,n));
                Quad(mat,new Vector3(l,b,f),new Vector3(l,b,n),new Vector3(r,b,n),new Vector3(r,b,f));
                Quad(mat,new Vector3(r,b,n),new Vector3(r,t,n),new Vector3(r,t,f),new Vector3(r,b,f));
                Quad(mat,new Vector3(l,b,f),new Vector3(l,t,f),new Vector3(l,t,n),new Vector3(l,b,n));
            }

            // An angular, wind-cut floating island; the tapered underside is real
            // triangulated rock geometry, not a stretched sphere.
            public void Island(float x, float y, float z, float radius, int seed)
            {
                const int sides = 10;
                float[] heights = { .26f, .09f, -.22f, -.57f, -1.27f };
                float[] widths = { .57f, 1.05f, .91f, .61f, .11f };
                Vector3 At(int ring, int i)
                {
                    float angle=(float)(Math.PI*2*i/sides);
                    float noise=1f+.11f*MathF.Sin(i*2.72f+seed)+
                        .075f*MathF.Cos(i*4.13f+seed*.27f);
                    return new Vector3(
                        x+MathF.Cos(angle)*radius*widths[ring]*noise,
                        y+radius*heights[ring]+.12f*radius*MathF.Sin(i*1.32f+seed),
                        z+MathF.Sin(angle)*radius*widths[ring]*noise);
                }
                for (int ring=0; ring<4; ring++)
                for (int i=0; i<sides; i++)
                {
                    int next=(i+1)%sides;
                    string mat = ring < 2 ? "rock" : "cliff";
                    Quad(mat,At(ring,i),At(ring,next),At(ring+1,next),At(ring+1,i));
                }
                var summit=new Vector3(x,y+radius*.31f,z);
                for(int i=0;i<sides;i++)
                    Triangle("rock",summit,At(0,(i+1)%sides),At(0,i));
                // Ruined sky temples have stronger readable silhouettes than
                // piles of pipes. All the pieces share their parent chunk mesh.
                float deck=y+radius*.26f;
                Box("ivory",x,deck,z,radius*1.02f,.68f,radius*.79f);
                Box("ruin",x,deck+.62f,z-radius*.26f,radius*.80f,.33f,radius*.18f);
                for(int s=-1;s<=1;s+=2)
                {
                    float px=x+s*radius*.32f;
                    Box("ruin",px,deck+3.4f,z,1.3f,6.2f,1.35f);
                    Box("ivory",px,deck+6.8f,z,1.75f,.58f,1.72f);
                    Crystal(px,deck+8f,z,1.4f,2.1f);
                }
                Box("ruin",x,deck+6.85f,z,radius*.82f,.55f,1.60f);
            }

            public void Crystal(float x,float y,float z,float radius,float height)
            {
                Vector3 top=new Vector3(x,y+height,z), bottom=new Vector3(x,y-height*.56f,z);
                for(int i=0;i<6;i++)
                {
                    float a=(float)(i*Math.PI/3), b=(float)((i+1)*Math.PI/3);
                    var l=new Vector3(x+radius*MathF.Cos(a),y,z+radius*MathF.Sin(a));
                    var r=new Vector3(x+radius*MathF.Cos(b),y,z+radius*MathF.Sin(b));
                    Triangle("aether",top,r,l);
                    Triangle("aether",bottom,l,r);
                }
            }

            public void Cloud(float x,float y,float z,float rx,float rz)
            {
                // Flat, softly stepped 12-sided atmospheric geometry.
                const int sides=12;
                Vector3 Center(float elevation) => new Vector3(x,y+elevation,z);
                Vector3 Edge(int i,float width,float elevation)
                {
                    float a=(float)(i*Math.PI*2/sides);
                    return new Vector3(x+MathF.Cos(a)*rx*width,
                        y+elevation+MathF.Sin(i*2.12f)*.3f,
                        z+MathF.Sin(a)*rz*width);
                }
                for(int i=0;i<sides;i++)
                {
                    int next=(i+1)%sides;
                    Triangle("cloud",Center(1.2f),Edge(next,.70f,1.2f),Edge(i,.70f,1.2f));
                    Quad("cloud",Edge(i,.70f,1.2f),Edge(next,.70f,1.2f),
                        Edge(next,1f,-.8f),Edge(i,1f,-.8f));
                    Quad("cloud",Edge(i,1f,-.8f),Edge(next,1f,-.8f),
                        Edge(next,.65f,-2.1f),Edge(i,.65f,-2.1f));
                }
            }

            public void Wing(string mat,float sign)
            {
                // A stepped swept planform, extruded with actual thickness.
                Vector3[] upper = {
                    new Vector3(sign*.72f,.06f,-1.28f),
                    new Vector3(sign*2.0f,.03f,-.6f),
                    new Vector3(sign*4.45f,-.13f,.83f),
                    new Vector3(sign*4.20f,-.16f,1.38f),
                    new Vector3(sign*1.02f,.05f,1.58f)
                };
                Vector3[] lower=new Vector3[upper.Length];
                for(int i=0;i<upper.Length;i++)
                    lower[i]=upper[i]-new Vector3(0,.22f,0);
                for(int i=1;i<upper.Length-1;i++)
                {
                    Triangle(mat,upper[0],upper[i],upper[i+1]);
                    Triangle(mat,lower[i+1],lower[i],lower[0]);
                }
                for(int i=0;i<upper.Length;i++)
                {
                    int next=(i+1)%upper.Length;
                    Quad(mat,upper[i],upper[next],lower[next],lower[i]);
                }
            }

            public void Skiff()
            {
                // Consolidated engineered player craft: batched armor panels,
                // sharp wings, visible cockpit and twin thrusters.
                Box("hull",0,-.05f,.30f,1.55f,.60f,4.40f);
                Box("armor",0,.24f,-.9f,1.15f,.29f,3.35f);
                Box("hull",0,-.12f,-3.06f,.80f,.34f,2.24f);
                Box("armor",0,.44f,-.60f,1.13f,.38f,1.88f);
                Box("glass",0,.72f,-1.10f,.84f,.23f,1.43f);
                Box("aether",0,.87f,-1.12f,.055f,.045f,1.60f);
                Wing("hull",-1f);
                Wing("hull",1f);
                Box("armor",0,.1f,2.0f,5.7f,.12f,.42f);
                Box("armor",0,.4f,2.3f,1.6f,.29f,1.2f);
                Box("hull",0,-.32f,1.05f,1.00f,.34f,3.00f);
                for(int side=-1;side<=1;side+=2)
                {
                    float sx=side*2.05f;
                    Box("armor",sx,-.22f,1.05f,.82f,.52f,2.75f);
                    Box("hull",sx,-.19f,2.24f,.67f,.59f,1.55f);
                    Box("aether",sx,-.22f,3.06f,.50f,.42f,.18f);
                    Box("amber",sx,.04f,-.24f,.29f,.08f,.67f);
                    Box("aether",side*3.0f,-.035f,.72f,1.4f,.06f,.17f);
                    Box("ruin",side*4.04f,.015f,1.1f,.26f,.31f,.7f);
                }
                Box("ivory",0,.35f,-3.15f,.41f,.08f,.91f);
                Box("aether",0,-.33f,-3.88f,.33f,.10f,.45f);
            }

            public Entity Build(string label, Scene scene, GraphicsDevice device,
                                Dictionary<string,Material> materials)
            {
                var model=new Model();
                Vector3 globalMin=new Vector3(float.MaxValue), globalMax=new Vector3(float.MinValue);
                foreach(var group in vertices)
                {
                    if(group.Value.Count==0) continue;
                    var array=group.Value.ToArray();
                    var ib=Stride.Graphics.Buffer.Index.New(device,indices[group.Key].ToArray());
                    var vb=Stride.Graphics.Buffer.Vertex.New(device,array);
                    Vector3 min=new Vector3(float.MaxValue), max=new Vector3(float.MinValue);
                    foreach(var vertex in array)
                    {
                        min=Vector3.Min(min,vertex.Position);
                        max=Vector3.Max(max,vertex.Position);
                    }
                    globalMin=Vector3.Min(globalMin,min);
                    globalMax=Vector3.Max(globalMax,max);
                    var mesh=new Mesh
                    {
                        MaterialIndex=model.Materials.Count,
                        BoundingBox=new BoundingBox(min,max),
                        Draw=new MeshDraw
                        {
                            PrimitiveType=PrimitiveType.TriangleList,
                            DrawCount=indices[group.Key].Count,
                            IndexBuffer=new IndexBufferBinding(ib,true,indices[group.Key].Count),
                            VertexBuffers=new [] {new VertexBufferBinding(vb,
                                VertexPositionNormalTexture.Layout,array.Length)}
                        }
                    };
                    model.Materials.Add(materials[group.Key]);
                    model.Meshes.Add(mesh);
                }
                model.BoundingBox=new BoundingBox(globalMin,globalMax);
                model.BoundingSphere=BoundingSphere.FromBox(model.BoundingBox);
                var entity=new Entity(label) { new ModelComponent(model) };
                scene.Entities.Add(entity);
                return entity;
            }
        }
    }
}
