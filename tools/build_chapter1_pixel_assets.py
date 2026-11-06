"""Original chapter props. Explicit world-size face UVs, 2px extrusion, no noise.
Only writes art/story/chapter1. Does not read or import reverse-engineered art.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import math, json, re

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/story/chapter1'
DENSITY=32

def vadd(a,b): return tuple(x+y for x,y in zip(a,b))
def vsub(a,b): return tuple(x-y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def length(v): return math.sqrt(sum(x*x for x in v))
def normal(points):
    n=cross(vsub(points[1],points[0]),vsub(points[2],points[0])); d=length(n)
    return tuple(x/d for x in n)

def box(center,size,color,role='panel',bevel=False,tilt_x=0):
    h=[x/2 for x in size]; faces=[]
    b=min(.022,min(size)*.14) if bevel else 0
    inner=[x-b for x in h]
    def face(points): faces.append({'points':[vadd(center,p) for p in points],'color':color,'role':role})
    for axis in range(3):
        axes=[i for i in range(3) if i!=axis]
        for sign in [-1,1]:
            points=[]
            for s,t in [(-1,-1),(1,-1),(1,1),(-1,1)]:
                p=[0.,0.,0.]; p[axis]=sign*h[axis]; p[axes[0]]=s*inner[axes[0]]; p[axes[1]]=t*inner[axes[1]]; points.append(tuple(p))
            if normal(points)[axis]*sign<0: points.reverse()
            face(points)
    if b:
        # Twelve bevel strips plus eight corners, not arbitrary extra subdivisions.
        for along in range(3):
            a,c=[i for i in range(3) if i!=along]
            for sa in [-1,1]:
                for sc in [-1,1]:
                    pts=[]
                    for direction,outer in [(-1,True),(1,True),(1,False),(-1,False)]:
                        p=[0.,0.,0.];p[along]=direction*inner[along]
                        p[a]=sa*(h[a] if outer else inner[a]);p[c]=sc*(inner[c] if outer else h[c]);pts.append(tuple(p))
                    n=normal(pts)
                    if n[a]*sa+n[c]*sc<0: pts.reverse()
                    face(pts)
        for sx in [-1,1]:
            for sy in [-1,1]:
                for sz in [-1,1]:
                    pts=[(sx*h[0],sy*inner[1],sz*inner[2]),(sx*inner[0],sy*h[1],sz*inner[2]),(sx*inner[0],sy*inner[1],sz*h[2])]
                    if sum(a*b for a,b in zip(normal(pts),(sx,sy,sz)))<0:pts.reverse()
                    face(pts)
    if tilt_x:
        c,s=math.cos(tilt_x),math.sin(tilt_x)
        for f in faces:
            points=[]
            for p in f['points']:
                x,y,z=vsub(p,center)
                points.append(vadd(center,(x,y*c-z*s,y*s+z*c)))
            f['points']=points
    return faces

def export(name,faces):
    OUT.mkdir(parents=True,exist_ok=True)
    if not name.startswith('camera_'):
        base_y=min(p[1] for f in faces for p in f['points'])
        for f in faces:
            f['points']=[(p[0],p[1]-base_y,p[2]) for p in f['points']]
    elif name=='camera_mount':
        back_z=min(p[2] for f in faces for p in f['points'])
        for f in faces:
            f['points']=[(p[0],p[1],p[2]-back_z) for p in f['points']]
    width=256; x=y=2; row=0
    for f in faces:
        p=f['points']; horizontal=length(vsub(p[1],p[0])); vertical=length(vsub(p[-1],p[0]))
        # Orthogonal quads and bevel strips use exactly their physical face spans.
        f['size']=(max(1,round(horizontal*DENSITY)),max(1,round(vertical*DENSITY)))
        w,h=f['size']
        if x+w+2>width: x=2;y+=row+4;row=0
        f['rect']=(x,y,w,h);x+=w+4;row=max(row,h)
    height=32
    while height<y+row+2:height*=2
    image=Image.new('RGB',(width,height),(28,34,43));glow=Image.new('RGB',image.size)
    obj=['# Original FiveMinuteMore chapter asset; 1 unit = 1 metre.']; index=1; audits=[]; triangles=0
    for f in faces:
        px,py,w,h=f['rect']; n=normal(f['points']); base=f['color']
        # Material separation is deliberate; no baked directional shadow blobs.
        factor=1.20 if n[1]>.6 else .55 if n[1]<-.6 else .78 if abs(n[0])>.5 else 1.
        color=tuple(min(255,round(c*255*factor)) for c in base)
        tile=Image.new('RGB',(w,h),color);d=ImageDraw.Draw(tile)
        seam=tuple(round(c*.78) for c in color)
        light=tuple(min(255,round(c*1.32)) for c in color)
        if w>=9 and h>=9:
            d.line([(2,h-3),(w-3,h-3)],fill=seam,width=1)
            if f['role'] in ['monitor','housing','cabinet','drawer']:
                d.line([(w-3,2),(w-3,h-3)],fill=seam,width=1)
                if n[1]<.5:d.rectangle((3,max(2,h//2),min(w-4,8),max(2,h//2)+1),fill=(172,181,181))
            if f['role']=='housing' and n[1]>.5:
                for j in range(3):d.line([(3,3+j*2),(min(w-4,9),3+j*2)],fill=seam)
            if f['role']=='fabric' and w>20:d.line([(3,3),(w-4,3)],fill=seam)
            if f['role']=='keyboard' and n[1]>.6:
                for yy in range(3,min(h-3,10),2):
                    for xx in range(3,w-3,3):d.rectangle((xx,yy,min(xx+1,w-3),yy),fill=seam)
            # Two short wear marks, kept on a structural edge rather than all-over noise.
            if w>24 and h>16:d.point((w-4,2),fill=tuple(min(255,c+13) for c in color))
        # Semantic parts, deliberately sparse. No baked light or all-over noise.
        role=f['role']
        if role in ['pillow','duvet','cuff','rug'] and min(w,h)>=6:
            d.rectangle((1,1,w-2,h-2),outline=light if role=='cuff' else seam)
            if role=='pillow' and n[1]>.6:
                d.line((w//3,h//2,2*w//3,h//2),fill=seam)
            if role=='duvet' and n[1]>.6:
                band=max(2,min(4,h//8));d.rectangle((1,1,w-2,band),fill=light)
                for xx in [w//3,2*w//3]:d.line((xx,h//2,xx,min(h-3,h//2+4)),fill=seam)
            if role=='rug':d.rectangle((3,3,w-4,h-4),outline=light)
        if role in ['wardrobe_door','drawer'] and w>=10 and h>=12 and abs(n[2])>.6:
            d.rectangle((1,1,w-2,h-2),outline=seam)
            if role=='wardrobe_door':
                for yy in [4,6,8]:d.line((4,yy,w-5,yy),fill=seam)
                d.rectangle((3,h-8,min(w-4,10),h-6),fill=(134,144,150))
        if role=='book' and min(w,h)>=3:
            d.rectangle((1,2,w-2,min(h-2,4)),fill=(178,183,180))
        if role=='toolbox' and min(w,h)>=5:
            d.line((1,h//2,w-2,h//2),fill=seam)
            d.rectangle((w//2,h//2,w//2+1,min(h-2,h//2+2)),fill=(182,191,196))
        if role=='worktop' and n[1]>.6 and min(w,h)>8:
            d.line((2,h-3,w-3,h-3),fill=(153,130,78))
            d.rectangle((3,3,min(w-4,12),min(h-4,8)),outline=seam)
        if role=='lcd' and min(w,h)>=6:
            d.rectangle((0,0,w-1,h-1),fill=(29,51,66))
            d.rectangle((1,1,w-2,h-2),outline=(92,151,172))
            d.line((2,3,w-3,3),fill=(152,199,204))
            for yy in range(5,h-2,3):d.line((3,yy,max(3,w-5-(yy%3)),yy),fill=(102,170,187))
        if role=='housing' and min(w,h)>=7 and abs(n[2])>.6:
            d.rectangle((2,2,w-3,h-3),outline=seam)
        if role=='wood' and min(w,h)>=8:
            for yy in range(4,h-3,7):
                start=3+(yy%5); end=max(start,w-4-(yy%7))
                d.line((start,yy,end,yy),fill=tuple(round(c*.91) for c in color))
            if n[1]>.6:d.line((1,1,w-2,1),fill=light)
        if role=='pillow' and n[1]>.6 and min(w,h)>=8:
            d.ellipse((1,1,w-2,h-2),fill=color,outline=seam)
            d.ellipse((3,2,w-4,h-3),fill=light)
            d.line((w//3,h-4,2*w//3,h-4),fill=seam)
        if role in ['duvet','cuff'] and n[1]>.6 and min(w,h)>=8:
            for row in [h//3,2*h//3]:
                for xx in range(2,w-2):
                    yy=row+int(math.sin(xx*.16)*1.5)
                    d.point((xx,yy),fill=seam);d.point((xx,min(h-2,yy+1)),fill=light)
            d.rectangle((1,1,w-2,min(3,h-2)),fill=light)
            d.line((1,min(4,h-2),w-2,min(4,h-2)),fill=seam)
        if role=='recess':
            d.rectangle((0,0,w-1,h-1),fill=tuple(round(c*.48) for c in color))
        if role in ['drawer','wardrobe_door'] and min(w,h)>=7:
            d.line((2,2,w-3,2),fill=seam);d.line((2,h-3,w-3,h-3),fill=light)
        if role=='toolbox' and w>=5 and h>=3:
            for yy in [h//3,2*h//3]:d.line((1,yy,w-2,yy),fill=seam)
            d.point((w//2,h//2),fill=(187,192,191))
        if role=='worktop' and n[1]>.6 and min(w,h)>=10:
            d.rectangle((w//4,h//3,3*w//4,h-4),fill=(41,55,61))
            for xx in range(w//4+2,3*w//4,4):d.line((xx,h//3+1,xx,h-5),fill=(47,63,68))
        if n[1]>.6 and min(w,h)>=6 and role not in ['lcd','led','rug','recess']:
            d.line((1,1,w-2,1),fill=light)
        for yy in range(-2,h+2):
            for xx in range(-2,w+2):image.putpixel((px+xx,py+yy),tile.getpixel((min(w-1,max(0,xx)),min(h-1,max(0,yy)))))
        if f['role'] in ['lcd','led']:
            glow.paste(tile,(px,py))
        points=f['points'];uv=[(0,0),(1,0),(1,1),(0,1)] if len(points)==4 else [(0,0),(1,0),(0,1)]
        for p,(u,v) in zip(points,uv):
            obj.append('v %.7f %.7f %.7f'%p)
            obj.append('vt %.8f %.8f'%((px+.5+u*max(0,w-1))/width,1-(py+.5+v*max(0,h-1))/height))
            obj.append('vn %.7f %.7f %.7f'%n)
        for k in range(1,len(points)-1):
            obj.append('f '+' '.join(f'{i}/{i}/{i}' for i in [index,index+k,index+k+1]));triangles+=1
        index+=len(points)
        audits.append({'pixels':[w,h],'metres':[length(vsub(points[1],points[0])),length(vsub(points[-1],points[0]))],'rect':[px,py,w,h]})
    (OUT/f'{name}.obj').write_text('\n'.join(obj)+'\n',encoding='utf-8')
    image.save(OUT/f'{name}.png');glow.save(OUT/f'{name}_emission.png')
    mat=f'''[gd_resource type="StandardMaterial3D" load_steps=3 format=3]
[ext_resource type="Texture2D" path="res://art/story/chapter1/{name}.png" id="1"]
[ext_resource type="Texture2D" path="res://art/story/chapter1/{name}_emission.png" id="2"]
[resource]
albedo_texture = ExtResource("1")
metallic = 0.0
metallic_specular = 0.0
roughness = 0.88
texture_filter = 0
emission_enabled = true
emission_operator = 1
emission_texture = ExtResource("2")
emission = Color(1, 1, 1, 1)
emission_energy_multiplier = 0.5
'''
    (OUT/f'{name}.tres').write_text(mat,encoding='utf-8')
    return {'asset':name,'triangles':triangles,'atlas':[width,height],'padding':2,'faces':audits}

def bedroom_assets():
    import_recipe=ROOT/'tools/chapter1_pixel_asset_recipe.json'
    if import_recipe.exists():
        groups=json.loads(import_recipe.read_text(encoding='utf-8'))
        return [export('bedroom_'+kind,[f for p in parts for f in box(**p)]) for kind,parts in groups.items()]
    text=(ROOT/'scenes/story/chapter_bedroom.tscn').read_text(encoding='utf-8')
    sizes={m[0]:tuple(float(x) for x in m[1].split(',')) for m in re.findall(r'\[sub_resource type="BoxMesh" id="([^"]+)"\]\nsize = Vector3\(([^)]+)\)',text)}
    colors={m[0]:tuple(float(x) for x in m[1].split(',')[:3]) for m in re.findall(r'\[sub_resource type="StandardMaterial3D" id="([^"]+)"\]\nalbedo_color = Color\(([^)]+)\)',text)}
    groups={}
    for name,parent,body in re.findall(r'\[node name="([^"]+)" type="MeshInstance3D" parent="(Furniture/[^"/]+)"\]\n(.*?)(?=\n\[|\Z)',text,re.S):
        pos=re.search(r'position = Vector3\(([^)]+)\)',body);mesh=re.search(r'mesh = SubResource\("([^"]+)"\)',body);mat=re.search(r'material_override = SubResource\("([^"]+)"\)',body)
        if not all([pos,mesh,mat]):continue
        point=tuple(float(x) for x in pos[1].split(','));size=sizes[mesh[1]];color=colors[mat[1]]
        kind=parent.split('/')[-1].lower();scale=(.8,.9,.72) if kind=='bed' else (1,1,1)
        point=tuple(a*b for a,b in zip(point,scale));size=tuple(a*b for a,b in zip(size,scale))
        role='lcd' if name=='LCD' else 'fabric' if mat[1] in ['Mat_linen','Mat_blanket','Mat_rug'] else 'cabinet' if kind in ['wardrobe','nightstand','shelf'] else 'panel'
        groups.setdefault(kind,[]).append(dict(center=point,size=size,color=color,role=role,bevel=min(size)>.1))
    groups['wardrobe'].append(dict(center=(0,.04,.48),size=(1.75,.08,.11),color=(.40,.44,.49),role='panel',bevel=False))
    for y in [.6,1.5]:groups['shelf'].append(dict(center=(.35,y,0),size=(.06,.08,1.8),color=(.40,.44,.49),role='panel',bevel=False))
    import_recipe.write_text(json.dumps(groups,indent=2),encoding='utf-8')
    return [export('bedroom_'+kind,[f for p in parts for f in box(**p)]) for kind,parts in groups.items()]

def main():
    report=bedroom_assets()
    import sys
    if '--bedroom-only' in sys.argv:
        audit_path=OUT/'asset_audit.json'
        prior=json.loads(audit_path.read_text(encoding='utf-8')) if audit_path.exists() else {'density':32,'assets':[]}
        prior['assets']=[a for a in prior['assets'] if not a['asset'].startswith('bedroom_')]+report
        audit_path.write_text(json.dumps(prior,indent=2),encoding='utf-8')
        print('BEDROOM_ASSETS',len(report))
        return
    steel=(.43,.49,.55);edge=(.56,.61,.65);dark=(.075,.10,.14)
    head=box((0,0,0),(.44,.27,.64),(.24,.29,.35),'housing',True)
    head+=box((0,.15,.20),(.52,.055,.36),(.62,.68,.73),'panel')
    head+=box((0,0,.329),(.29,.15,.027),dark,'panel')
    head+=box((.17,-.07,.35),(.045,.035,.02),(.70,.10,.16),'led')
    report.append(export('camera_head',head))
    mount=box((0,0,0),(.12,.45,.13),steel)
    a=[(-.06,-.18,0),(-.06,-.18,.40),(-.06,.05,0)]; b=[(.06,y,z) for _,y,z in a]
    for pts in [a,list(reversed(b)),[a[0],b[0],b[1],a[1]],[a[1],b[1],b[2],a[2]],[a[2],b[2],b[0],a[0]]]:mount.append({'points':pts,'color':steel,'role':'panel'})
    report.append(export('camera_mount',mount))
    parts=[]
    for x in [-.6,.6]:parts+=box((x,.38,0),(.11,.76,.68),steel,'panel',True)
    parts+=box((0,.82,0),(1.5,.14,.85),edge,'worktop',True)
    parts+=box((0,.62,-.31),(1.3,.28,.10),steel,'drawer',True)
    parts+=box((.30,1.04,-.22),(.55,.32,.12),dark,'monitor',True)
    parts+=box((.30,1.04,-.15),(.44,.23,.014),(.24,.48,.60),'lcd')
    parts+=box((.25,.91,.16),(.52,.045,.23),steel,'panel')
    parts+=box((-.44,.96,.07),(.30,.24,.30),(.44,.16,.15),'toolbox',True)
    parts+=box((-.13,1.03,-.22),(.25,.24,.12),dark,'monitor',True)
    parts+=box((-.13,1.03,-.15),(.18,.15,.014),(.24,.48,.60),'lcd')
    for x in [.12,.48]:parts+=box((x,.94,-.13),(.04,.04,.05),edge,'panel')
    report.append(export('workbench',parts))
    (OUT/'asset_audit.json').write_text(json.dumps({'density':32,'source':'Original procedural face painting, no reverse-engineered files','assets':report},indent=2),encoding='utf-8')
    print([(r['asset'],r['triangles'],r['atlas']) for r in report])
if __name__=='__main__':main()
