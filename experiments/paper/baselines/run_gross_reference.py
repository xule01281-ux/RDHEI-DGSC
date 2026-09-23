"""Favourable comparison: forward-simulated gross slots with ALL side costs waived."""
from pathlib import Path
import json,time
import numpy as np
from PIL import Image
from rdh_capacity import mhm_prepare,mhm_embed,idpvo_iteration
from run_comparison import save_json,ROOT,OUT,LABELS,INPUT

def run():
    rows=[]
    for label in LABELS:
        for domain in ['plaintext','ciphertext']:
            image=np.asarray(Image.open(INPUT/f'{label}_{domain}.png'),dtype=np.int16)
            for delta in range(1,7):
                for seed in [0,1,2]:
                    rng=np.random.default_rng(seed);first=mhm_prepare(image,delta,0)
                    # Waive costs to give the comparator a favourable gross figure.
                    f=dict(first);f['aux']=0
                    stage1=mhm_embed(f,f['gross'],rng.integers(0,2,f['gross'],dtype=np.int16))
                    second=mhm_prepare(stage1,delta,1);s=dict(second);s['aux']=0
                    final=mhm_embed(s,s['gross'],rng.integers(0,2,s['gross'],dtype=np.int16))
                    gross=first['gross']+second['gross']
                    row={'image':label,'domain':domain,'method':'HC-MHM','delta':delta,'seed':seed,
                         'first_gross_bits':first['gross'],'second_gross_bits':second['gross'],
                         'gross_bits':gross,'gross_bpp':gross/image.size,
                         'counted_aux_bits':first['aux']+second['aux'],
                         'net_balance_for_full_layers_bits':gross-first['aux']-second['aux'],
                         'min_pixel':int(final.min()),'max_pixel':int(final.max()),
                         'psnr_db':float(10*np.log10(255**2/np.mean((final.astype(float)-image)**2))),
                         'first_params':first['params'].tolist(),'second_params':second['params'].tolist(),
                         'accounting':'all available slots of both layers; no auxiliary costs deducted; not net ECC'}
                    rows.append(row)
            save_json(OUT/'mhm_gross_reference.json',rows)
            best=max((r for r in rows if r['image']==label and r['domain']==domain),key=lambda r:r['gross_bits'])
            print(f'HC-MHM gross {label} {domain}: {best["gross_bits"]} bits, {best["gross_bpp"]:.6f} bpp, delta={best["delta"]}',flush=True)
    print('Gross reference complete.',flush=True)

if __name__=='__main__':run()
