# Offline check of StaffCombat poses: replays _solve() (grip clamp to shoulder reach) and
# prints how far the solved staff axis strays from the authored direction. >20 deg = the
# pose is unreachable and the staff ends up sideways. Usage: python3 tools/pose_check.py
import math
S=(0.21,1.48,-0.06); R=0.43
def d(y,p):
    y=math.radians(y);p=math.radians(p);return (math.sin(y)*math.cos(p),math.sin(p),math.cos(y)*math.cos(p))
def add(a,b,k=1): return tuple(a[i]+b[i]*k for i in range(3))
def sub(a,b): return tuple(a[i]-b[i] for i in range(3))
def ln(a): return math.sqrt(sum(x*x for x in a))
def rot(v,t): return (v[0]*math.cos(t)+v[2]*math.sin(t), v[1], -v[0]*math.sin(t)+v[2]*math.cos(t))
def clamp(h,s):
    v=sub(h,s); l=ln(v); return h if l<=R else add(s,v,R/l)
def solve(y,p,P,tw):
    dd=d(y,p); t=math.radians(tw)
    sl=rot(S,t); sr=rot((-S[0],S[1],S[2]),t)
    hr=clamp(add(P,dd,-0.45),sr); hl=clamp(add(P,dd,-0.10),sl)
    ax=sub(hl,hr); l=ln(ax); a=tuple(x/l for x in ax)
    ang=math.degrees(math.acos(max(-1,min(1,sum(a[i]*dd[i] for i in range(3))))))
    tip=add(hr,a,0.45+0.93)
    return ang,tip,l
keys={'s0':[(-125,4,(-0.30,1.22,0.22),-38),(95,-6,(0.28,1.12,0.40),34)],
 's2':[(0,128,(0,2.0,0),-12),(0,-28,(0,1.05,0.62),6)],
 'heavy_old':[(0,-33,(0,0.95,0.68),8)],'heavy_new':[(0,-40,(0.08,1.19,0.38),8)],'raised':[(0,140,(0,1.95,-0.12),-18)],'guard':[(28,-14,(0.02,1.0,0.55),0)]}
for k,v in keys.items():
    for pose in v:
        a,tip,l=solve(*pose); print(k,pose[:2],'axis err %.0f deg'%a,'tip',tuple(round(x,2) for x in tip),'grip gap %.2f'%l)
