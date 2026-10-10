# Offline check of StaffCombat poses: parses game/player/combat.gd, replays _solve() (grip
# clamp to shoulder reach) for every key and the halfway blend between keys, and prints how
# far the solved staff axis strays from the authored direction, plus the staff's clearance
# from the torso. >15 deg = unreachable (the staff ends up sideways); clearance under ~1.1
# torso radii = the shaft passes through the chest. Exit code 1 if any key fails.
# Usage: python3 tools/pose_check.py [-v]
import math, os, re, sys
S=(0.21,1.48,-0.06); R=0.43; HR=-0.45; HL=-0.10; HALF=0.93
def d(y,p):
    y=math.radians(y);p=math.radians(p);return (math.sin(y)*math.cos(p),math.sin(p),math.cos(y)*math.cos(p))
def add(a,b,k=1): return tuple(a[i]+b[i]*k for i in range(3))
def sub(a,b): return tuple(a[i]-b[i] for i in range(3))
def ln(a): return math.sqrt(sum(x*x for x in a))
def rot(v,t): return (v[0]*math.cos(t)+v[2]*math.sin(t), v[1], -v[0]*math.sin(t)+v[2]*math.cos(t))
def clamp(h,s):
    v=sub(h,s); l=ln(v); return h if l<=R else add(s,v,R/l)
def torso_gap(a,b):
    # clearance in torso radii: chest is an ellipse 0.17 m wide / 0.12 m deep (y 0.9-1.5),
    # head an ellipsoid above it; 1.0 = the shaft's centre line touches the surface
    best=9
    for i in range(41):
        x=add(a,sub(b,a),i/40)
        if 0.9<=x[1]<=1.50: best=min(best,math.hypot(x[0]/0.17,(x[2]+0.02)/0.12))
        elif 1.50<x[1]<=1.80: best=min(best,math.hypot(x[0]/0.11,(x[2]-0.01)/0.12,(x[1]-1.66)/0.14))
    return best
def solve(y,p,P,tw,slide=0.0):
    dd=d(y,p); t=math.radians(tw)
    sl=rot(S,t); sr=rot((-S[0],S[1],S[2]),t)
    hr=clamp(add(P,dd,HR+slide),sr); hl=clamp(add(P,dd,HL+slide),sl)
    ax=sub(hl,hr); l=ln(ax); a=tuple(x/l for x in ax)
    ang=math.degrees(math.acos(max(-1,min(1,sum(a[i]*dd[i] for i in range(3))))))
    c=add(hr,a,-(HR+slide))
    return ang,add(c,a,HALF),torso_gap(add(c,a,-HALF),add(c,a,HALF))
src=open(os.path.join(os.path.dirname(__file__),'..','game','player','combat.gd')).read()
num=r'(-?[\d.]+|TAU)'
key=re.compile(r'\[\s*'+num+r',\s*'+num+r',\s*'+num+r',\s*Vector3\(\s*'+num+r',\s*'+num+r',\s*'+num+r'\),\s*'+num+r'(?:,\s*'+num+r')?\]')
def f(x): return 0.0 if x is None else math.tau if x=='TAU' else float(x)
bad=0; verbose='-v' in sys.argv
for block in re.finditer(r'^const (\w+) := (.*?)(?=^const |^var |^func |\Z)', src, re.S|re.M):
    keys=[tuple(map(f,m.groups())) for m in key.finditer(block.group(2))]
    if not keys: continue
    poses=[(k[1],k[2],k[3:6],k[6],k[7]) for k in keys]
    checks=[]
    for i,pz in enumerate(poses):
        checks.append(('key%d'%i,pz))
        if i+1<len(poses):
            q=poses[i+1]; m=(0.5*(pz[0]+q[0]),0.5*(pz[1]+q[1]),tuple(0.5*(pz[2][j]+q[2][j]) for j in range(3)),0.5*(pz[3]+q[3]),0.5*(pz[4]+q[4]))
            checks.append(('mid%d'%i,m))
    for name,(y,p,P,tw,sl) in checks:
        ang,tip,gap=solve(y,p,P,tw,sl)
        fail=(ang>15 and name.startswith('key')) or gap<(1.15 if name.startswith('key') else 1.05)
        bad+=fail
        if fail or verbose or name.startswith('key'):
            print('%-7s %-5s yaw %6.0f pitch %5.0f  axis err %3.0f deg  torso clear %.2f  tip %s%s'%(block.group(1),name,y,p,ang,gap,tuple(round(x,2) for x in tip),'  FAIL' if fail else ''))
print('FAIL: %d'%bad if bad else 'all poses reachable')
sys.exit(1 if bad else 0)
