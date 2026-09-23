from pathlib import Path
import argparse, csv, hashlib, json, time, os
import numpy as np
from PIL import Image
from rdh_capacity import (arithmetic_map,decode_arithmetic_map,idpvo_iteration,
                          mhm_prepare,mhm_embed,mhm_options,mhm_optimize)

ROOT=Path(__file__).parent
OUT=Path(os.environ.get('RDHEI_BASELINE_OUTPUT',str(ROOT.parents[2]/'results/generated/paper/table10')))
INPUT=Path(os.environ.get('RDHEI_BASELINE_INPUT',str(ROOT/'inputs')))
OUT.mkdir(parents=True,exist_ok=True)
LABELS=['Man','Jetplane','Baboon','Tiffany']

def save_json(path,value):
    Path(path).write_text(json.dumps(value,ensure_ascii=False,indent=2,default=lambda x:x.item() if isinstance(x,np.generic) else x.tolist()),encoding='utf-8')

def verify():
    rng=np.random.default_rng(9020)
    for n,p in [(0,0),(1,1),(200,0),(200,1),(400,.5),(262144,.008),(500,.9)]:
        a=(rng.random(n)<p).astype(np.uint8);encoded=arithmetic_map(a,True)
        assert np.array_equal(a,decode_arithmetic_map(encoded))
    # Capacity DP versus exhaustive search on 3 artificial histograms.
    import itertools
    H=np.zeros((16,511),dtype=np.int64);H[:3,245:266]=rng.integers(0,20,(3,21))
    for delta in [1,2,3]:
        states,cap=mhm_options(H,delta);brute=-1
        for s in itertools.product(range(len(states)),repeat=3):
            vals=[states[i] for i in s]
            if vals[0][0]!=delta:continue
            if all(vals[i][0]>=vals[i+1][0] and vals[i][1]<=vals[i+1][1] for i in [0,1]):
                brute=max(brute,sum(cap[i,s[i]] for i in range(3)))
        best,params,_=mhm_optimize(H,delta);assert best==brute
    # Hand-computable forward rules, all image updates must stay in uint8 range.
    test=np.array([[163,164,167],[162,166,166],[204,205,247],[202,203,249]],dtype=np.int16)
    _,s=idpvo_iteration(test,np.random.default_rng(0),'horizontal')
    assert s['forward_gross_bits']==3
    save_json(OUT/'verification.json',{'arithmetic_roundtrip':True,'mhm_dp_vs_bruteforce':True,
                                      'idpvo_example_forward_count':3,'full_image_recovery_tested':False})
    print('Verification passed: arithmetic maps, MHM optimization, I-DPVO forward example.',flush=True)

def idpvo(image,label,domain):
    rows=[]
    for seed in [0,1,2]:
        rng=np.random.default_rng(seed);work=image.copy();gross=aux=0;start=time.perf_counter()
        for iteration in range(1,4):
            orientation='horizontal' if iteration%2 else 'vertical'
            work,r=idpvo_iteration(work,rng,orientation)
            gross+=r['gross_bits'];aux+=r['aux_bits']
            r.update(image=label,domain=domain,method='I-DPVO',seed=seed,iteration=iteration,
                     orientation=orientation,cumulative_gross_bits=gross,cumulative_aux_bits=aux,
                     cumulative_balance_bits=gross-aux,net_capacity_estimate_bits=max(0,gross-aux),
                     gross_bpp=gross/image.size,ecc_estimate_bpp=max(0,gross-aux)/image.size,
                     psnr_db=float(10*np.log10(255**2/np.mean((work.astype(float)-image)**2))),
                     elapsed_seconds=time.perf_counter()-start)
            rows.append(r)
    save_json(OUT/f'{label}_{domain}_idpvo.json',rows)
    r=rows[2]
    print(f'I-DPVO {label} {domain}: R=3 seed0 gross={r["cumulative_gross_bits"]} aux={r["cumulative_aux_bits"]} net_est={r["net_capacity_estimate_bits"]}',flush=True)
    return rows

def mhm(image,label,domain):
    rows=[];probes=[]
    # Capacity only, candidates fixed from the paper. Two chessboard layers
    # receive equal secret payload; each also pays its own auxiliary length.
    for delta in range(1,7):
        started=time.perf_counter();first=mhm_prepare(image,delta,0)
        upper=first['gross']-first['aux'];rng=np.random.default_rng(0)
        data=rng.integers(0,2,first['gross'],dtype=np.int16);cache={}
        def probe(half):
            half=int(half)
            if half in cache:return cache[half]
            marked=mhm_embed(first,half,data)
            assert marked is not None
            second=mhm_prepare(marked,delta,1)
            margin=second['gross']-second['aux']-half
            info={'half_payload_bits':half,'second_gross_bits':second['gross'],
                  'second_aux_bits':second['aux'],'second_lm_bits':second['location_map_bits'],
                  'second_lm_ones':second['location_map_ones'],'second_margin_bits':margin,
                  'second_params':second['params'].tolist(),
                  'second_threshold_width':second['threshold_width'],
                  'feasible':margin>=0}
            cache[half]=info
            return info
        best=-1
        if upper>=0:
            grid=np.unique(np.rint(np.linspace(0,upper,9)).astype(int))
            for half in grid:
                r=probe(half)
                if r['feasible']:best=max(best,int(half))
            if best>=0 and best<upper:
                high=min(x for x in grid if x>best);low=best
                while high-low>16:
                    middle=(low+high)//2;r=probe(middle)
                    if r['feasible']:low=middle;best=max(best,middle)
                    else:high=middle
                for half in np.arange(max(0,low-24),min(upper,high+32)+1,4):
                    if probe(half)['feasible']:best=max(best,int(half))
        selected=cache.get(best,{})
        result={'method':'HC-MHM','image':label,'domain':domain,'delta_max':6,'delta':delta,
                'seed':0,'first_gross_bits':first['gross'],'first_aux_bits':first['aux'],
                'first_lm_bits':first['location_map_bits'],'first_lm_ones':first['location_map_ones'],
                'first_threshold_width':first['threshold_width'],'first_params':first['params'].tolist(),
                'first_relaxed_upper_bits':first['relaxed'],'first_net_balance_bits':upper,
                'net_capacity_estimate_bits':max(0,2*best),'ecc_estimate_bpp':max(0,2*best)/image.size,
                'positive_payload_found':best>0,'probes':len(cache),
                'elapsed_seconds':time.perf_counter()-started,**selected}
        rows.append(result)
        for p in cache.values():probes.append({'image':label,'domain':domain,'delta':delta,**p})
        save_json(OUT/f'{label}_{domain}_mhm.json',rows)
        save_json(OUT/f'{label}_{domain}_mhm_probes.json',probes)
        print(f'HC-MHM {label} {domain} delta={delta}: first {first["gross"]}-{first["aux"]}; net_est={result["net_capacity_estimate_bits"]}; {len(cache)} probes; {result["elapsed_seconds"]:.1f}s',flush=True)
    return rows

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--method',choices=['all','mhm','idpvo'],default='all')
    parser.add_argument('--image',default='all');parser.add_argument('--verify-only',action='store_true')
    args=parser.parse_args()
    verify()
    if args.verify_only:return
    for label in LABELS if args.image=='all' else [args.image]:
        for domain in ['plaintext','ciphertext']:
            image=np.asarray(Image.open(INPUT/f'{label}_{domain}.png'),dtype=np.int16)
            if args.method in ['all','idpvo']:idpvo(image,label,domain)
            if args.method in ['all','mhm']:mhm(image,label,domain)
    print('Capacity experiments finished; no payload extraction or image recovery run.',flush=True)

if __name__=='__main__':main()
