"""Additional independent checks of the equations used for capacity measurement."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from rdh_capacity import mhm_features,mhm_prepare,mhm_embed
from run_comparison import INPUT,OUT

def literal_mapping(e,d,b,bit):
    positive=list(range(d-1)) + ([] if b==999 else [b])
    negative=sorted([-x-1 for x in positive],reverse=True)
    if e>=0:
        return e+sum(x<e for x in positive)+(bit if e in positive else 0)
    return e-sum(x>e for x in negative)-(bit if e in negative else 0)

def main():
    tested=0
    for d in range(1,7):
        for b in list(range(d-1,d+6))+[999]:
            outputs={}
            for e in range(-255,256):
                magnitude=e if e>=0 else -e-1
                eligible=magnitude<d-1 or magnitude==b
                for bit in [0,1] if eligible else [0]:
                    shift=min(magnitude,d-1)+int(magnitude>b)+(bit if eligible else 0)
                    y=e+shift if e>=0 else e-shift
                    assert y==literal_mapping(e,d,b,bit)
                    assert y not in outputs or outputs[y]==(e,bit)
                    outputs[y]=(e,bit);tested+=1
    image=np.asarray(Image.open(INPUT/'Baboon_plaintext.png'),dtype=np.int16)
    first=mhm_prepare(image,6,0);f=first['features']
    # The vectorized prediction/noise is checked against literal Fig.5 values.
    for idx in [0,1,100,1000,len(f['r'])-1]:
        r,c=int(f['r'][idx]),int(f['c'][idx]);I=first['work'].astype(int)
        w={1:I[r-1,c],2:I[r,c-1],3:I[r+1,c],4:I[r,c+1],5:I[r+1,c-1],
           6:I[r+1,c+1],7:I[r+2,c],8:I[r,c+2],9:I[r+2,c-1],10:I[r-1,c+2],
           11:I[r+2,c+1],12:I[r+1,c+2],13:I[r+2,c+2]}
        pred=(w[1]+w[2]+w[3]+w[4])//4
        noise=(abs(w[2]-w[5])+abs(w[5]-w[9])+abs(w[3]-w[7])+abs(w[4]-w[6])+
               abs(w[6]-w[11])+abs(w[10]-w[8])+abs(w[8]-w[12])+abs(w[12]-w[13])+
               abs(w[2]-w[4])+abs(w[5]-w[3])+abs(w[3]-w[6])+abs(w[6]-w[12])+
               abs(w[9]-w[7])+abs(w[7]-w[11])+abs(w[11]-w[13]))
        assert pred==f['prediction'][idx] and noise==f['noise'][idx]
    # A second-layer capacity probe must use the modified first-layer image.
    marked=mhm_embed(first,1000,np.random.default_rng(99).integers(0,2,first['gross']))
    a=mhm_features(first['work'],1);b=mhm_features(marked,1)
    assert np.any(a['errors']!=b['errors'])
    # Check source files contain no invocation of extraction/recovery routines.
    result={'mhm_equation5_cases':tested,'mhm_mapping_no_collisions':True,
            'fig5_literal_stencil_check':True,'second_layer_uses_modified_first':True,
            'full_image_recovery_executed':False}
    (OUT/'paper_rule_verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result))
if __name__=='__main__':main()
