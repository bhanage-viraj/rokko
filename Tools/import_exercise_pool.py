#!/usr/bin/env python3
"""Import Lesson_1_Exercise_Pool.numbers into Content/Lesson1/exercise_pool.json.

Dev tool only (not shipped in the app). Usage:
    python3 -I Tools/import_exercise_pool.py <pool.numbers | pool.csv> rokko/Content/Lesson1/exercise_pool.json

A .numbers file is first exported to CSV by Numbers (AppleScript). Every row is checked:
answer in options, pairs match, each team adds up to 16, no duplicate rounds. Any error stops the import.
"""
import csv, sys, json, re, collections, os, subprocess, tempfile
src, out = sys.argv[1], sys.argv[2]
if src.endswith('.numbers'):
    tmp = os.path.join(tempfile.mkdtemp(), 'pool.csv')
    script = ('tell application "Numbers"\n set d to open POSIX file "%s"\n'
              ' export d to POSIX file "%s" as CSV\n close d saving no\nend tell' % (os.path.abspath(src), tmp))
    subprocess.run(['osascript', '-e', script], check=True)
    src = tmp
PIECE = {'K':'king','Q':'queen','R':'rook','B':'bishop','N':'knight','P':'pawn'}
CHAR = {'LK':'king','LQ':'queen','ER':'rook','KB':'bishop','HK':'knight','SP':'pawn'}
COL = {'W':'white','B':'black','S':'shaded'}
def tok(t):
    t=t.strip()
    m=re.fullmatch(r'([WBS])C(LK|LQ|ER|KB|HK|SP)',t)
    if m: return f"{COL[m[1]]}.character.{CHAR[m[2]]}"
    m=re.fullmatch(r'([WB])P([KQRBNP])',t)
    if m: return f"{COL[m[1]]}.piece.{PIECE[m[2]]}"
    raise ValueError('bad token '+repr(t))
def lst(s):
    s=s.strip()
    if s in ('','—','-'): return []
    res=[]
    for part in s.split(','):
        part=part.strip()
        m=re.fullmatch(r'(\S+?)×(\d+)',part)
        if m: res += [tok(m[1])]*int(m[2])
        else: res.append(tok(part))
    return res
raw=list(csv.reader(open(src,encoding='utf-8-sig'),delimiter=';'))
hdr=raw[0]; rows=[]
for r in raw[1:]:
    rows.append(dict(zip(hdr,r)))
pool=collections.OrderedDict(); errs=[]
def E(i,msg): errs.append(f"{i}: {msg}")
for r in rows:
    i=r['ID']; lll,m,tt,ee,v,iii=i.split('-')
    assert int(m)==int(r['Module']) and int(tt)==int(r['Type']) and int(ee)==int(r['Exercise']) and int(v)==int(r['Level']), i
    code=f"{lll}-{m}-{tt}-{ee}"; lvl=int(v); t=int(tt)
    rd={'id':i,'level':lvl,'variant':int(r['Variant'])}
    top=r['Card shown (top)']; opts=r['Options / cards to place']; ans=r['Correct answer']; pre=r['Prefilled']
    if t in (1,2):
        rd['shown']=tok(top); rd['options']=lst(opts); rd['answer']=tok(ans)
        if rd['answer'] not in rd['options']: E(i,'answer not in options')
        if rd['options'].count(rd['answer'])!=1: E(i,'answer repeated')
        if len(set(rd['options']))!=len(rd['options']): E(i,'dup options')
        sp=rd['shown'].split('.'); ap=rd['answer'].split('.')
        if sp[2]!=ap[2] or sp[0]!=ap[0] or sp[1]==ap[1]: E(i,'answer does not match shown')
    elif t==3:
        rd['characters']=lst(top); rd['pieces']=lst(opts); pairs=[]
        for p in ans.split(';'):
            c,ps=p.split('→'); pairs.append({'character':tok(c),'pieces':[tok(x) for x in ps.split('&')]})
        rd['pairs']=pairs
        if sorted(p['character'] for p in pairs)!=sorted(rd['characters']): E(i,'pairs vs characters')
        if sorted(x for p in pairs for x in p['pieces'])!=sorted(rd['pieces']): E(i,'pairs vs pieces')
        for p in pairs:
            c=p['character'].split('.')
            for x in p['pieces']:
                xp=x.split('.')
                if xp[2]!=c[2] or (c[0]!='shaded' and xp[0]!=c[0]): E(i,'bad pair '+str(p))
    elif t==4:
        m2=re.fullmatch(r'Shelf: ([WB]) team silhouettes K1 Q1 R2 B2 N2 P8',top.strip())
        if not m2: E(i,'shelf text'); continue
        rd['shelf']=COL[m2[1]]
        if '+ distractors:' in opts: a,b=opts.split('+ distractors:'); rd['toPlace']=lst(a); rd['distractors']=lst(b)
        else: rd['toPlace']=lst(opts); rd['distractors']=[]
        rd['prefilled']=lst(pre)
        team=rd['toPlace']+rd['prefilled']
        cnt=collections.Counter(x.split('.')[2] for x in team)
        if cnt!={'king':1,'queen':1,'rook':2,'bishop':2,'knight':2,'pawn':8}: E(i,f'team not 16: {cnt}')
        if any(x.split('.')[0]!=rd['shelf'] for x in team): E(i,'team colour')
        if any(x.split('.')[0]==rd['shelf'] for x in rd['distractors']): E(i,'distractor colour')
        if len({x.split('.')[1] for x in team+rd['distractors']})!=1: E(i,'mixed forms')
        mm=re.search(r'All (\d+)',ans)
        if not mm or int(mm[1])!=len(rd['toPlace']): E(i,'place count text')
    elif t==5:
        k=re.fullmatch(r'(\S+) \(top-left\) & (\S+) \(top-right\)',top.strip())
        rd['kings']={'white':tok(k[1]),'black':tok(k[2])}
        rd['toPlace']=lst(opts)
        w,b=pre.split('|'); assert w.strip().startswith('W:') and b.strip().startswith('B:'), i
        rd['prefilled']={'white':lst(w.strip()[2:]),'black':lst(b.strip()[2:])}
        for col in ('white','black'):
            team=[rd['kings'][col]]+[x for x in rd['toPlace'] if x.startswith(col)]+rd['prefilled'][col]
            cnt=collections.Counter(x.split('.')[2] for x in team)
            if cnt!={'king':1,'queen':1,'rook':2,'bishop':2,'knight':2,'pawn':8}: E(i,f'{col} team not 16: {dict(cnt)}')
            if any(not x.startswith(col) for x in rd['prefilled'][col]): E(i,'prefill colour')
        rd['placeEach']={c:sum(x.startswith(c) for x in rd['toPlace']) for c in ('white','black')}
    if r['Note'].strip(): rd['note']=r['Note'].strip()
    ex=pool.setdefault(code,{'code':code,'type':t,'levels':collections.OrderedDict()})
    lv=ex['levels'].setdefault(str(lvl),{'possibleVariants':int(r['Possible variants']),'rounds':[]})
    if lv['possibleVariants']!=int(r['Possible variants']): E(i,'possible variants differs in level')
    lv['rounds'].append(rd)
# per-level checks
for code,ex in pool.items():
    for l,lv in ex['levels'].items():
        vs=[r['variant'] for r in lv['rounds']]
        if vs!=list(range(1,len(vs)+1)): E(code+'-'+l,'variants not 1..n')
        keys=[json.dumps({k:v for k,v in r.items() if k not in('id','variant','note')},sort_keys=True) for r in lv['rounds']]
        if len(set(keys))!=len(keys): E(code+'-'+l,'duplicate rounds')
        if len(vs)>lv['possibleVariants']: E(code+'-'+l,'more rounds than possible')
ids=[r['ID'] for r in rows]; assert len(set(ids))==len(ids)
print('rows',len(rows),'exercises',len(pool))
if errs: sys.exit('\n'.join(errs))
doc={'source':os.path.basename(sys.argv[1]),
     'idFormat':'LLL-M-TT-EE-V-III (III = pool row number, unique across Lesson 1)',
     'itemFormat':'<colour>.<form>.<piece>; colour = white | black | shaded; form = character | piece',
     'exercises':list(pool.values())}
def dump(doc):
    J=lambda o: json.dumps(o,ensure_ascii=False)
    L=['{']+[f'  {J(k)}: {J(doc[k])},' for k in ('source','idFormat','itemFormat')]+['  "exercises": [']
    for n,ex in enumerate(doc['exercises']):
        L.append(f'    {{"code": {J(ex["code"])}, "type": {ex["type"]}, "levels": {{')
        lv=list(ex['levels'].items())
        for m,(l,v) in enumerate(lv):
            L.append(f'      {J(l)}: {{"possibleVariants": {v["possibleVariants"]}, "rounds": [')
            L+=[f'        {J(r)}'+(',' if j<len(v['rounds'])-1 else '') for j,r in enumerate(v['rounds'])]
            L.append('      ]}'+(',' if m<len(lv)-1 else ''))
        L.append('    }}'+(',' if n<len(doc['exercises'])-1 else ''))
    return '\n'.join(L+['  ]','}'])+'\n'
open(out,'w').write(dump(doc))
# summary
for code,ex in pool.items():
    if ex['type'] in (3,5):
        for l,lv in ex['levels'].items():
            if ex['type']==3: sp={(sum(c.startswith('white') for c in r['characters']),sum(c.startswith('black') for c in r['characters'])) for r in lv['rounds']}
            else: sp={(r['placeEach']['white'],r['placeEach']['black']) for r in lv['rounds']}
            print(code,'L'+l,'white/black',sorted(sp))
