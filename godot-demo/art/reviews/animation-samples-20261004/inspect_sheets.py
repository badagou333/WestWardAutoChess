from PIL import Image
from pathlib import Path
import json

root=Path(__file__).parent
for p in root.glob('*-keyposes.png'):
    im=Image.open(p)
    w,h=im.size
    a=im.getchannel('A')
    mask=bytearray(1 if v>=16 else 0 for v in a.tobytes())
    components=[]
    for start in range(w*h):
        if not mask[start]: continue
        todo=[start]; mask[start]=0
        x0=x1=start%w; y0=y1=start//w; count=0
        while todo:
            q=todo.pop(); x=q%w; y=q//w; count+=1
            x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)
            for n in ((q-1 if x else -1),(q+1 if x<w-1 else -1),q-w,q+w):
                if 0<=n<w*h and mask[n]: mask[n]=0;todo.append(n)
        if count>250: components.append({'bbox':[x0,y0,x1+1,y1+1],'pixels':count})
    print(json.dumps({'file':p.name,'size':im.size,'mode':im.mode,'alpha':a.getextrema(),'components':components}))
