function out=packet_bit_layout(I)
% Parse public length fields only. No secret key or sender truth is required.
% Bit identifiers index column-major pixels, then MSB-first bits per pixel.
[H,W]=size(I); g=read_global_support(I,false); h=g.h;w=g.w;
[opt,width,used]=read_opt_headers(double(I),g.reference,g.ecc==0,h,w);
allidx=reshape(1:H*W,H,W);
globpix=reshape(allidx(H:-h:1,W:-1:1).',1,[]);
glob=reshape(8*(globpix-1)+(1:8).',1,[]);
prot=glob(g.protected_frequency);
refstart=g.reference_start+used;
prot=[prot,glob(refstart:g.layout.global_bits)];
global_covered=glob(1:8*ceil(g.layout.global_bits/8));
slots=cell(size(opt)); private=cell(size(opt)); lengths=zeros(size(opt));
for a=1:H/h
 for b=1:W/w
  if g.ecc(a,b),continue;end
  pix=reshape(allidx((a-1)*h+(1:h),(b-1)*w+(1:w)).',1,[]);
  ids=reshape(8*(pix-1)+(1:8).',1,[]);
  v=double(I(pix)); bits=reshape(rem(floor(v(:)./2.^(7:-1:0)),2).',1,[]);
  cursor=width(a,b)+1; priv=cursor:cursor+1;cursor=cursor+2;
  flag=take(1);
  if flag,large=take(1);take(log2(w)+large*g.max_l);end
  ns=symbol(g.tables{1});
  if ns==1
   n=number(6);take(1);priv=[priv,cursor:cursor+n-1];take(n);
  elseif ns>1
   tail=number(6);base=symbol(g.tables{2});
   for k=1:ns-1,symbol(g.tables{3});end
   flags=take(ns-1);take(ns);n=tail+sum(flags*base+(1-flags)*53);
   priv=[priv,cursor:cursor+n-1];take(n);
  end
  lengths(a,b)=cursor-1;assert(cursor-1<=opt(a,b)*8);
  private{a,b}=ids(priv);
  slot=ids(cursor:8*opt(a,b));
  % Same physical global-overlap rule as the production writer.
  byte=floor((slot-1)/8)+1;x=mod(byte-1,H)+1;y=floor((byte-1)/H)+1;
  keep=x<g.layout.last_row | mod(x-g.layout.last_row,h)~=0 | ...
      (x==g.layout.last_row & y<g.layout.last_col);
  slots{a,b}=slot(keep);
 end
end
slots=reshape(slots.',1,[]);slots=[slots{:}];
private=reshape(private.',1,[]);private=[private{:}];
private=private(~ismember(private,global_covered));
assert(numel(slots)>=g.layout.displaced_bits);
prot=[prot,private,slots(1:g.layout.displaced_bits)];
assert(numel(unique(prot))==numel(prot),'Duplicate protected bit.');
out=struct('protected',prot,'slots',slots,'payload',slots(g.layout.displaced_bits+1:end), ...
 'reference',slots(1:g.layout.displaced_bits),'header_lengths',lengths, ...
 'global',g,'payload_bits',numel(slots)-g.layout.displaced_bits);
 function v=take(n)
  assert(n>=0 && cursor+n-1<=numel(bits),'Truncated block.');
  v=bits(cursor:cursor+n-1);cursor=cursor+n;
 end
 function v=number(n),v=take(n)*2.^(n-1:-1:0).';end
 function v=symbol(t)
  for len=1:t.max_length
   assert(cursor+len-1<=numel(bits)); code=char(bits(cursor:cursor+len-1)+'0');
   k=find(strcmp(code,t.codes),1);
   if ~isempty(k),v=t.values(k);cursor=cursor+len;return;end
  end
  error('packet:Code','Invalid Huffman code.');
 end
end
