"""Regenerate Tables 3,4,5,7,8,10,11,12 from archived numerical records.

Does not encode images, run datasets, or change reference records.
"""
from pathlib import Path
import argparse,csv,json,math,statistics,subprocess,sys

ROOT=Path(__file__).resolve().parents[2]
LABEL={'11.png':'Man','Jetplane.tiff':'Jetplane','Baboon.tiff':'Baboon','Tiffany.tiff':'Tiffany'}
ORDER=['Man','Jetplane','Baboon','Tiffany']
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def dump(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf-8')
def csv_out(p,rows):
    with p.open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def near(a,b):assert math.isclose(a,b,abs_tol=1e-9,rel_tol=1e-10),(a,b)
def normalized(x):return LABEL.get(x,x)

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--reference',type=Path,default=ROOT/'results/paper')
    p.add_argument('--output',type=Path,default=ROOT/'results/generated/paper_summary')
    args=p.parse_args();ref=args.reference.resolve();out=args.output.resolve()
    assert out!=ref and ref not in out.parents,'Do not overwrite paper reference records'
    out.mkdir(parents=True,exist_ok=True);audit={};totals={};all_tables={}
    # Table 3: train the fixed detector again from the original stored features.
    subprocess.run([sys.executable,str(Path(__file__).parent/'detection/analyze_detection.py'),
                    '--input',str(ref/'table3'),'--output',str(out/'table3')],check=True)
    manifest=read(ref/'table3/security_manifest.json')
    hashes=[]
    for stage,count in [('pilot',200),('formal',1000)]:
        old=read(ref/f'table3/detection_{stage}.json');new=read(out/f'table3/detection_{stage}.json')
        assert new['sources']==count and not new['failures']
        source_rows=[]
        for i in [1,2]:source_rows+=read(ref/f'table3/security_{stage}_{i}.json')['rows']
        lookup={r['id']:r for r in manifest[stage]};assert len(lookup)==count
        for r in source_rows:
            m=lookup[r['id']];assert r['sha256']==m['sha256'] and r['split']==m['split']
            assert len(r['features'])==5 and all(len(f)==303 for f in r['features'])
        hashes += [r['sha256'] for r in manifest[stage]]
        for a,b in zip(old['results'],new['results']):
            assert (a['comparison'],a['detector'])==(b['comparison'],b['detector'])
            for k in ['auc','balanced_accuracy']:near(a[k],b[k])
            for x,y in zip(a['auc_ci95'],b['auc_ci95']):near(x,y)
    assert len(hashes)==len(set(hashes))==1200
    table3=read(out/'table3/detection_formal.json')['results']
    csv_out(out/'table3.csv',[{k:v for k,v in r.items() if k!='auc_ci95'} for r in table3])
    audit['table3']='PASS: all 1200 source identities/splits disjoint; AUC, BA and paired bootstrap intervals regenerated'
    all_tables['table3']=table3
    # Table 4: each stage is measured against the same original image.
    raw=read(ref/'table4/table4_raw.json');rows=raw['rows'];assert len(rows)==20
    assert len({r['credentials_sha256'] for r in rows})==20
    assert all(all(r['summary'][k] for k in ['payload_ok','auxiliary_ok','image_recovery_ok','scramble_ok']) for r in rows)
    tab=[];old=read(ref/'table4/table4_summary.json')['summary']
    for label in ['Baboon','Jetplane','Tiffany','Man']:
        rr=[r for r in rows if r['image']==label];assert len(rr)==5
        totals[label]=rr[0]['summary']['payload_bits']
        for stage in ['cipher','marked','recovered']:
            item={'image':label,'stage':stage,'repetitions':5}
            for metric in ['psnr_db','ssim','entropy','mae']:
                vals=[r[stage][metric] for r in rr]
                if metric=='psnr_db' and stage=='recovered':mean='Inf';sd=0
                else:mean=statistics.mean(vals);sd=statistics.stdev(vals)
                item[metric+'_mean']=mean;item[metric+'_std']=sd
            source=next(x for x in old if x['image']==label and x['stage']==stage)
            for k,v in item.items():
                if isinstance(v,(float,int)):near(v,source[k])
                else:assert v==source[k]
            tab.append(item)
        assert all(r['recovered']['mae']==0 and r['recovered']['ssim']==1 and r['recovered']['pixel_mismatches']==0 for r in rr)
    all_tables['table4']=tab;csv_out(out/'table4.csv',tab);audit['table4']='PASS: 20 original round trips and 12 stage means'
    assert sum(totals.values())==3380795
    # Table 5: actual net capacity and all header state bits.
    rr=read(ref/'table5/capacity.json')['rows'];assert len(rr)==16
    tab=[]
    for r in rr:
        assert r['status']=='pass';near(r['ecc_bpp'],r['payload_bits']/262144)
        if r['block_h']==16:assert r['payload_bits']==totals[r['image']]
        tab.append({'image':r['image'],'block_size':r['block_h'],'payload_bits':r['payload_bits'],
                    'auxiliary_bits':r['block_header_bits']+r['global_auxiliary_bits'],'ecc_bpp':r['ecc_bpp']})
    all_tables['table5']=tab;csv_out(out/'table5.csv',tab);audit['table5']='PASS: 16 block-size measurements'
    # All seven SCEC configurations, including the three response-only groups.
    rr=read(ref/'table7/ablation.json');assert len(rr)==28;tab=[]
    for group in dict.fromkeys(r['group'] for r in rr):
        cases=[r for r in rr if r['group']==group];assert len(cases)==4
        row={'configuration':group}
        for label in ORDER:
            r=next(r for r in cases if normalized(r['image'])==label)
            row[label+'_bits']=r['data']['payload_bits'];row[label+'_ecc']=r['data']['ecc_bpp']
        row['total_bits']=sum(row[x+'_bits'] for x in ORDER);row['mean_ecc']=row['total_bits']/(4*262144)
        row['loss_from_full_bits']=3380795-row['total_bits'];tab.append(row)
    assert next(x for x in tab if x['configuration']=='no_scec')['loss_from_full_bits']==7626
    all_tables['table7']=tab;csv_out(out/'table7_all_seven.csv',tab);audit['table7']='PASS: 28 runs; full-minus-disabled = 7626 bit'
    # Table 8 finite best excludes the first-row/column baseline.
    rr=read(ref/'table8/capacity.json');tab=[]
    for label in ORDER:
        axis=[r for r in rr if normalized(r['image'])==label and r['group']=='axis'];assert len(axis)==11
        assert axis[0]['split']==[1,1] and axis[1]['split']==[256,256]
        centroid=axis[2]['split'];expected=[[1,1],[256,256],centroid,[128,128],[128,256],[128,384],[256,128],[256,384],[384,128],[384,256],[384,384]]
        assert [r['split'] for r in axis]==expected
        best=max(axis[1:],key=lambda x:x['data']['payload_bits'])
        row={'image':label,'first':axis[0]['data']['ecc_bpp'],'geometric':axis[1]['data']['ecc_bpp'],
             'centroid':axis[2]['data']['ecc_bpp'],'finite_best':best['data']['ecc_bpp'],
             'finite_best_row':best['split'][0],'finite_best_col':best['split'][1]}
        assert axis[2]['data']['payload_bits']==totals[label];tab.append(row)
        saved=next(r for r in read(ref/'table8/capacity_summary.json') if normalized(r['image'])==label)
        assert best==saved['finite_best']
    all_tables['table8']=tab;csv_out(out/'table8.csv',tab);audit['table8']='PASS: 44 axis runs; correct 10-candidate maximum'
    # Table 10 fixes payload seed 0, independently optimizes delta 1..6.
    gross=read(ref/'table10/mhm_gross_reference.json');tab=[]
    for label in ORDER:
        row={'image':label}
        for domain in ['plaintext','ciphertext']:
            a=[r for r in gross if r['image']==label and r['domain']==domain and r['seed']==0]
            assert len(a)==6
            best=max(a,key=lambda x:x['gross_bits']);assert best['delta']==6
            row['mhm_'+domain+'_gross']=best['gross_bpp']
            b=read(ref/f'table10/{label}_{domain}_idpvo.json')
            b=next(r for r in b if r['seed']==0 and r['iteration']==3)
            row['idpvo_'+domain+'_gross']=b['gross_bpp']
        row['proposed_net']=totals[label]/262144;tab.append(row)
    all_tables['table10']=tab;csv_out(out/'table10.csv',tab);audit['table10']='PASS: fixed seed 0; baseline gross and proposed net kept distinct'
    # Formal timing, sample SD (ddof=1), paired four-image totals.
    t=read(ref/'table11/timing.json');assert t['warmups_per_image']==2 and t['repetitions_per_image']==10
    assert len(t['forward_seconds'])==10 and t['all_checks_passed'];tab=[]
    for k,label in enumerate(t['labels']):
        vals=[r[k] for r in t['forward_seconds']];mean=statistics.mean(vals);sd=statistics.stdev(vals)
        near(mean,t['mean_seconds'][k]);near(sd,t['std_seconds'][k]);assert all(r[k]==totals[label] for r in t['payload_bits'])
        tab.append({'image':label,'mean_seconds':mean,'sd_seconds':sd,'payload_bits':totals[label]})
    sums=[sum(r) for r in t['forward_seconds']];near(statistics.mean(sums),t['total_seconds_mean']);near(statistics.stdev(sums),t['total_seconds_std'])
    all_tables['table11']=tab;csv_out(out/'table11.csv',tab);audit['table11']='PASS: 40 measurements; 11.1425245 s mean paired total'
    # The damage suite quantifies exact success, not authentication.
    rows=read(ref/'table12/damage.json')['rows'];assert len(rows)==148;tab=[]
    for attack,level in dict.fromkeys((r['attack'],r['level']) for r in rows):
        rr=[r for r in rows if r['attack']==attack and r['level']==level]
        row={'attack':attack,'level':level,'trials':len(rr)}
        for k in ['extraction_completed','payload_exact','image_exact','joint_exact']:row[k]=sum(bool(r['result'][k]) for r in rr)
        tab.append(row)
        source=next(r for r in read(ref/'table12/retest_summary.json')['damage'] if r['attack']==attack and r['level']==level)
        for k,v in row.items():assert v==source[k],(k,v,source[k])
    assert sum(r['joint_exact'] for r in tab)==4
    all_tables['table12']=tab;csv_out(out/'table12.csv',tab);audit['table12']='PASS: 148 records, 4/4 intact controls, 0/144 joint damaged recovery'
    dump(out/'tables.json',all_tables);dump(out/'verification.json',{'checks':audit,'status':'PASS','new_encoding_experiments':False,'full_dataset_runs':False})
    print(json.dumps(audit,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
