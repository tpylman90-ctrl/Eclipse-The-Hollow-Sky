"""Eclipse asset foundry: original, deterministic Blender -> AO-baked atlases -> GLB.
Runs headlessly in GitHub Actions. Geometry is authored offline, never per game frame.
All meshes/materials are generated for this project; no external asset licenses.
"""
import bpy
import math
import os
import json
import random
import argparse
import sys
from mathutils import Vector

def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for item in list(bpy.data.materials):
        bpy.data.materials.remove(item)

def paint(name, rgb, metallic=0.0, roughness=0.7):
    m=bpy.data.materials.new(name)
    m.use_nodes=True
    m['atlas_rgb']=list(rgb)
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Metallic'].default_value=metallic
    p.inputs['Roughness'].default_value=roughness
    # Surface breakup is baked, not sampled procedurally on a phone.
    noise=m.node_tree.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value=6
    ramp=m.node_tree.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position=.14
    ramp.color_ramp.elements[0].color=(*(min(1,c*.78) for c in rgb),1)
    ramp.color_ramp.elements[1].position=.90
    ramp.color_ramp.elements[1].color=(*(min(1,c*1.1) for c in rgb),1)
    m.node_tree.links.new(noise.outputs['Fac'],ramp.inputs['Fac'])
    m.node_tree.links.new(ramp.outputs['Color'],p.inputs['Base Color'])
    return m

def cube(name,loc,scale,mat,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    ob=bpy.context.object
    ob.name=name
    ob.dimensions=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    ob.data.materials.append(mat)
    if bevel:
        mod=ob.modifiers.new('machined_chamfer','BEVEL')
        mod.width=bevel
        mod.segments=1
        bpy.context.view_layer.objects.active=ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob

def polygon_solid(name,points,thickness,mat):
    # points in Blender horizontal XY plane; a solid, not a single-sided card.
    n=len(points)
    vs=[(x,y,-thickness*.5) for x,y in points]+[(x,y,thickness*.5) for x,y in points]
    fs=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vs,[],fs);mesh.update()
    ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob

def cylinder(name,loc,radius,depth,mat,vertices=12,axis='Z'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    ob=bpy.context.object;ob.name=name;ob.data.materials.append(mat)
    if axis=='Y': ob.rotation_euler[0]=math.pi/2
    return ob

def create_ship():
    clear()
    navy=paint('Eclipse forged titanium',(.12,.19,.26),.72,.32)
    armor=paint('Warm ceramic armor',(.46,.57,.64),.35,.42)
    glass=paint('Deep cockpit glass',(.025,.17,.24),.34,.22)
    carbon=paint('Anodized black',(.018,.035,.052),.28,.58)
    glow=paint('Aether cyan',(.14,.78,.9),.06,.22)
    copper=paint('Signal copper',(.8,.34,.12),.53,.34)
    # Blender Z points up, while minus Y is the craft's forward nose.
    sections=[(-4.5,.27,.17),(-3.6,.62,.29),(-2.45,.83,.36),
              (-1.1,.94,.47),(.4,.91,.50),(1.7,.84,.47),(3.05,.70,.41)]
    vertices=[]
    for yy,w,h in sections:
        for x,z in [(-w,-h),(-w*.94,h*.45),(-w*.53,h),(w*.53,h),(w*.94,h*.45),(w,-h)]:
            vertices.append((x,yy,z))
    faces=[]
    for idx in range(len(sections)-1):
        for j in range(6):
            a=idx*6+j;b=idx*6+(j+1)%6
            faces.append((a,b,b+6,a+6))
    faces.extend([tuple(range(5,-1,-1)),tuple((len(sections)-1)*6+j for j in range(6))])
    mesh=bpy.data.meshes.new('Six-facet armor fuselage');mesh.from_pydata(vertices,[],faces);mesh.update()
    ob=bpy.data.objects.new('Fuselage cast',mesh);bpy.context.collection.objects.link(ob);ob.data.materials.append(navy)
    cube('Nose leading plate',(0,-3.76,.11),(.47,1.35,.16),armor,.045)
    cube('Spine channel',(0,-.92,.49),(.24,2.55,.10),carbon,.03)
    cube('Pilot armor collar',(0,-.12,.54),(1.29,1.85,.28),armor,.08)
    cube('Canopy dark', (0,-.66,.72),(.95,1.58,.49),glass,.19)
    cube('Canopy dividing bar',(0,-1.14,1.01),(.046,1.16,.07),glow,.018)
    # Aerodynamic, thick, swept-wing geometry instead of broad rectangular blocks.
    for side in (-1,1):
        wing=[(side*.62,-1.72),(side*1.55,-1.05),(side*4.80,.65),
              (side*4.61,1.41),(side*2.48,1.19),(side*.85,2.10)]
        ob=polygon_solid('Forged swept wing '+str(side),wing,.23,navy)
        ob.location.z=-.12
        wingtip=polygon_solid('Wingtip copper trim '+str(side),
                             [(side*4.26,.59),(side*4.80,.72),(side*4.61,1.41),(side*4.32,1.34)],.055,copper)
        wingtip.location.z=.025
        cube('Wing inner armor '+str(side),(side*1.64,.46,.06),(1.12,2.0,.17),armor,.06)
        for n in range(6):
            cube('Engine gill %s-%s'%(side,n),(side*(1.35+.14*n),1.14+.15*n,.24),
                 (.085,.36,.06),carbon,.01)
        # Heavy twin thruster nacelles, visible exhaust rings, and housings.
        cube('Outer thruster %s'%side,(side*2.47,1.95,-.28),(.79,2.65,.86),carbon,.14)
        cube('Pod armor %s'%side,(side*2.47,1.78,.16),(.90,1.86,.32),armor,.075)
        cylinder('Rear exhaust housing %s'%side,(side*2.47,3.39,-.28),.43,.35,navy,20,'Y')
        cylinder('Rear ion core %s'%side,(side*2.47,3.58,-.28),.29,.10,glow,20,'Y')
        cube('Aether side trim %s'%side,(side*2.49,.20,.23),(.09,1.28,.065),glow,.02)
        cube('Intake frame %s'%side,(side*.93,-2.06,-.03),(.18,.62,.43),carbon,.035)
        cube('Canard wing %s'%side,(side*1.11,-2.24,-.19),(1.01,.57,.12),armor,.035)
    cube('Aft bridge',(0,2.26,.32),(3.92,.35,.24),armor,.08)
    cube('Rear dorsal pod',(0,2.48,.55),(1.22,1.0,.30),navy,.08)
    for x in (-.57,.57):
        for n in range(7):
            cube('Vented panel', (x,-1.40+n*.25,.57),(.068,.12,.04),carbon,.012)
    return 'EclipseSkiff',1024

def create_island():
    clear()
    rock=paint('Metamorphic fractured rock',(.19,.25,.34),.03,.91)
    lighter=paint('Exposed mineral edges',(.31,.37,.43),.01,.91)
    temple=paint('Ancient limestone and concrete',(.51,.56,.58),.02,.84)
    dark=paint('Cut granite',(.17,.22,.29),.03,.86)
    copper=paint('Weathered copper',(.50,.29,.15),.50,.53)
    crystal=paint('Etherium crystal',(.09,.7,.80),.20,.38)
    rng=random.Random(51884)
    # Several intersecting tapered strata, with irregular rings and no holes.
    segments=22
    rings=[(-7.6,.11),(-5.5,.38),(-3.6,.63),(-1.7,.89),(0,1.10),(1.1,.97),(1.85,.71)]
    vs=[]
    for ring,(height,scale) in enumerate(rings):
        for i in range(segments):
            a=(2*math.pi*i/segments)
            wobble=1+.14*math.sin(a*5+ring*.52)+.09*math.cos(a*9+.17*ring)
            radial=scale*wobble
            vs.append((math.cos(a)*8.5*radial,math.sin(a)*6.9*radial,
                       height+(.20*math.sin(a*7+ring*1.1))))
    fs=[]
    for k in range(len(rings)-1):
        for i in range(segments):
            j=(i+1)%segments
            fs.append((k*segments+i,k*segments+j,(k+1)*segments+j,(k+1)*segments+i))
    fs.append(tuple((len(rings)-1)*segments+i for i in range(segments)))
    mesh=bpy.data.meshes.new('Continuous sculpted island profile')
    mesh.from_pydata(vs,[],fs);mesh.update()
    island=bpy.data.objects.new('Floating island / sculpted basalt',mesh)
    bpy.context.collection.objects.link(island);mesh.materials.append(rock)
    # Strata plates and isolated rocks add useful shadow/baked detail.
    for i in range(25):
        a=rng.random()*math.tau
        r=(.30+.60*rng.random())
        rad=6*r
        xx=math.cos(a)*rad;yy=math.sin(a)*rad*.81
        cube('Basalt stratified ledge',(xx,yy,-.9+rng.random()*1.5),
             (1.4+rng.random()*2.2,1.3+rng.random()*2, .18+rng.random()*.45),
             lighter,.075)
    # Temple foundations and an actual raised accessible-looking courtyard.
    cube('Upper temple deck',(0,0,2.05),(9.8,7.35,.62),temple,.17)
    cube('Terrace inlay',(0,0,2.40),(8.5,6.35,.09),dark,.045)
    for side in (-1,1):
        for i in range(4):
            xx=side*4.15;yy=-2.60+i*1.68
            cylinder('Fluted temple tower',(xx,yy,4.52),.51,4.0,temple,12)
            cylinder('Temple plinth',(xx,yy,2.68),.69,.46,dark,12)
            cube('Temple capital',(xx,yy,6.53),(1.27,1.18,.46),copper,.045)
        cube('Ruined temple top beam',(side*4.15,0,6.86),(.87,6.5,.42),temple,.085)
    # Courtyard altar, hanging fixtures, and temple front arch.
    cube('Altar deck',(0,0,2.70),(3.5,2.25,.38),temple,.06)
    cube('Relic base',(0,0,3.16),(1.75,1.40,.56),dark,.035)
    cylinder('Sky crystal pylon',(0,0,4.68),.65,2.80,crystal,8)
    for s in (-1,1):
        cube('Sky beacon',(s*2.88,-2.62,4.85),(.58,.58,2.8),copper,.07)
        cylinder('Aether beacon cap',(s*2.88,-2.62,6.35),.38,.75,crystal,8)
    return 'EclipseIsland',768


def raster_fallback(ob,size):
    """Per-face UV/colour/AO raster fallback for headless Blender bugs.
    All work happens offline in Actions, not on the Android device.
    """
    import numpy as np
    rgb=np.zeros((size,size,4),dtype=np.float32)
    occl=np.zeros((size,size,4),dtype=np.float32)
    rgb[:,:,3]=1.;occl[:,:,3]=1.
    uvdata=ob.data.uv_layers.active.data
    coverage=0
    for polygon in ob.data.polygons:
        if len(polygon.loop_indices)!=3: continue
        p=[uvdata[i].uv for i in polygon.loop_indices]
        points=[(q.x*(size-1),q.y*(size-1)) for q in p]
        x0=max(0,int(math.floor(min(q[0] for q in points))))
        y0=max(0,int(math.floor(min(q[1] for q in points))))
        x1=min(size,int(math.ceil(max(q[0] for q in points)))+1)
        y1=min(size,int(math.ceil(max(q[1] for q in points)))+1)
        if x1<=x0 or y1<=y0:continue
        (ax,ay),(bx,by),(cx,cy)=points
        den=(by-cy)*(ax-cx)+(cx-bx)*(ay-cy)
        if abs(den)<1e-6:continue
        yy,xx=np.mgrid[y0:y1,x0:x1]
        wx=((by-cy)*(xx-cx)+(cx-bx)*(yy-cy))/den
        wy=((cy-ay)*(xx-cx)+(ax-cx)*(yy-cy))/den
        wz=1.-wx-wy
        inside=(wx>=-.00001)&(wy>=-.00001)&(wz>=-.00001)
        if not np.any(inside):continue
        coverage+=int(np.count_nonzero(inside))
        mat=ob.data.materials[polygon.material_index]
        col=mat.get('atlas_rgb',[.38,.53,.64])
        face=max(0.,min(1.,polygon.normal.z))
        exposure=.84+.16*face
        # Low-amplitude machined and stone surface variation.
        noise=.94+.06*np.sin(xx*.21+yy*.37)
        area=rgb[y0:y1,x0:x1]
        for k in range(3):
            plane=area[:,:,k]
            plane[inside]=np.clip(float(col[k])*exposure*noise[inside],.02,1.)
        ao_region=occl[y0:y1,x0:x1]
        factor=.66+.31*face
        for k in range(3):
            plane=ao_region[:,:,k];plane[inside]=factor
    if coverage<=size*size*.005:
        raise RuntimeError('UV raster fallback covered too few texels')
    return rgb,occl

def bake_atlas(ob,basename,size,out_dir):
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=12
    scene.render.bake.use_clear=True
    scene.render.bake.margin=8
    # Fresh shared UV atlas; the final GLB has only one sampled material.
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(island_margin=.025)
    bpy.ops.object.mode_set(mode='OBJECT')

    def target(name):
        im=bpy.data.images.new(name,size,size,alpha=False)
        for mat in ob.data.materials:
            mat.use_nodes=True
            nodes=mat.node_tree.nodes
            tex=nodes.new('ShaderNodeTexImage')
            tex.name='BAKE_TARGET_'+name
            tex.image=im
            for node in nodes:node.select=False
            tex.select=True;nodes.active=tex
        return im
    base=target('COLOR')
    # Color only; no baked direct/indirect from an arbitrary studio light.
    bpy.ops.object.bake(type='DIFFUSE',pass_filter={'COLOR'})
    base.filepath_raw=os.path.join(out_dir,basename+'_color.png')
    base.file_format='PNG';base.save()
    ambient=target('AO')
    bpy.ops.object.bake(type='AO')
    ambient.filepath_raw=os.path.join(out_dir,basename+'_ao.png')
    ambient.file_format='PNG';ambient.save()
    # On some Ubuntu Blender builds Cycles returns an entirely black bake
    # for a densely joined hard-surface mesh even with valid UV coordinates.
    # Detect it and compute a guaranteed usable offline UV atlas instead.
    if max(list(base.pixels[:])[0::4]) < .04:
        print('BAKE FAILURE DETECTED:',basename,'- applying offline UV material raster fallback')
        baked_color,baked_ao=raster_fallback(ob,size)
        base.pixels.foreach_set(baked_color.ravel())
        ambient.pixels.foreach_set(baked_ao.ravel())
        base.save();ambient.save()
    # AO multiplied into the color atlas conservatively, to preserve the
    # dynamic sunlight response in Stride while cheaply adding crevice depth.
    color_pix=list(base.pixels[:]);ao_pix=list(ambient.pixels[:])
    for i in range(0,len(color_pix),4):
        occlusion=min(1,max(0,ao_pix[i]))
        factor=.56+.44*occlusion
        color_pix[i]*=factor
        color_pix[i+1]*=factor
        color_pix[i+2]*=factor
    final=bpy.data.images.new(basename+'_baked',size,size,alpha=False)
    final.pixels[:]=color_pix
    final.filepath_raw=os.path.join(out_dir,basename+'_albedo_ao.png')
    final.file_format='PNG';final.save()
    if max(list(final.pixels[:])[0::4]) < .04:
        raise RuntimeError(basename+' output atlas is black')
    baked=bpy.data.materials.new('BAKED')
    baked.use_nodes=True
    nodes=baked.node_tree.nodes
    principled=nodes.get('Principled BSDF')
    principled.inputs['Metallic'].default_value=.17 if 'Island' in basename else .53
    principled.inputs['Roughness'].default_value=.80 if 'Island' in basename else .44
    tex=nodes.new('ShaderNodeTexImage');tex.image=final;tex.interpolation='Linear'
    baked.node_tree.links.new(tex.outputs['Color'],principled.inputs['Base Color'])
    ob.data.materials.clear()
    ob.data.materials.append(baked)

def render_preview(ob,name,out_dir):
    scene=bpy.context.scene
    camera_data=bpy.data.cameras.new('QA Preview Camera')
    cam=bpy.data.objects.new('QA Preview Camera',camera_data)
    bpy.context.collection.objects.link(cam);scene.camera=cam
    if name=='EclipseSkiff': cam.location=(13,-20,11);target=Vector((0,0,0));cam.data.type='ORTHO';cam.data.ortho_scale=17
    else: cam.location=(22,-25,16);target=Vector((0,0,0));cam.data.type='ORTHO';cam.data.ortho_scale=24
    direction=target-Vector(cam.location)
    cam.rotation_euler=direction.to_track_quat('-Z','Y').to_euler()
    for xyz,energy,size in [((-9,-12,22),1300,11),((8,6,13),950,8)]:
        data=bpy.data.lights.new('Preview softbox','AREA')
        light=bpy.data.objects.new('Preview softbox',data)
        bpy.context.collection.objects.link(light)
        light.location=xyz;data.energy=energy;data.shape='DISK';data.size=size
    scene.world.color=(.09,.12,.20)
    scene.render.resolution_x=960;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.cycles.samples=16
    for layer in scene.view_layers:
        if hasattr(layer.cycles,'use_denoising'):
            layer.cycles.use_denoising=False
    scene.render.image_settings.file_format='PNG'
    scene.render.filepath=os.path.join(out_dir,name+'_preview.png')
    bpy.ops.render.render(write_still=True)

def make_asset(factory,out_dir):
    name,size=factory()
    originals=[o for o in bpy.context.scene.objects if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for ob in originals: ob.select_set(True)
    bpy.context.view_layer.objects.active=originals[0]
    bpy.ops.object.join()
    ob=bpy.context.object;ob.name=name
    # Export and bake on the exact triangulated final mobile mesh.
    mod=ob.modifiers.new('Android triangles','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bake_atlas(ob,name,size,out_dir)
    render_preview(ob,name,out_dir)
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True);bpy.context.view_layer.objects.active=ob
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir,name+'.glb'),
                              export_format='GLB',use_selection=True,export_apply=True)
    # Blender-created input is validated by counts and UV integrity.
    if not ob.data.uv_layers.active:raise RuntimeError(name+' missing UVs')
    tris=len(ob.data.polygons)
    if tris<150 or tris>35000:raise RuntimeError(name+' unexpected triangles: '+str(tris))
    return dict(asset=name,triangles=tris,vertices=len(ob.data.vertices),
                textures=[name+'_albedo_ao.png',name+'_ao.png'],
                glb=name+'.glb',preview=name+'_preview.png',atlas_px=size)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--out',required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out=os.path.abspath(args.out)
    os.makedirs(out,exist_ok=True)
    results=[make_asset(create_ship,out),make_asset(create_island,out)]
    manifest=dict(blender=bpy.app.version_string,source='original Eclipse assets',
                  bake='CPU Cycles diffuse color + ambient occlusion',assets=results)
    with open(os.path.join(out,'manifest.json'),'w') as f:json.dump(manifest,f,indent=2)
    print('ECLIPSE ASSET FOUNDRY COMPLETE:',json.dumps(manifest,indent=2))
if __name__=='__main__':main()
