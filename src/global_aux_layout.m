function layout = global_aux_layout(bit_count,H,W,h)
% 全局辅助位按 H,H-h,... 行，从右向左覆盖；末字节用零填充。
% 旧写入器在整字节且未到行尾时还保存一个未覆盖的前瞻字节。
% 保持这个既有布局，接收端无需外传 AI_sum_num。
assert(bit_count>0 && bit_count==fix(bit_count) && mod(H,h)==0 && ...
    ceil(bit_count/8)<=H/h*W,'global_aux_layout:Size','Invalid global section size.');
covered=ceil(bit_count/8);
saved=min(floor(bit_count/8)+1,ceil(covered/W)*W);
layout=struct('global_bits',bit_count,'covered_bytes',covered, ...
    'displaced_bits',8*saved,'last_row',H-floor((covered-1)/W)*h, ...
    'last_col',W-mod(covered-1,W));
end
