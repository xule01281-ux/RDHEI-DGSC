function [LSIb, SIb, s_LSIb, ns_b, l_d_best_b, l_0_l_b, ecc, inforamtion_numn] = block_in_support(opt,p0,r,h,w,row1,col1,b0,ns,l_0,l_d,l_d_best,max_l,p1,l0,p0_f,xts,select_blocked,mode_flags)
    if nargin < 19
        mode_flags = [];
    end
    
    %% 1. ????? Huffman ?????
    n = ceil(log2(h*w/8+1));
    n_block = ceil(log2(h*w)); % ?? opt_bin
    
    % ????????? Huffman ????
    function map = getHuffmanMap(unique_vals, tree)
        map = containers.Map('KeyType', 'double', 'ValueType', 'any');
        for k = 1:length(unique_vals)
            [enc] = huffmanEncode(unique_vals(k), tree);
            map(unique_vals(k)) = double(enc - '0');
        end
    end

    % ??? ns, l_d_best, l_0 ??? (????????)
    ns_unique = unique(ns(:));
    ns_map = getHuffmanMap(ns_unique, buildHuffmanTree(ns(:)'));
    
    ld_unique = unique(l_d_best(:));
    ld_map = getHuffmanMap(ld_unique, buildHuffmanTree(l_d_best(:)'));
    
    l0_all = horzcat(l_0{:});
    % No multi-segment blocks: emit an unused one-symbol length table.
    if isempty(l0_all), l0_all=0; end
    l0_unique = unique(l0_all);
    l0_map = getHuffmanMap(l0_unique, buildHuffmanTree(l0_all));

    %% 2. ?????????? (ns_b, l_d_best_b, l_0_l_b)
    % ????????????????????????
    function out_bin = fast_header_gen(vals, tree, map, n_val)
        u_vals = unique(vals);
        max_v = max(u_vals);
        n11 = max(1,floor(log2(max(1,max_v)))+1);
        b1 = []; b2 = []; b4 = [];
        for v = u_vals
            enc = map(v);
            b1 = [b1, enc];
            b2 = [b2, bitget(length(enc), n_val:-1:1)];
            b4 = [b4, bitget(v, n11:-1:1)];
        end
        out_bin = [bitget(length(u_vals), n_val:-1:1), b2, bitget(n11, n_val:-1:1), b1, b4];
    end

    ns_b = fast_header_gen(ns(:)', [], ns_map, n);
    l_d_best_b = fast_header_gen(l_d_best(:)', [], ld_map, n);
    l_0_l_b = fast_header_gen(l0_all, [], l0_map, n);

    %% 3. ?????
    LSIb = zeros(row1, col1);
    SIb = cell(row1, col1);
    ecc = zeros(row1, col1);
    
    % ?????
    ecc0_bin_cell = cell(1, row1 * col1);
    ecc_idx = 0;
    
    inforamtion_numn = 0;
    s_LSIb = 0;
    opt_sum = sum(opt(:));

    % ??????
    b0_const_len = log2(w) + max_l + 2;

    for i = 1:row1
        for j = 1:col1
            if opt(i,j) == 0
                ecc(i,j) = 1;
                continue;
            end
            
            % --- 1. opt_bin & r_bin (??? bitget) ---
            opt_bin = bitget(opt(i,j)-1, n_block:-1:1);
            r_bin = bitget(r(i,j)-1, 2:-1:1);
            
            % --- 2. b0_bin ?? ---
            idx = (i-1)*col1 + j;
            b0_bin = b0{idx};
            if b0_bin(1) == 1 && b0_bin(2) == 1
                if b0_const_len ~= length(b0_bin)
                    next_l = length(b0_bin) - b0_const_len;
                    b0_bin = [b0_bin(1:2), b0_bin(2+next_l+1:end)];
                end
            end

            % --- 3. xf ?? (Huffman ??) ---
            ns_val = ns(i,j);
            ns_encoded = ns_map(ns_val);
            xts_n = xts{idx};

            if ns_val == 0
                xf = ns_encoded;
            else
                if ns_val == 1
                    xt_val = xts_n{1};
                    lxf = ceil(log2(xt_val + 1));
                     mode_bits = zeros(1,max(0,round(ns_val)));
                    if ~isempty(mode_flags) && numel(mode_flags) >= idx && ...
                            ~isempty(mode_flags{idx})
                        mf = double(mode_flags{idx}(:).');
                        mode_bits(1:min(numel(mode_bits),numel(mf))) = ...
                            mf(1:min(numel(mode_bits),numel(mf)));
                    end
                    xf = [ns_encoded, bitget(lxf, 6:-1:1), mode_bits,bitget(xt_val, lxf:-1:1)];
                else
                    % ????
                    lxf_end = ceil(log2(1 + xts_n{ns_val}));
                    xt_end_bin = bitget(xts_n{ns_val}, lxf_end:-1:1);
                    
                    l_d_n = l_d{idx};
                    l_d_best_n = l_d_best(i,j);
                    
                    % ??????????
                    xt_e = [];
                    l_d_f = double(l_d_n <= l_d_best_n);
                    % The current encoder may switch between the base
                    % frequency table and the m3 table independently for
                    % each segment.  Preserve the original width flags for
                    % decoding xt, and append the table-mode bits as a
                    % separate self-describing field.
                    mode_bits = zeros(1,max(0,round(ns_val)));
                    if ~isempty(mode_flags) && numel(mode_flags) >= idx && ...
                            ~isempty(mode_flags{idx})
                        mf = double(mode_flags{idx}(:).');
                        mode_bits(1:min(numel(mode_bits),numel(mf))) = ...
                            mf(1:min(numel(mode_bits),numel(mf)));
                    end
                    for l_i = 1:ns_val-1
                        lxf_i = ifthen(l_d_f(l_i), l_d_best_n, 53);
                        xt_e = [xt_e, bitget(xts_n{l_i}, lxf_i:-1:1)];
                    end
                    
                    ld_best_enc = ld_map(l_d_best_n);
                    l0_n = l_0{idx};
                    % l_0 ????????????????
                    l0_enc = [];
                    for val = l0_n(:)', l0_enc = [l0_enc, l0_map(val)]; end
                    
                    xf = [ns_encoded, bitget(lxf_end, 6:-1:1), ld_best_enc, ...
                        l0_enc, double(l_d_f), mode_bits, xt_end_bin, xt_e];
                end
            end

            % --- 4. ??????? ---
            combined_str = [opt_bin, r_bin, b0_bin, xf];
            
            if opt(i,j)*8 < length(combined_str)
                ecc(i,j) = 1;
                opt_sum = opt_sum - opt(i,j);
            else
                inforamtion_numn=inforamtion_numn+length(combined_str);
            end
            SIb{i,j} = combined_str;
            LSIb(i,j) = length(combined_str);
            s_LSIb = s_LSIb + opt(i,j)*8 - length(combined_str);
            % ??????????????? length(combined_str) == opt(i,j)*8
            % s_LSIb ?????????????????????
           
        end
    end

    %% 4. ????
    fprintf('???????: %.3f\n',s_LSIb/512/512);
end

% ????????????
function val = ifthen(cond, a, b)
    if cond, val = a; else, val = b; end
end
