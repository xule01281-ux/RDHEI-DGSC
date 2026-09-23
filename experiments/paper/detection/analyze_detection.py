from pathlib import Path
import json,numpy as np
import argparse
args=argparse.ArgumentParser()
args.add_argument('--input',type=Path,required=True)
args.add_argument('--output',type=Path,required=True)
args=args.parse_args()
out=args.input
args.output.mkdir(parents=True,exist_ok=True)
def auc(y,s):
 order=np.argsort(s,kind='stable');sort=s[order];rank=np.empty(len(s));a=0
 while a<len(s):
  b=a+1
  while b<len(s) and sort[b]==sort[a]:b+=1
  rank[order[a:b]]=(a+b+1)/2;a=b
 n=y.sum();return float((rank[y==1].sum()-n*(n+1)/2)/(n*(len(y)-n)))
def metrics(y,s):
 p=s>=.5;return {'auc':auc(y,s),'balanced_accuracy':float(((p[y==1]).mean()+(~p[y==0]).mean())/2)}
def fit_score(X,y,Z):
 # Ridge linear least squares, fixed penalty chosen before pilot; no test tuning.
 mean=X.mean(0);std=X.std(0);std[std<1e-9]=1
 X=(X-mean)/std;Z=(Z-mean)/std
 X=np.column_stack([np.ones(len(X)),X]);Z=np.column_stack([np.ones(len(Z)),Z])
 reg=np.eye(X.shape[1])*10;reg[0,0]=0
 w=np.linalg.solve(X.T@X+reg,X.T@y);return Z@w
def analyze(stage):
 files=sorted(out.glob(f'security_{stage}_[12].json'))
 if len(files)!=2:return
 rows=[];fail=[]
 for p in files:
  d=json.loads(p.read_text(encoding='utf-8'));rows+=d['rows'];fail+=d['failures']
 if not rows:return
 ids=[a['id'] for a in rows];assert len(ids)==len(set(ids))
 expected=200 if stage=='pilot' else 1000
 assert len(rows)==expected and not fail, 'Incomplete experiment: do not summarize partial chunks as the formal study'
 A=np.array([a['features'] for a in rows]);train=np.array([a['split']=='train' for a in rows]);test=~train
 assert train.sum()==int(expected*.7) and test.sum()==int(expected*.3)
 results=[]
 for neg,pos,name in [(0,1,'AES vs zero payload'),(0,4,'AES vs full payload'),(1,2,'zero vs 25 percent'),(1,3,'zero vs 50 percent'),(1,4,'zero vs full payload')]:
  X=np.concatenate([A[train,neg],A[train,pos]]);Z=np.concatenate([A[test,neg],A[test,pos]])
  y=np.repeat([0,1],train.sum());yt=np.repeat([0,1],test.sum())
  for mode in ['statistics_only','statistics_and_public_parser']:
   cols=slice(None,-1) if mode=='statistics_only' else slice(None)
   score=fit_score(X[:,cols],y,Z[:,cols]);m=metrics(yt,score)
   # Source-paired bootstrap retains the paired cover/payload observations.
   rng=np.random.default_rng(7819);cis=[];n=test.sum()
   for _ in range(500):
    idx=rng.integers(0,n,n);ix=np.r_[idx,idx+n];cis.append(auc(yt[ix],score[ix]))
   m.update({'auc_ci95':np.quantile(cis,[.025,.975]).tolist(),'comparison':name,'detector':mode})
   results.append(m)
 report={'stage':stage,'sources':len(rows),'train_sources':int(train.sum()),'test_sources':int(test.sum()),
 'failures':fail,'random_baseline':{'auc':.5,'balanced_accuracy':.5},'results':results,
 'detector':'302 grayscale/bit-plane/spatial statistics; optionally 1 public-format parser success flag. Fixed ridge penalty 10, threshold 0.5.',
 'protocol':'Independent source-image split; paired ciphertext variants remain in same split; zero padding encrypted in all unused slots; payload length kept in public external context.'}
 (args.output/f'detection_{stage}.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print(stage,len(rows),'failures',len(fail),[(x['comparison'],x['detector'],round(x['auc'],4)) for x in results])
for stage in ['pilot','formal']:analyze(stage)
