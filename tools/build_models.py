"""Original Marine Outpost asset pack. Run: blender -b --python tools/build_models.py"""
import bpy, math, random, sys
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parents[1]/'models'; OUT.mkdir(exist_ok=True)
random.seed(17)
M={}
def material(name,color,metal=.0,rough=.5,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 M[name]=m
for args in [('armor',(.12,.21,.27),.45,.36),('steel',(.36,.44,.48),.65,.3),('dark',(.025,.04,.055),.35,.5),('rubber',(.02,.025,.03),0,.85),('copper',(.48,.25,.1),.65,.36),('ivory',(.62,.66,.59),.3,.42),('cyan',(.1,.7,.83),.2,.25,1.1),('orange',(.9,.33,.045),.15,.4),('yellow',(.85,.62,.14),.1,.6),('violet',(.44,.21,.75),.2,.35),('frost',(.3,.7,.87),.1,.22,.7),('red',(.75,.055,.025),.1,.35,.6),('skin',(.19,.24,.14),0,.78),('flesh',(.20,.018,.024),0,.6),('bone',(.66,.63,.43),0,.65),('cloth',(.11,.14,.12),0,.92),('asphalt',(.055,.07,.085),0,.95),('concrete',(.22,.26,.28),0,.9),('blood',(.15,.015,.02),0,.48)]: material(*args)
# Combat asset palette: distinguish weapon families by their painted hulls.
for args in [('olive',(.11,.15,.095),.35,.6),('ceramic',(.32,.38,.36),.25,.65),('sand',(.22,.16,.10),.3,.65),('necrotic',(.16,.18,.15),0,.9),('sinew',(.13,.018,.022),0,.7)]: material(*args)
# Grey-green cadaver skin; reserve saturation for wound interiors.
material('skin',(.14,.17,.13),0,.88)
root=None

def empty(name,pos=(0,0,0),parent=None):
 n=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(n);n.location=pos;n.parent=parent
 return n

def finish(obj,name,mat,parent=None,bevel=0):
 obj.name=name;obj.data.materials.append(M[mat]);obj.parent=parent or root
 if bevel:
  mod=obj.modifiers.new('Machined edge bevel','BEVEL');mod.width=bevel;mod.segments=2
  mod=obj.modifiers.new('Face weighted normals','WEIGHTED_NORMAL')
 return obj

def box(name,p,s,mat='armor',parent=None,bevel=.035,rot=(0,0,0)):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.rotation_euler=rot
 return finish(o,name,mat,parent,bevel)

def cyl(name,p,r,d,mat='steel',parent=None,axis=(0,0,1),vertices=20,r2=None):
 if r2 is None:bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d,location=p)
 else:bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r2,depth=d,location=p)
 o=bpy.context.object;o.rotation_euler=Vector((0,0,1)).rotation_difference(Vector(axis)).to_euler()
 for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
 return finish(o,name,mat,parent,.008)

def ball(name,p,s,mat='skin',parent=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,radius=1,location=p);o=bpy.context.object;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for f in o.data.polygons:f.use_smooth=True
 return finish(o,name,mat,parent)

def torus(name,p,r,t,mat='steel',parent=None,rot=(0,0,0)):
 bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=t,major_segments=24,minor_segments=8,location=p,rotation=rot)
 return finish(bpy.context.object,name,mat,parent)

def link(name,a,b,r,mat='steel',parent=None):
 mid=(Vector(a)+Vector(b))/2;return cyl(name,mid,r,(Vector(b)-Vector(a)).length,mat,parent,Vector(b)-Vector(a))

def text(name,p,body,size,mat='ivory',rot=(0,0,0),parent=None):
 bpy.ops.object.text_add(location=p,rotation=rot);o=bpy.context.object;o.data.body=body;o.data.size=size;o.data.align_x='CENTER';o.data.extrude=.002;o.data.materials.append(M[mat]);o.parent=parent or root
 bpy.ops.object.convert(target='MESH');return bpy.context.object

def bolts(p,s,parent=None):
 for x in [-1,1]:
  for y in [-1,1]:cyl('Rivet',(p[0]+x*s[0],p[1]+y*s[1],p[2]),.025,.028,'steel',parent,vertices=8)

def scar(p,scale=1,parent=None):
 for i in range(3):box('Scored armor',(p[0]+i*.05*scale,p[1],p[2]+i*.025*scale),(.018*scale,.13*scale,.006),'dark',parent,.002,rot=(0,0,-.5))

def muzzle(parent,x,y,z,r=.09,length=.8):
 cyl('Barrel jacket',(x,y,z),r,length,'steel',parent,(0,1,0))
 torus('Muzzle rim',(x,y+length/2,z),r*.9,r*.18,'dark',parent,(math.pi/2,0,0))
 cyl('Bore',(x,y+length/2+.004,z),r*.64,.012,'dark',parent,(0,1,0))
 for off in [-.18,.1]:cyl('Barrel collar',(x,y+off,z),r*1.15,.05,'dark',parent,(0,1,0))

def organic(name, rings, mat='skin', parent=None, sides=16):
 # Continuous anatomical surface: z, horizontal radius, depth, forward lean.
 rings=sorted(rings,key=lambda ring:ring[0])  # Consistent outward normals, including descending leg profiles.
 vertices=[];faces=[]
 for z,rx,ry,lean in rings:
  for j in range(sides):
   a=j*math.tau/sides;vertices.append((math.cos(a)*rx,math.sin(a)*ry+lean,z))
 for ring in range(len(rings)-1):
  for j in range(sides):
   a=ring*sides+j;b=ring*sides+(j+1)%sides
   faces.append((a,b,b+sides,a+sides))
 faces.extend([tuple(reversed(range(sides))),tuple((len(rings)-1)*sides+j for j in range(sides))])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
 for poly in mesh.polygons:poly.use_smooth=True
 return finish(obj,name,mat,parent)

def tower(kind,variant):
 accent=['cyan','orange','frost'][kind]
 hull=['olive','sand','ceramic'][kind]
 cyl('Recessed bearing',(0,0,.18),.57,.24,'dark',vertices=12)
 cyl('Armored footing',(0,0,.23),.65,.12,hull,vertices=6 if kind==2 else 8)
 torus('Bearing',(0,0,.37),.43,.04,'steel')
 # Low, angular outriggers give heavy weapons a grounded silhouette.
 for angle in [45,135,225,315]:
  a=math.radians(angle);x,y=math.cos(a)*.61,math.sin(a)*.61
  box('Stabilizer arm',(x*.74,y*.74,.17),(.7,.21,.17),'dark',rot=(0,0,a))
  box('Clamped foot',(x,y,.09),(.32,.29,.16),hull,bevel=.025,rot=(0,0,a))
  cyl('Lock pin',(x,y,.2),.042,.08,'steel',vertices=8)
  box('Identification flash',(x,y,.185),(.15,.08,.018),accent,bevel=.003,rot=(0,0,a))
 if kind==1:
  for side in [-1,1]:
   box('Artillery stabilizer',(side*.8,-.32,.19),(.45,.22,.2),'sand',bevel=.03)
   link('Hydraulic stabilizer',(side*.3,-.1,.38),(side*.8,-.32,.22),.055,'steel')
 elif kind==2:
  for side in [-1,1]:
   box('Capacitor bank',(side*.53,-.12,.42),(.23,.55,.4),'dark',bevel=.035)
   for y in [-.3,-.12,.06]:cyl('Capacitor',(side*.53,y,.58),.075,.33,'steel')
   link('Coolant return',(side*.53,-.35,.4),(side*.26,-.35,.8),.035,'copper')
 cyl('Turntable',(0,0,.49),.42,.2,'steel')
 head=empty('Head',parent=root)
 box('Armored cradle',(0,-.04,.84),(.83,.75,.44),hull,head,.055)
 box('Top carapace',(0,-.12,1.09),(.87,.64,.15),hull,head,.035)
 for side in [-1,1]:
  box('Flank plate',(side*.48,-.12,.88),(.14,.68,.38),hull,head,.025)
  box('Identification strip',(side*.559,-.07,.98),(.015,.39,.055),accent,head,.004)
  for i in range(4):box('Cooling vent',(side*.25,-.38+i*.07,1.178),(.14,.025,.015),'dark',head,.003)
 bolts((0,-.12,1.182),(.34,.22),head)
 scar((.11,-.12,1.184),parent=head)
 cyl('Optics mast',(-.25,-.23,1.28),.065,.25,'dark',head)
 box('Optics enclosure',(-.25,-.19,1.36),(.18,.2,.14),'dark',head,.025)
 cyl('Targeting lens',(-.25,-.08,1.36),.05,.025,accent,head,(0,1,0))
 for side in [-1,1]:
  box('Rear heat sink',(side*.31,-.5,.84),(.18,.24,.32),'dark',head,.015)
  for z in [.74,.82,.9,.98]:box('Heat sink fin',(side*.31,-.52,z),(.24,.29,.018),'steel',head,.004)
 text('Unit stencil',(0,-.08,1.185),['SENT','MTR','CRYO'][kind],.1,'ivory',parent=head)
 if kind==0:
  if variant==0: # Long precision weapon with two rails and energized core.
   for side in [-1,1]:box('Rail',(side*.15,.87,1.0),(.09,1.75,.13),'steel',head,.025)
   box('Accelerator',(0,.9,1),(.08,1.5,.06),'cyan',head,.008)
   box('Muzzle brake',(0,1.73,1),(.44,.19,.22),'dark',head,.025)
   box('Scope',(0,.12,1.3),(.18,.45,.17),'dark',head,.03)
   cyl('Scope glass',(0,.36,1.3),.06,.02,'cyan',head,(0,1,0))
  elif variant==1:
   cyl('Rotary housing',(0,.35,.98),.28,.32,'dark',head,(0,1,0))
   rotor=empty('Rotor',(0,0,.98),head)
   for i in range(6):
    a=i*math.tau/6;muzzle(rotor,math.cos(a)*.16,.92,math.sin(a)*.16,.052,1.12)
   torus('Rotary muzzle brace',(0,1.4,0),.22,.045,'steel',rotor,(math.pi/2,0,0))
   cyl('Ammo drum',(-.66,-.1,.83),.26,.35,'copper',head,(1,0,0))
  else:
   for side in [-1,1]:muzzle(head,side*.2,.7,.98,.09,.94)
   box('Feed tray',(.62,-.13,.8),(.3,.55,.32),'dark',head,.04)
   box('Ballistic gunshield',(0,.28,.85),(.95,.13,.45),hull,head,.025)
   for side in [-1,1]:box('Receiver shoulder',(side*.24,.26,1.09),(.26,.38,.13),hull,head,.025)
   link('Feed cable',(.55,-.38,.79),(.68,-.38,.99),.035,'rubber',head)
   for i in range(5):cyl('Linked cartridge',(.65,-.32+i*.09,1.0),.035,.2,'copper',head)
 elif kind==1:
  if variant==1: # Three individually collared launchers.
   for x in [-.29,0,.29]:
    link('Launcher',(x,.05,.87),(x,.48,1.5),.135,'steel',head)
    torus('Launcher rim',(x,.48,1.5),.13,.032,'orange',head,(.6,0,0))
    ball('Launcher darkness',(x,.48,1.5),(.09,.09,.025),'dark',head)
  else:
   radius=.22 if variant<0 else .3
   end=(0,.68,1.56 if variant<0 else 1.86)
   link('Howitzer tube',(0,.03,.82),end,radius,'steel',head)
   ball('Bore darkness',end,(radius*.8,radius*.8,radius*.2),'dark',head)
   for side in [-1,1]:link('Recoil piston',(side*.36,-.1,.67),(side*.36,.38,1.22),.065,'copper',head)
   box('Recoil shield',(0,.24,.95),(.98,.15,.35),'armor',head,.04)
  for side in [-1,1]:
   box('Shell rack',(side*.66,-.13,.7),(.28,.62,.23),'dark',head,.03)
   for i in range(3):cyl('Shell',(side*.66,-.32+i*.2,.92),.075,.26,'copper',head,r2=.04)
 else:
  if variant==1:
   cyl('Pulse mast',(0,.02,1.35),.15,.7,'steel',head)
   cyl('Dish',(0,.02,1.76),.48,.15,'armor',head,r2=.24)
   torus('Field emitter',(0,.02,1.85),.45,.055,'frost',head)
   for i in range(4):
    a=i*math.tau/4;link('Field prong',(math.cos(a)*.15,math.sin(a)*.15,1.5),(math.cos(a)*.45,math.sin(a)*.45,1.95),.045,'steel',head)
  else:
   for z in [.96,1.13,1.3,1.47]:torus('Cryogenic coil',(0,.08,z),.26,.045,'steel',head)
   cyl('Coolant core',(0,.08,1.25),.17,.73,'frost',head,vertices=6,r2=.1)
   for side in [-1,1]:
    box('Emitter fin',(side*.35,.08,1.36),(.12,.32,.75),'armor',head,.03,rot=(0,side*.18,0))
    box('Frozen seam',(side*.35,.255,1.36),(.04,.025,.5),'frost',head,.004)
   if variant==0:
    for a in [0,math.pi/2,math.pi,math.pi*1.5]:cyl('Zero crystal',(math.cos(a)*.2,.08+math.sin(a)*.2,1.81),.09,.36,'frost',head,vertices=5,r2=0)
  for side in [-1,1]:cyl('Coolant tank',(side*.62,-.22,.84),.15,.5,'dark',head)

def zombie(kind):
 # Continuous ribcage and small head; independent knees and elbows animate in game.
 titan=kind==3;runner=kind==1;armored=kind==2
 body=empty('Body',parent=root)
 width=1.35 if titan else (.83 if runner else 1)
 organic('Ribcage',[(.69,.13,.12,0),(.84,.18,.13,0),(1.04,.24,.17,.025),(1.23,.29,.19,.045),(1.37,.25,.17,.07),(1.43,.13,.11,.09)],'necrotic' if titan else 'skin',body)
 box('Torn trousers',(0,0,.67),(.32,.25,.21),'cloth',bevel=.07)
 # Asymmetric exposed back, muscles and torn shoulder straps.
 for side in [-1,1]:
  ball('Scapula',(side*.12,-.14,1.26),(.10,.045,.15),'necrotic',body)
  box('Ragged harness',(side*.18,-.02,1.32),(.055,.39,.065),'cloth',body,.01,rot=(0,side*.4,0))
  leg=empty('LegL' if side<0 else 'LegR',(side*.12,0,.69),root)
  organic('Thigh',[(0,.08,.085,0),(-.11,.1,.1,0),(-.28,.075,.075,.025)],'cloth',leg)
  ball('Exposed knee',(0,.045,-.3),(.082,.09,.072),'necrotic',leg)
  knee=empty('ShinL' if side<0 else 'ShinR',(0,0,-.3),leg)
  link('Tibia',(0,0,0),(0,-.015,-.28),.052,'skin' if side<0 else 'cloth',knee)
  link('Exposed shin bone',(.025,.045,-.04),(.025,.035,-.24),.02,'bone',knee)
  box('Combat boot',(0,.065,-.3),(.155,.25,.14),'rubber',knee,.025)
  box('Boot sole',(0,.067,-.371),(.16,.26,.025),'dark',knee,.008)
  arm=empty('ArmL' if side<0 else 'ArmR',(side*.29,.04,1.29),root)
  ball('Deltoid',(side*.015,0,-.025),(.085,.085,.12),'skin',arm)
  link('Bicep',(side*.02,.015,-.06),(side*.055,.13,-.29),.067,'skin',arm)
  ball('Elbow',(side*.055,.13,-.29),(.06,.06,.06),'bone',arm)
  if titan and side<0:
   arm.scale=(1.65,1.5,1.55)
   link('Hypertrophic bicep',(0,0,-.04),(-.05,.12,-.27),.1,'necrotic',arm)
  elbow=empty('ForearmL' if side<0 else 'ForearmR',(side*.055,.13,-.29),arm)
  link('Forearm',(0,0,0),(side*.035,.23,-.04),.047,'necrotic',elbow)
  link('Wrist sinew',(0,.035,.035),(side*.035,.22,0),.019,'sinew',elbow)
  ball('Hand',(side*.035,.25,-.045),(.067,.085,.042),'skin',elbow)
  if titan and side<0:
   link('Club forearm',(0,0,0),(-.035,.22,-.04),.1,'necrotic',elbow)
   for j in range(3):cyl('Forearm bone',(-.085-j*.01,.03+j*.06,-.02),.035,.18,'bone',elbow,axis=(-1,0,.3),vertices=5,r2=0)
  for finger in range(4):
   x=side*.035-.048+finger*.03
   link('Finger',(x,.29,-.045),(x,.36,-.07),.011,'skin',elbow)
   link('Talon',(x,.36,-.07),(x,.39,-.105),.008,'bone',elbow)
 link('Hunched neck',(0,.06,1.37),(0,.16,1.5),.085,'necrotic',body)
 organic('Cranium',[(1.43,.07,.08,.16),(1.51,.105,.10,.18),(1.64,.125,.115,.18),(1.73,.10,.09,.17),(1.76,.035,.035,.15)],'necrotic',body)
 box('Exposed cheekbone',(-.095,.27,1.57),(.064,.04,.13),'bone',body,.015,rot=(0,.25,.1))
 box('Sunken mouth',(0,.278,1.5),(.13,.045,.067),'dark',body,.018)
 box('Torn jaw',(0,.273,1.46),(.14,.06,.045),'sinew',body,.015,rot=(0,.12,0))
 for side in [-1,1]:
  ball('Eye socket',(side*.052,.278,1.625),(.042,.02,.033),'dark',body)
  ball('Dead pupil',(side*.052,.296,1.625),(.009,.005,.008),'bone',body)
  box('Brow',(side*.055,.277,1.663),(.09,.04,.032),'necrotic',body,.012,rot=(0,side*.2,0))
 for i in range(3):box('Broken tooth',(-.04+i*.032,.303,1.511),(.012,.014,.018+i*.004),'bone',body,.003,rot=(0,0,i*.2))
 for i in range(4):
  box('Ragged chest wound',(-.11+i*.014,.189,1.04+i*.047),(.09,.025,.068),'sinew',body,.009,rot=(0,-.3+i*.12,0))
 for i in range(5):
  link('Exposed rib',(-.2,.19,1.02+i*.054),(-.045,.208,1.045+i*.054),.016,'bone',body)
 for i in range(5):
  ball('Vertebra',(0,-.16,1.0+i*.07),(.034,.035,.028),'bone',body)
  box('Clothing tear',(.15,-.19,1.0+i*.08),(.05,.025,.07),'cloth',body,.008,rot=(0,.1,i*.4))
 if runner:
  root.scale=(.78,1,1)
  for i in range(6):cyl('Spinal spur',(0,-.18,1.05+i*.07),.035,.19,'bone',body,axis=(0,-1,.4),vertices=5,r2=0)
  link('Exposed tendon',(.1,.04,.8),(.21,-.1,1.24),.024,'sinew',body)
  box('Torn hazard band',(.27,.06,1.3),(.12,.18,.06),'yellow',body,.01)
 elif armored:
  box('Breastplate',(0,.16,1.16),(.51,.15,.43),'armor',body,.045)
  box('Trauma plate',(0,.248,1.19),(.31,.04,.27),'steel',body,.02)
  for side in [-1,1]:
   box('Pauldrons',(side*.3,.035,1.34),(.22,.3,.18),'armor',body,.045,rot=(0,side*.25,0))
   box('Armored shin',(side*.12,.07,.28),(.12,.07,.26),'armor',bevel=.025)
  ball('Broken helmet',(0,.17,1.69),(.145,.14,.13),'armor',body)
  box('Cracked visor',(0,.302,1.64),(.22,.025,.054),'red',body,.01)
  box('Helmet gash',(-.08,.09,1.8),(.045,.18,.025),'dark',body,.006,rot=(0,0,.5))
  text('Armor stencil',(0,.273,1.16),'07',.085,'ivory',rot=(math.pi/2,0,0),parent=body)
 elif titan:
  ball('Hypertrophic back',(0,-.15,1.29),(.37,.29,.34),'necrotic',body)
  organic('Distended abdomen',[(.67,.14,.12,.02),(.78,.24,.2,.03),(.95,.26,.22,.03),(1.12,.2,.16,.02)],'necrotic',body)
  for i in range(4):box('Abdominal tear',(.04+i*.025,.233,.77+i*.07),(.15,.025,.045),'sinew',body,.012,rot=(0,.2,0))
  for i in range(7):
   x=(-.25 if i%2==0 else .18)+i*.013
   ball('Necrotic growth',(x,-.33,1.1+i*.07),(.075,.055,.1),'sinew' if i%2 else 'skin',body)
  for side in [-1,1]:
   box('Broken restraint',(side*.25,.015,.99),(.12,.48,.17),'dark',body,.02,rot=(0,side*.15,0))
   for i in range(3):cyl('Bone spike',(side*(.28+i*.07),-.06,1.39+i*.08),.065,.31,'bone',body,axis=(side*.5,0,1),vertices=6,r2=0)
  box('Containment collar',(0,.1,1.46),(.4,.33,.1),'steel',body,.025)
  for i in range(3):ball('Infection pustule',(.19,-.3,1.23+i*.1),(.045,.05,.055),'red',body)
  root.scale=(width,1,width)


def road(kind):
 box('Foundation',(0,0,-.05),(2.2,2,.16),'concrete',bevel=.025)
 box('Road surface',(0,0,.045),(1.72,2,.08),'asphalt',bevel=.012)
 for side in [-1,1]:
  box('Curb',(side*1.02,0,.055),(.14,2,.14),'steel',bevel=.018)
  box('Lane light',(side*.93,.45,.115),(.045,.4,.018),'yellow',bevel=.004)
 if kind==0:
  box('Center dash',(0,.12,.09),(.045,.5,.008),'ivory',bevel=.002)
  for i in range(4):
   x=random.uniform(-.7,.7);y=random.uniform(-.8,.8)
   box('Asphalt scar',(x,y,.092),(.018,random.uniform(.1,.4),.005),'dark',bevel=0,rot=(0,0,random.uniform(-1,1)))
 elif kind==1:
  box('Deck',(0,0,.105),(1.65,1.92,.08),'dark',bevel=.01)
  for i in range(12):box('Drain grating',(0,-.88+i*.16,.16),(1.5,.055,.025),'steel',bevel=.008)
  for side in [-1,1]:cyl('Conduit',(side*.69,0,.19),.055,1.92,'copper',axis=(0,1,0))
 elif kind==2:
  for side in [-1,1]:
   for i in range(7):box('Hazard stripe',(side*.72,-.82+i*.27,.105),(.22,.11,.012),'yellow',bevel=.002,rot=(0,0,-.5))
   box('Warning beacon',(side*1.03,0,.22),(.12,.24,.22),'orange',bevel=.02)
  ball('Blood smear',(.22,.35,.1),(.19,.32,.008),'blood')
  for i in range(5):ball('Spatter',(.15+math.sin(i*2.4)*.25,.3+math.cos(i*2.4)*.4,.103),(.025+i*.005,.035,.006),'blood')
 elif kind==3:
  for i in range(6):
   x=random.uniform(-.55,.55);y=random.uniform(-.75,.75)
   box('Fracture',(x,y,.1),(.025,.55,.01),'dark',bevel=.002,rot=(0,0,random.uniform(-1,1)))
  for side in [-1,1]:
   box('Broken edge',(side*.79,.58,.14),(.16,.26,.11),'concrete',bevel=.02,rot=(0,.2,.4))
   link('Exposed rebar',(side*.9,.35,.1),(side*.86,.6,.2),.018,'copper')
  ball('Dragged remains',(-.27,-.1,.1),(.12,.36,.008),'blood')

def prop(kind):
 if kind==0:
  box('Bunker hull',(0,0,1.05),(2.8,3.3,2.1),'armor',bevel=.22)
  box('Roof armor',(0,0,2.18),(3.15,3.6,.28),'steel',bevel=.12)
  for side in [-1,1]:
   box('Gate buttress',(side*1.2,1.72,.9),(.4,.44,1.8),'dark',bevel=.07)
   box('Door light',(side*.96,1.92,.95),(.055,.05,1.6),'cyan',bevel=.008)
   for i in range(5):box('Roof vent',(side*.68,-.7+i*.24,2.34),(.65,.065,.035),'dark',bevel=.01)
  box('Armored door',(0,1.69,.91),(1.75,.1,1.7),'steel',bevel=.06)
  box('Gate seam',(0,1.755,.9),(.04,.015,1.65),'dark',bevel=.002)
  for i in range(4):box('Gate ribs',(0,1.77,.35+i*.35),(1.6,.035,.055),'dark',bevel=.006)
  text('Bunker identification',(0,-.15,2.34),'OUTPOST 07',.24)
  cyl('Antenna',(1,-1.1,3),.04,1.45,'steel')
  ball('Antenna beacon',(1,-1.1,3.75),(.08,.08,.08),'red')
 elif kind==1:
  cyl('Generator deck',(0,0,.15),1.1,.3,'dark',vertices=8)
  cyl('Reactor body',(0,0,1.05),.68,1.7,'armor',vertices=16)
  for z in [.5,.8,1.1,1.4,1.7]:torus('Containment ring',(0,0,z),.69,.055,'steel')
  for a in range(0,360,60):
   angle=math.radians(a);x,y=math.cos(angle)*.69,math.sin(angle)*.69
   box('Core window',(x,y,1.05),(.15,.15,1.2),'cyan',bevel=.025)
  cyl('Reactor crown',(0,0,1.98),.8,.2,'steel',r2=.6)
  for side in [-1,1]:
   link('Coolant pipe',(side*.95,0,.3),(side*.95,0,1.5),.1,'copper')
   link('Header',(side*.95,0,1.5),(side*.5,0,1.5),.1,'copper')
  text('Reactor number',(0,0,2.09),'R-09',.2)
 else:
  box('Barrier foot',(0,0,.1),(3.3,.85,.2),'dark',bevel=.08)
  box('Barrier armor',(0,0,.52),(3,.6,.85),'concrete',bevel=.12)
  for x in [-1.1,-.7,-.3,.1,.5,.9]:box('Hazard stripe',(x,.311,.62),(.16,.015,.42),'yellow',bevel=.003,rot=(0,.35,0))
  for side in [-1,1]:
   cyl('Wire post',(side*1.25,0,1.18),.035,.6,'steel')
   box('Bolt plate',(side*1.13,.32,.35),(.2,.04,.14),'steel',bevel=.015)
  # Actual coiled razor wire and projecting barbs.
  for i in range(13):
   ring=torus('Razor coil',(-1.2+i*.2,0,1.27),.19,.012,'steel',rot=(0,math.pi/2,0))
   link('Barb',(-1.2+i*.2,-.2,1.25),(-1.2+i*.2,-.29,1.36),.009,'steel')
  scar((.5,.28,.95),2)

def environment_prop(kind):
 if kind==0: # Expedition supply crate.
  box('Shockproof case',(0,0,.36),(1.1,.72,.7),'armor',bevel=.075)
  box('Lid',(0,0,.75),(1.15,.77,.13),'steel',bevel=.04)
  for x in [-.4,.4]:
   box('Reinforced strap',(x,0,.39),(.09,.8,.76),'dark',bevel=.02)
   box('Latch',(x,.43,.55),(.12,.07,.18),'copper',bevel=.018)
  text('Supply stencil',(0,0,.82),'SUPPLY',.15)
 elif kind==1: # Open munitions rack.
  box('Ammo cage',(0,0,.25),(1.15,.8,.5),'dark',bevel=.045)
  for i in range(5):
   cyl('Shell',(-.42+i*.21,0,.62),.08,.65,'copper',r2=.045)
   cyl('Shell cap',(-.42+i*.21,0,.98),.05,.12,'orange',r2=0)
  for side in [-1,1]:box('Rack handle',(side*.63,0,.3),(.1,.7,.13),'steel')
 elif kind==2: # Diesel generator.
  box('Skid',(0,0,.12),(1.7,1.05,.2),'dark',bevel=.04)
  box('Generator housing',(0,0,.62),(1.4,.88,.85),'armor',bevel=.09)
  for i in range(7):box('Vent',(-.45+i*.15,.451,.63),(.06,.025,.48),'dark',bevel=.006)
  cyl('Exhaust',(.45,-.2,1.24),.07,.65,'steel')
  cyl('Silencer',(.45,-.2,1.32),.11,.26,'dark')
  box('Control box',(-.49,-.42,.83),(.28,.1,.25),'steel')
  box('Status lamp',(-.49,-.48,.86),(.16,.02,.045),'cyan',bevel=.005)
 elif kind==3: # Communications antenna.
  box('Antenna platform',(0,0,.1),(1.5,1.5,.2),'concrete',bevel=.04)
  for side in [-1,1]:
   link('Mast brace',(side*.55,0,.2),(0,0,2.3),.035,'steel')
  cyl('Antenna mast',(0,0,1.7),.07,3.2,'steel')
  for z in [1.9,2.5,3.1]:
   link('Receiver',(-.55,0,z),(.55,0,z),.025,'steel')
  ball('Red beacon',(0,0,3.4),(.075,.075,.075),'red')
 elif kind==4: # Dual floodlight with caged luminaires.
  box('Lamp base',(0,0,.1),(.9,.9,.2),'dark',bevel=.05)
  cyl('Lamp mast',(0,0,1.5),.065,2.8,'steel')
  box('Luminaire crossbar',(0,0,2.85),(1.25,.15,.12),'dark')
  for side in [-1,1]:
   box('Floodlight case',(side*.43,.06,2.87),(.54,.3,.34),'armor',bevel=.045)
   box('Floodlight lens',(side*.43,.221,2.87),(.42,.02,.23),'ivory',bevel=.025)
   for i in range(3):box('Lens guard',(side*.43-.14+i*.14,.243,2.87),(.018,.014,.26),'steel',bevel=.003)
 elif kind==5: # Exposed pipe manifold.
  box('Pipe footing',(0,0,.1),(2.3,1.2,.18),'concrete',bevel=.04)
  for side in [-1,1]:
   link('Pipe',(side*.6,-.45,.42),(side*.6,.45,.42),.14,'copper')
   torus('Valve wheel',(side*.6,0,.73),.18,.023,'red')
   cyl('Valve stem',(side*.6,0,.56),.04,.3,'steel')
   for y in [-.37,.37]:cyl('Flange',(side*.6,y,.42),.2,.07,'steel',axis=(0,1,0))
  link('Junction',(-.6,0,.42),(.6,0,.42),.14,'copper')
 elif kind==6: # Ground crater, low profile; never a hidden build obstacle.
  cyl('Scorched basin',(0,0,.008),1.05,.012,'dark',vertices=20)
  for i in range(9):
   a=(i+random.uniform(-.25,.25))*math.tau/9;r=random.uniform(.72,1.02)
   box('Shattered impact rim',(math.cos(a)*r,math.sin(a)*r,.03),(random.uniform(.16,.38),random.uniform(.1,.24),.045),'concrete',bevel=.018,rot=(0,0,a+random.uniform(-.4,.4)))
  for i in range(8):
   a=i*2.4;box('Impact splinter',(math.cos(a)*.58,math.sin(a)*.58,.026),(.05,.31,.02),'steel',rot=(0,0,a))
 elif kind==7: # Rubble, deliberately low enough for a turret deck to cover.
  for i in range(13):
   x=random.uniform(-.75,.75);y=random.uniform(-.5,.5)
   box('Broken slab',(x,y,.025),(.15+random.random()*.25,.12+random.random()*.22,.04),'concrete',bevel=.025,rot=(0,0,random.random()*3))
  for i in range(4):link('Rebar',(-.55+i*.3,-.4,.035),(-.35+i*.3,.4,.035),.014,'copper')
 elif kind==8: # Burned utility rover.
  box('Chassis',(0,0,.5),(1.25,2.3,.3),'dark',bevel=.1)
  box('Cab',(0,.45,.95),(1.18,1.15,.8),'armor',bevel=.12,rot=(.06,0,.04))
  box('Smashed windshield',(0,1.035,1.08),(.9,.025,.37),'dark',bevel=.03)
  for side in [-1,1]:
   for y in [-.75,.75]:
    cyl('Rover tire',(side*.65,y,.38),.3,.22,'rubber',axis=(1,0,0))
    cyl('Wheel hub',(side*.78,y,.38),.13,.035,'steel',axis=(1,0,0))
  box('Burned bed',(0,-.7,.78),(1.15,.9,.35),'concrete',bevel=.06)
  box('Bent hood',(0,1.13,.78),(1.05,.62,.06),'steel',bevel=.025,rot=(.28,.08,0))
  for i in range(5):box('Blast scar',(-.4+i*.16,-.8,.97),(.06,.45,.015),'dark',rot=(0,0,.3))
 elif kind==9: # Field medical shelter.
  box('Shelter platform',(0,0,.1),(2.6,2.6,.2),'dark',bevel=.05)
  box('Shelter body',(0,0,.9),(2.3,2.2,1.6),'cloth',bevel=.15)
  box('Roof armor',(0,0,1.77),(2.55,2.4,.18),'armor',bevel=.08)
  box('Entrance',(0,1.12,.78),(1.1,.025,1.35),'dark',bevel=.06)
  box('Medical cross H',(.76,1.13,1.25),(.4,.025,.12),'ivory',bevel=.008)
  box('Medical cross V',(.76,1.14,1.25),(.12,.025,.4),'ivory',bevel=.008)
  for side in [-1,1]:box('Shelter rib',(side*1.2,0,1),(.08,2.3,1.7),'steel',bevel=.025)
 elif kind==10: # Ruined hab, open side and jagged upper walls.
  box('Hab slab',(0,0,.1),(3.2,2.7,.2),'concrete',bevel=.04)
  box('Hab rear',(0,-1.15,1.08),(3,.22,2),'armor',bevel=.06)
  for side in [-1,1]:
   box('Hab side',(side*1.38,0,.8),(.22,2.3,1.4),'concrete',bevel=.045)
   for i in range(4):
    z=1.5+random.random()*.3
    box('Broken wall crown',(side*1.38,-.85+i*.54,z),(.22,.4,.3),'armor',bevel=.04,rot=(0,0,random.uniform(-.2,.2)))
  box('Warped roof',(-.6,-.5,2.04),(1.7,1.5,.14),'steel',bevel=.04,rot=(0,.17,.08))
  for i in range(5):box('Floor debris',(-.9+i*.4,.3,.25),(.3,.45,.16),'concrete',rot=(0,.1,i*.7))
 elif kind==11: # Checkpoint arch.
  for side in [-1,1]:
   box('Checkpoint foot',(side*1.25,0,.16),(.75,1.1,.3),'concrete',bevel=.06)
   box('Checkpoint column',(side*1.25,0,1.25),(.4,.55,2.3),'armor',bevel=.06)
   box('Gate signal',(side*1.25,.29,1.9),(.13,.035,.3),'red',bevel=.012)
  box('Checkpoint lintel',(0,0,2.5),(3,.65,.36),'steel',bevel=.08)
  text('Checkpoint warning',(0,.34,2.42),'QUARANTINE',.18,'ivory',rot=(math.pi/2,0,0))

def export(name):
 # Apply bevels and consolidate by rigid part/material. Preserve named limb pivots.
 bpy.ops.object.select_all(action='DESELECT')
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for o in meshes:
  bpy.context.view_layer.objects.active=o;o.select_set(True)
  for mod in list(o.modifiers):
   try:bpy.ops.object.modifier_apply(modifier=mod.name)
   except RuntimeError:pass
  o.select_set(False)
 groups={}
 for o in meshes:groups.setdefault((o.parent.name if o.parent else '',o.data.materials[0].name),[]).append(o)
 for group in groups.values():
  if len(group)<2:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join()
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
 print('ASSET COMPLETE:',name)

def clear():
 global root
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 root=empty('Model')

names=['01_marine_sentinel','02_mortar_bulwark','03_cryo_prism','04_sniper_lancer','05_assault_reaper','06_siege_judgement','07_cluster_hydra','08_deepfreeze_zero','09_fieldcontrol_pulse','10_zombie_walker','11_zombie_runner','12_zombie_armored','13_zombie_titan','14_road_asphalt','15_road_steel','16_road_quarantine','17_road_ruined','18_bunker_command','19_reactor','20_barricade','21_supply_crate','22_ammo_cache','23_generator_aux','24_comms_mast','25_floodlight','26_pipe_junction','27_blast_crater','28_rubble_pile','29_wreck_rover','30_medical_shelter','31_habitat_ruined','32_gate_checkpoint']
only = next((a.split('=',1)[1] for a in sys.argv if a.startswith('--only=')), '')
selected = set(int(x) for x in only.split(',')) if only else set(range(1,len(names)+1))
for index,name in enumerate(names):
 if index+1 not in selected: continue
 random.seed(1700+index)
 clear()
 if index<3:tower(index,-1)
 elif index<9:tower((index-3)//2,(index-3)%2)
 elif index<13:zombie(index-9)
 elif index<17:road(index-13)
 elif index<20:prop(index-17)
 else:environment_prop(index-20)
 export(name)
print('FINISHED:',len(selected),'ORIGINAL ASSETS')
