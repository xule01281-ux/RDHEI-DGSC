"""Paper-based capacity-only reimplementations; not author code or full codecs.

Sources: Ou & Zhao, TCSVT 2020, doi:10.1109/TCSVT.2019.2921812;
Wahed & Nyeem, AEJ 2025, doi:10.1016/j.aej.2025.02.088.
All arrays use signed integers. No image recovery is performed.
"""
from __future__ import annotations
import math
import numpy as np


def arithmetic_map(bits, return_stream=False):
    """Actual static binary arithmetic encoding, 32-bit interval.

    Accounting includes 1 mode bit, 19-bit length, 19-bit one-count,
    19-bit code length. Constant map: mode + length + value (21 bits).
    Stream bit count includes the termination; no ideal-entropy substitution.
    The papers specify arithmetic coding but not a particular coder/model.
    """
    bits=np.asarray(bits, dtype=np.uint8).ravel()
    n=int(bits.size); ones=int(bits.sum())
    if n==0 or ones in (0,n):
        return {'bits':21, 'symbols':n, 'ones':ones, 'coded_bits':0,
                'model':'constant', 'stream':bytes([int(ones>0)]) if return_stream else None}
    zero=n-ones; low=0; high=(1<<32)-1; pending=0; count=0; stream=[]
    half=1<<31; quarter=1<<30; three=3*quarter
    def emit(bit):
        nonlocal pending,count
        count+=1+pending
        if return_stream: stream.extend([bit]+[1-bit]*pending)
        pending=0
    for bit in bits:
        split=low+((high-low+1)*zero)//n
        if bit: low=split
        else: high=split-1
        while True:
            if high<half: emit(0)
            elif low>=half:
                emit(1);low-=half;high-=half
            elif low>=quarter and high<three:
                pending+=1;low-=quarter;high-=quarter
            else: break
            low*=2;high=high*2+1
    pending+=1;emit(int(low>=quarter))
    return {'bits':58+count,'symbols':n,'ones':ones,'coded_bits':count,
            'model':'static_binary_arithmetic', 'stream':bytes(stream) if return_stream else None}


def decode_arithmetic_map(info):
    n=info['symbols'];ones=info['ones']
    if info['model']=='constant':return np.full(n,int(ones>0),dtype=np.uint8)
    code=info['stream']; pos=0
    def get():
        nonlocal pos
        b=code[pos] if pos<len(code) else 0;pos+=1;return int(b)
    low=0;high=(1<<32)-1;value=0;half=1<<31;quarter=1<<30;three=3*quarter
    for _ in range(32):value=value*2+get()
    out=np.empty(n,np.uint8);zero=n-ones
    for i in range(n):
        split=low+((high-low+1)*zero)//n
        b=int(value>=split);out[i]=b
        if b:low=split
        else:high=split-1
        while True:
            if high<half:pass
            elif low>=half:low-=half;high-=half;value-=half
            elif low>=quarter and high<three:low-=quarter;high-=quarter;value-=quarter
            else:break
            low*=2;high=high*2+1;value=value*2+get()
    return out


def idpvo_iteration(image, rng, orientation):
    """Eqs (1)-(4), Algorithms 1-2; nonoverlapping triples within rows.

    Even iteration is vertical (transpose); last 2 ungrouped pixels per
    scanline remain unchanged. Eq (4b)'s >-1 typo is read as <-1, required
    by its negative error domain and symmetric Eqs (2d),(3b).
    """
    work=(image.T if orientation=='vertical' else image).copy().astype(np.int16)
    h,w=work.shape;usable=w-w%3
    lm=(work==0)|(work==255)
    work[work==0]=1;work[work==255]=254
    boundary=arithmetic_map(lm)
    triples=work[:,:usable].reshape(-1,3).copy()
    order=np.argsort(triples,axis=1,kind='stable')
    vals=np.take_along_axis(triples,order,axis=1)
    dmin=vals[:,1]-vals[:,0];dmax=vals[:,2]-vals[:,1]
    min_bits=rng.integers(0,2,int(np.count_nonzero(dmin==1)),dtype=np.int16)
    max_bits=rng.integers(0,2,int(np.count_nonzero(dmax==1)),dtype=np.int16)
    vals[dmin>1,0]-=1;vals[dmin==1,0]-=min_bits
    vals[dmax>1,2]+=1;vals[dmax==1,2]+=max_bits
    forward=int(min_bits.size+max_bits.size)
    eligible_min=(vals[:,1]-vals[:,0])>1
    eligible_max=(vals[:,2]-vals[:,1])>1
    skipped_min=arithmetic_map(~eligible_min);skipped_max=arithmetic_map(~eligible_max)
    back=0
    for column,eligible,sign in [(0,eligible_min,1),(2,eligible_max,-1)]:
        locations=np.flatnonzero(eligible);locations=locations[:len(locations)//2*2].reshape(-1,2)
        pairs=vals[locations,column]
        sorted_order=np.argsort(pairs,axis=1,kind='stable')
        pair_values=np.take_along_axis(pairs,sorted_order,axis=1)
        gaps=pair_values[:,1]-pair_values[:,0]
        data=rng.integers(0,2,int(np.count_nonzero(gaps==1)),dtype=np.int16)
        changes=(gaps>1).astype(np.int16);changes[gaps==1]=data
        target=locations[np.arange(len(locations)),sorted_order[:,1 if sign==1 else 0]]
        vals[target,column]+=sign*changes
        back+=len(data)
    np.put_along_axis(triples,order,vals,axis=1)
    work[:,:usable]=triples.reshape(h,usable)
    assert work.min()>=0 and work.max()<=255
    # Iteration/direction/stop metadata: explicit measurement convention.
    header=8+1+19
    aux=boundary['bits']+skipped_min['bits']+skipped_max['bits']+header
    result={'forward_gross_bits':forward,'backward_gross_bits':back,
            'gross_bits':forward+back,'boundary_map_bits':boundary['bits'],
            'boundary_ones':boundary['ones'],'skip_min_map_bits':skipped_min['bits'],
            'skip_max_map_bits':skipped_max['bits'],'skip_min_ones':skipped_min['ones'],
            'skip_max_ones':skipped_max['ones'],'skip_map_symbols_each':skipped_min['symbols'],
            'header_bits':header,'aux_bits':aux,'net_balance_bits':forward+back-aux,
            'min_pixel':int(work.min()),'max_pixel':int(work.max())}
    # Conservative partial accounting: even omitting the entire grouping map,
    # the mandatory boundary map is still charged. Report separately.
    result['boundary_only_balance_bits']=forward+back-boundary['bits']-header
    return (work.T if orientation=='vertical' else work),result


def mhm_features(image, parity):
    """Fig.5 stencil, Eq.(16) FLOOR predictor and 15-term noise level."""
    h,w=image.shape
    r,c=np.mgrid[1:h-2,1:w-2];mask=(r+c)%2==parity;r=r[mask];c=c[mask]
    at=lambda dr,dc:image[r+dr,c+dc].astype(np.int32)
    omega={1:at(-1,0),2:at(0,-1),3:at(1,0),4:at(0,1),5:at(1,-1),
           6:at(1,1),7:at(2,0),8:at(0,2),9:at(2,-1),10:at(-1,2),
           11:at(2,1),12:at(1,2),13:at(2,2)}
    prediction=(omega[1]+omega[2]+omega[3]+omega[4])//4
    edges=[(2,5),(5,9),(3,7),(4,6),(6,11),(10,8),(8,12),(12,13),
           (2,4),(5,3),(3,6),(6,12),(9,7),(7,11),(11,13)]
    noise=sum(np.abs(omega[a]-omega[b]) for a,b in edges)
    hist=np.bincount(noise);cumulative=np.cumsum(hist)
    thresholds=np.searchsorted(cumulative,np.ceil(np.arange(1,17)*len(r)/16).astype(int))
    cls=np.searchsorted(thresholds,noise,side='left')
    errors=at(0,0)-prediction
    H=np.zeros((16,511),dtype=np.int64)
    np.add.at(H,(cls,errors+255),1)
    return {'r':r,'c':c,'prediction':prediction,'errors':errors,'classes':cls,
            'thresholds':thresholds,'histogram':H,'noise':noise}


def mhm_options(H,delta):
    states=[(d,b) for d in range(1,delta+1) for b in list(range(d-1,d+6))+[999]]
    capacities=np.zeros((16,len(states)),dtype=np.int64)
    for j,(d,b) in enumerate(states):
        centers=list(range(-d+1,d-1))
        if b!=999:centers += [-b-1,b]
        capacities[:,j]=H[:,np.array(centers,dtype=int)+255].sum(axis=1)
    return states,capacities


def mhm_optimize(H,delta):
    """Exact maximum slot count within Eq.(10),(12) for fixed histograms.

    Uses DP rather than enumerating all state sequences. This optimizes
    capacity, NOT the paper's distortion-per-payload objective Eq.(9).
    """
    states,cap=mhm_options(H,delta);count=len(states)
    prev=cap[0].copy();prev[[s[0]!=delta for s in states]]=-10**12
    pointers=np.zeros((16,count),dtype=int)
    for k in range(1,16):
        cur=np.empty(count,dtype=np.int64)
        for j,(d,b) in enumerate(states):
            allowed=np.array([i for i,(pd,pb) in enumerate(states) if pd>=d and pb<=b])
            p=allowed[np.argmax(prev[allowed])];cur[j]=prev[p]+cap[k,j];pointers[k,j]=p
        prev=cur
    pos=int(np.argmax(prev));best=int(prev[pos]);indices=[pos]
    for k in range(15,0,-1):pos=int(pointers[k,pos]);indices.append(pos)
    indices=indices[::-1]
    return best,np.array([states[i] for i in indices]),int(cap.max(axis=1).sum())


def mhm_prepare(image,delta,parity):
    work=image.copy().astype(np.int16);h,w=work.shape
    r,c=np.mgrid[1:h-2,1:w-2];mask=(r+c)%2==parity;r=r[mask];c=c[mask]
    values=work[r,c];problem=(values<delta)|(values>=255-delta)
    work[r[values<delta],c[values<delta]]+=delta
    work[r[values>=255-delta],c[values>=255-delta]]-=delta
    lm=arithmetic_map(problem);features=mhm_features(work,parity)
    gross,params,relaxed=mhm_optimize(features['histogram'],delta)
    # Paper lists 10K threshold bits; AES noise can exceed 1023. Widen when needed.
    width=max(10,int(max(features['thresholds'])).bit_length())
    param_bits=3*16+3+16*int(math.ceil(math.log2(delta)))
    aux=param_bits+16*width+18+lm['bits']
    return {'work':work,'features':features,'gross':gross,'params':params,
            'aux':aux,'location_map_bits':lm['bits'],'location_map_ones':lm['ones'],
            'threshold_width':width,'parameter_bits':param_bits,'relaxed':relaxed,
            'delta':delta,'parity':parity}


def mhm_embed(prepared, net_half, data):
    """Forward writes to the stop position, sufficient for the next layer.

    Data stream is random, including the auxiliary replacement placeholders;
    actual auxiliary lengths are subtracted. This is a capacity estimate,
    not a serialized mark/decode codec.
    """
    f=prepared['features'];params=prepared['params'];d=params[f['classes'],0];b=params[f['classes'],1]
    e=f['errors'];magnitude=np.where(e>=0,e,-e-1)
    eligible=(magnitude<d-1)|(magnitude==b)
    needed=net_half+prepared['aux']
    if needed>prepared['gross'] or net_half<0:return None
    spots=np.flatnonzero(eligible)
    stop=int(spots[needed-1])+1 if needed else 0
    shift=np.minimum(magnitude,d-1)+(magnitude>b)
    # Expansion bins use number of inner bins plus embedded bit.
    shift[spots[:needed]]+=data[:needed]
    shift[stop:]=0
    delta_values=np.where(e>=0,shift,-shift)
    work=prepared['work'].copy();work[f['r'],f['c']]+=delta_values.astype(np.int16)
    assert work.min()>=0 and work.max()<=255
    return work
