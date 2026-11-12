import json,re
from pathlib import Path
p=Path('/workspace/assets/ui/profile.ui.json')
d=json.loads(p.read_text())
INK=[91,76,47,255];MUTED=[116,102,70,255];PAPER=[255,246,220,255];ORANGE=[238,156,67,255]
def node(t,id,x,y,w,h,**props):
 return dict(type=t,id=id,position='absolute',left=x,top=y,width=w,height=h,**props)
def find(n,id):
 if n.get('id')==id:return n
 for c in n.get('children',[]):
  r=find(c,id)
  if r:return r
skins=[]
src=Path('/workspace/scripts/shared/outfit-manager.lua').read_text().split('local SKIN_PRAISES')[0]
for m in re.finditer(r'\{ id = "([^"]+)".*?thumbnail = "([^"]+)"',src,re.S):
 seg=m.group(0);sid=m.group(1);name=re.search(r'name\s*=\s*"([^"]+)"',seg).group(1)
 skins.append((sid,name,m.group(2),'默认' if sid=='default' else '完成7关' if sid=='sport' else '完成14关' if sid=='chef' else '￥3',sid=='default'))
assert len(skins)==11
bgs=[('default','暖阳奶油','暖阳奶油',True),('sky_blue','晴空蔚蓝','晴空蔚蓝',True),('mint_green','薄荷清风','薄荷清风',True),('sunset_glow','夕阳余晖','通关第7关',False),('lavender','薰衣紫梦','通关第14关',False),('cherry_blossom','樱花漫舞','通关第21关',False),('golden_autumn','金秋丰收','通关第28关',False)]
def populate(grid,rows,kind):
 if grid.get('children'):return
 grid['children']=[node('Panel',kind+'-grid-rule',24,0,355.2,1.5,backgroundColor=[221,207,166,255])]
 for i,(id,name,path,caption,unlocked) in enumerate(rows):
  x=28.6+(i%4)*90;y=14+(i//4)*114;selected=id=='default';prefix=kind+'-'+id
  children=[node('Panel',prefix+'-paper',0,0,76,76,backgroundColor=PAPER,borderRadius=11,borderColor=ORANGE if selected else INK,borderWidth=3 if selected else 2)]
  if kind=='skin':children.append(node('Panel',prefix+'-image',3,3,70,70,backgroundColor=False,backgroundImage=path,backgroundFit='contain',backgroundImageOpacity=1 if unlocked else .55))
  else:children.append(node('Panel',prefix+'-image',22.25,3,31.5,70,backgroundColor=False,backgroundImage=path,backgroundFit='cover'))
  if not unlocked:
   children.append(node('Panel',prefix+'-tint',0,0,76,76,backgroundColor=[255,246,220,90],borderRadius=11))
   children.append(node('Panel',prefix+'-lock',26,26,24,26,backgroundColor=False,backgroundImage='ui/art/map-lock.png',backgroundFit='contain'))
  if selected:
   children.append(node('Label',prefix+'-selected',56,0,20,20,text='✓',fontFamily='sans',fontSize=10.5,fontColor=PAPER,textAlign='center',verticalAlign='middle',backgroundColor=[132,166,78,255],borderRadius=10))
  children.append(node('Label',prefix+'-caption',-7,80,90,20,text=caption,fontFamily='sans',fontSize=9 if unlocked else 8.25,fontColor=INK if selected else MUTED,textAlign='center',verticalAlign='middle',lineHeight=1))
  grid['children'].append(node('Button',prefix,x,y,76,98,text='',padding=0,backgroundColor=False,borderWidth=0,boxShadow=False,children=children,_extraction={'id':id,'name':name,'unlockedSample':unlocked,'selectedSample':selected,'action':'保留原Lua：选择/解锁/购买，不在JSON绑定。'}))
populate(find(d,'profile-skin-grid'),skins,'skin')
rows=[(id,name,'image/handdrawn/backgrounds/previews/'+id+'.png',caption,unlocked) for id,name,caption,unlocked in bgs]
populate(find(d,'profile-background-grid'),rows,'background')
# 仅完善本轮提取的角色节点，不触碰其他手工资产。
grid=find(d,'profile-skin-grid')
for i,row in enumerate(skins):
 sid,name,path,caption,unlocked=row
 item=next(c for c in grid['children'] if c.get('id')=='skin-'+sid)
 prefix=item['id'];selected=sid=='default'
 image=next(c for c in item['children'] if c.get('backgroundImage'))
 image['backgroundImageOpacity']=1 if unlocked else .55
 label=next(c for c in item['children'] if c['type']=='Label')
 label['fontSize']=9 if unlocked else 8.25
 label['lineHeight']=1
 item['children'].insert(0,node('Panel',prefix+'-paper',0,0,76,76,backgroundColor=PAPER,borderRadius=11,borderColor=ORANGE if selected else INK,borderWidth=3 if selected else 2))
 if not unlocked:
  item['children'].extend([node('Panel',prefix+'-tint',0,0,76,76,backgroundColor=[255,246,220,90],borderRadius=11),node('Panel',prefix+'-lock',26,26,24,26,backgroundColor=False,backgroundImage='ui/art/map-lock.png',backgroundFit='contain')])
 else:
  item['children'].append(node('Label',prefix+'-selected',56,0,20,20,text='✓',fontFamily='sans',fontSize=10.5,fontColor=PAPER,textAlign='center',verticalAlign='middle',backgroundColor=[132,166,78,255],borderRadius=10))
grid['children'].insert(0,node('Panel','skin-grid-rule',24,0,355.2,1.5,backgroundColor=[221,207,166,255]))
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print('完成11角色和7背景缩略图')
