function [FinalPredImg, FinalErrorImg, BlockInfo, NewErr1, BlockStats] = scec_no_extreme_predictor(OriginalImg, split_row, split_col, ...
                                                             gH_global, gV_global, gD45_global, gD135_global,global_sigma ,GlobalPattern, R_zone, prediction_mode, cfg)
    
    BlockStats=zeros(4,5);
    Img = round(double(OriginalImg));
    [H, W] = size(Img);
    FinalPredImg = zeros(H, W);
    
    PadImg = padarray(Img, [2, 2], 'replicate');
    
    dir_labels = {'TL', 'TR', 'BL', 'BR'};
    
    blocks = cell(4, 2);
    blocks{1, 1} = 1:split_row;      blocks{1, 2} = 1:split_col;
    blocks{2, 1} = 1:split_row;      blocks{2, 2} = (split_col+1):W;
    blocks{3, 1} = (split_row+1):H;  blocks{3, 2} = 1:split_col;
    blocks{4, 1} = (split_row+1):H;  blocks{4, 2} = (split_col+1):W;

    BlockInfo = struct('Dir', {}, 'Mode', {}, 'SSE', {});
    T = 4096;
    for b = 1:4 
        best_cost = inf;
        r_range = blocks{b, 1};
        c_range = blocks{b, 2};
        if isempty(r_range) || isempty(c_range), continue; end
        H_block = numel(r_range);
        W_block = numel(c_range);
        N_block = H_block * W_block;

        TrueBlock = OriginalImg(r_range, c_range);

        if N_block >= T
            [gH_b, gV_b, gD45_b, gD135_b] = calc_global_gradients(TrueBlock);
            sigma_b = std(double(TrueBlock(:)));
        else
            gH_b    = gH_global;
            gV_b    = gV_global;
            gD45_b  = gD45_global;
            gD135_b = gD135_global;
            sigma_b = global_sigma;
        end
        BlockStats(b,:) = [gH_b,gV_b,gD45_b,gD135_b,sigma_b];
        
        
         candidates=1:numel(dir_labels);
         if ~isempty(cfg.forced_dirs), candidates=cfg.forced_dirs(b)+1; end
         for d = candidates
                current_dir = dir_labels{d};
                [TempPred,TempDiag] = predict_core_optimized(PadImg, r_range, c_range, current_dir, gH_b, gV_b, gD45_b, gD135_b,sigma_b,split_row, split_col,GlobalPattern, R_zone,cfg);
                current_sse = sum(sum((TrueBlock - TempPred).^2));
                if strcmp(prediction_mode,'entropy')
                    current_cost = estimate_prediction_bits(TempPred-TrueBlock);
                else
                    current_cost = current_sse;
                end
                if current_cost < best_cost
                    best_cost = current_cost;
                    best_sse  = current_sse;
                    best_dir  = current_dir;
                    best_pred = TempPred; best_diag=TempDiag;
                end
         end
       FinalPredImg(r_range, c_range) = best_pred;
    BlockInfo(b).Dir  = best_dir;
    BlockInfo(b).Mode = 'MED_GRAD'; % 梯度优化的 MED
    BlockInfo(b).SSE  = best_sse;
    BlockInfo(b).SelectionCost = best_cost;
    BlockInfo(b).SelectionMethod = prediction_mode;
    BlockInfo(b).Diagnostics=best_diag;



    end

    FinalErrorImg = (Img - FinalPredImg).^2;
    NewErr1 = Img - FinalPredImg;
end

function [PredBlock,diag] = predict_core_optimized(PadImg, r_idx, c_idx, dir_mode, gH, gV, gD45, gD135,global_sigma,split_row, split_col,GlobalPattern, R_zone, cfg)
    a=1.5;%%梯度把控系数
    b=2;
    H_block = length(r_idx);
    W_block = length(c_idx);
    PredBlock = zeros(H_block, W_block);
    diag=zeros(1,7); % interior feedback weight_floor weight_ceiling bias_clip soft_clip extreme
    total_grad = gH + gV + gD45 + gD135 + 1e-5; 
    w_V = 1+(gV / total_grad)*2;   
    w_H =1+(gH / total_grad)*2 ;   
    w_md =1+(gD45 / total_grad)*2 ;   
    w_sd = 1+(gD135 / total_grad)*2 ;
    switch dir_mode
        case 'TL', loop_r = 1:H_block;     loop_c = 1:W_block;
        case 'TR', loop_r = 1:H_block;     loop_c = W_block:-1:1;
        case 'BL', loop_r = H_block:-1:1;  loop_c = 1:W_block;
        case 'BR', loop_r = H_block:-1:1;  loop_c = W_block:-1:1;
    end
    
    for i = loop_r
        for j = loop_c
            pr = r_idx(i) + 2;
            pc = c_idx(j) + 2;
            


             abs_r = r_idx(i);
            abs_c = c_idx(j);
            
                a = 1.5;
                b = 2.0;

                

            
            switch dir_mode
                case 'TL' % 扫描：左上 -> 右下
                    xh  = PadImg(pr,   pc-1); % Left
                    x1  = PadImg(pr,   pc-2); % Left-Left
                    xv  = PadImg(pr-1, pc);   % Up
                    xmd = PadImg(pr-1, pc-1); % Up-Left
                    x2  = PadImg(pr-1, pc-2); % Up-Left-Left
                    x5  = PadImg(pr-2, pc);   % Up-Up
                    x4  = PadImg(pr-2, pc-1); % Up-Up-Left
                    x3  = PadImg(pr-2, pc-2); % Up-Up-Left-Left
                    
                    
                        xsd = PadImg(pr-1, pc+1);
                        x6  = PadImg(pr-2, pc+1);
                    
                     
                case 'TR' % 扫描：右上 -> 左下 (水平镜像)
                    xh  = PadImg(pr,   pc+1);
                    x1  = PadImg(pr,   pc+2);
                    
                    xv  = PadImg(pr-1, pc);
                    xmd = PadImg(pr-1, pc+1);
                    x2  = PadImg(pr-1, pc+2);
                    
                    x5  = PadImg(pr-2, pc);
                    x4  = PadImg(pr-2, pc+1);
                    x3  = PadImg(pr-2, pc+2);
                    
                    
                    
                    
                        xsd = PadImg(pr-1, pc-1);
                        x6  = PadImg(pr-2, pc-1);
                    
                   s=w_sd;
                     w_sd=w_md;   
                    w_md=s;
                    s=gD45;
                    gD45=gD135;
                    gD135=s;
                case 'BL' % 扫描：左下 -> 右上 (垂直镜像)
                    xh  = PadImg(pr,   pc-1);
                    x1  = PadImg(pr,   pc-2);
                    
                    xv  = PadImg(pr+1, pc);
                    xmd = PadImg(pr+1, pc-1);
                    x2  = PadImg(pr+1, pc-2);
                    
                    x5  = PadImg(pr+2, pc);
                    x4  = PadImg(pr+2, pc-1);
                    x3  = PadImg(pr+2, pc-2);
                    
                    
                    
                   
                        xsd = PadImg(pr+1, pc+1);
                        x6  = PadImg(pr+2, pc+1);
                      s=w_sd;
                     w_sd=w_md;   
                    w_md=s;
                    s=gD45;
                    gD45=gD135;
                    gD135=s;
                   
                case 'BR' % 扫描：右下 -> 左上 (双重镜像)
                    xh  = PadImg(pr,   pc+1);
                    x1  = PadImg(pr,   pc+2);
                    
                    xv  = PadImg(pr+1, pc);
                    xmd = PadImg(pr+1, pc+1);
                    x2  = PadImg(pr+1, pc+2);
                    
                    x5  = PadImg(pr+2, pc);
                    x4  = PadImg(pr+2, pc+1);
                    x3  = PadImg(pr+2, pc+2);
                    
                    
                    
                    
                        xsd = PadImg(pr+1, pc-1);
                        x6  = PadImg(pr+2, pc-1);
                    
             end

                dist_to_center = sqrt((abs_r - split_row)^2 + (abs_c - split_col)^2);
                is_center_zone = (dist_to_center <= R_zone);

                mx = max(xh, xv);
                mn = min(xh, xv);
                edge_span = mx - mn; % 局部跨度(对比度)


            switch dir_mode
                case 'TL'
                     
                case 'TR'
                    
                     s=w_sd;
                     w_sd=w_md;   
                    w_md=s;% 对角权互换
                case 'BL'
                     s=w_sd;
                     w_sd=w_md;   
                    w_md=s;
                    
                case 'BR'
                    
            end
            
            is_row_start = (i == loop_r(1));
            is_col_start = (j == loop_c(1));
            
            val = 0;
            
            if is_row_start && is_col_start
                val = xmd;
            elseif is_row_start
                val = xh;
            elseif is_col_start
                val = xv;
            else
                
                dh = (2*abs(xh - xmd) + 2*abs(xv - x5) + abs(xsd - x6)+abs(xmd - x4)+abs(x1 - x2))/7; % 这里加入 xsd, x6
                dv = (2*abs(xh - x1) + 2*abs(xv - xmd) + abs(xsd - xv)+abs(x2 - xmd)+abs(x4 - x5))/7;
                dmd=(abs(x3 - xmd)+abs(x4 - xv)+abs(x5 - xsd)+abs(x2 - xh))/4;
                dsd=(abs(xmd - x1)+abs(x5 - xmd)+abs(xv- xh)+abs(x2 - x4))/4;
                    grad_clip = 80;  % 可以试 30~80，看哪一档整体 MAE 更好
                    
                    dh   = min(dh,   grad_clip);
                    dv   = min(dv,   grad_clip);
                    dmd  = min(dmd,  grad_clip);
                    dsd  = min(dsd,  grad_clip);
               


                score_v = 1/((max(gV,1e-12))^2*(dh+0.1)^2);
                score_h = 1/((max(gH,1e-12))^2*(dv+0.1)^2);
                score_md = 1/(sqrt(2)*(max(gD45,1e-12))^2*(dmd+0.1)^2);
                score_sd = 1/(sqrt(2)*(max(gD135,1e-12))^2*(dsd+0.1)^2);

                total_score=score_v+score_h+score_md+score_sd;
                wight_v=score_v/total_score;
                wight_h=score_h/total_score;
                wight_md=score_md/total_score;
                wight_sd=score_sd/total_score;
                val= xv*wight_v+ xh*wight_h+xmd*wight_md+xsd*wight_sd;
                 if GlobalPattern==1
                     flage=0;
                 elseif GlobalPattern==2
                     flage=2;
                 else  
                   flage=1;
                 end
                 
                                 diag(1)=diag(1)+1;
                 if cfg.no_spatial, flage=1; end
                 if ~cfg.all_off
if flage==1
                % All experimental groups use the same extreme-free predictor.
                edge_span=max(xh,xv)-min(xh,xv);
                     pred_val=val;
                    slope_h = xh - x1; 
                    slope_v = xv - x5; 
                    bias = wight_h * slope_h + wight_v * slope_v;
                    

                    local_var = dh + dv + dmd + dsd;
                    
                    
                    base_scale = total_grad / (H_block * W_block) + 1e-3; 
                    
                    norm_var = local_var / base_scale; 
                    
                    bias_w = 0.6 * exp(-(norm_var^2) / 2.0);
                    
                    bias_w = max(0.4, min(0.6, bias_w));
                    diag(2)=diag(2)+1;
                    diag(3)=diag(3)+(bias_w==0.4); diag(4)=diag(4)+(bias_w==0.6);
                    if isfinite(cfg.fixed_weight), bias_w=cfg.fixed_weight; end




                    max_bias = max(0.4 * global_sigma, edge_span / 4);   % 用 global_sigma 替代 3
                    if ~cfg.no_bias_clamp
                        diag(5)=diag(5)+(abs(bias)>max_bias);
                        bias = sign(bias) * min(abs(bias), max_bias);
                    end
                    
                    if ~cfg.no_feedback, pred_val = pred_val + bias_w * bias; end
                    

                    local_max = max([xh, xv, xmd, xsd]);
                    local_min = min([xh, xv, xmd, xsd]);
                    
                    soft_margin = max(0.4 * global_sigma, 10);  % 原来的 ±10 改成跟 sigma 挂钩
                    if ~cfg.no_soft_clamp
                        diag(6)=diag(6)+(pred_val<local_min-soft_margin || pred_val>local_max+soft_margin);
                        pred_val = max(local_min-soft_margin,min(local_max+soft_margin,pred_val));
                    end
                val=round(pred_val);
                elseif flage==0
                    if is_center_zone
                        pred_val=val;
                    slope_h = xh - x1; 
                    slope_v = xv - x5; 
                    bias = wight_h * slope_h + wight_v * slope_v;
                    

                        local_var = dh + dv + dmd + dsd;
                        
                        
                        base_scale = total_grad / (H_block * W_block) + 1e-3; 
                        
                        norm_var = local_var / base_scale; 
                        
                        bias_w = 0.6 * exp(-(norm_var^2) / 2.0);
                        
                        bias_w = max(0.4, min(0.6, bias_w));
                    diag(2)=diag(2)+1;
                    diag(3)=diag(3)+(bias_w==0.4); diag(4)=diag(4)+(bias_w==0.6);
                    if isfinite(cfg.fixed_weight), bias_w=cfg.fixed_weight; end




                    max_bias = max(0.4 * global_sigma, edge_span / 4);   % 用 global_sigma 替代 3
                    if ~cfg.no_bias_clamp
                        diag(5)=diag(5)+(abs(bias)>max_bias);
                        bias = sign(bias) * min(abs(bias), max_bias);
                    end
                    
                    if ~cfg.no_feedback, pred_val = pred_val + bias_w * bias; end
                    

                    local_max = max([xh, xv, xmd, xsd]);
                    local_min = min([xh, xv, xmd, xsd]);
                    
                    soft_margin = max(0.4 * global_sigma, 10);  % 原来的 ±10 改成跟 sigma 挂钩
                    if ~cfg.no_soft_clamp
                        diag(6)=diag(6)+(pred_val<local_min-soft_margin || pred_val>local_max+soft_margin);
                        pred_val = max(local_min-soft_margin,min(local_max+soft_margin,pred_val));
                    end
                                        val = round(pred_val);
                    else
                                mx = max(xh, xv);
                                mn = min(xh, xv);
                                edge_span = mx - mn;
                                
                                if edge_span < global_sigma
                                    val=(xh+xv)/2;
                                end
                    end
                else
                    if is_center_zone
                         mx = max(xh, xv);
                                mn = min(xh, xv);
                                edge_span = mx - mn;
                                
                                if edge_span < global_sigma
                                    val=(xh+xv)/2;
                                end
                    else
                        pred_val=val;
                        slope_h = xh - x1; 
                        slope_v = xv - x5; 
                        bias = wight_h * slope_h + wight_v * slope_v;
                        
    
                        local_var = dh + dv + dmd + dsd;
                        
                        
                        base_scale = total_grad / (H_block * W_block) + 1e-3; 
                        
                        norm_var = local_var / base_scale; 
                        
                        bias_w = 0.6 * exp(-(norm_var^2) / 2.0);
                        
                        bias_w = max(0.4, min(0.6, bias_w));
                    diag(2)=diag(2)+1;
                    diag(3)=diag(3)+(bias_w==0.4); diag(4)=diag(4)+(bias_w==0.6);
                    if isfinite(cfg.fixed_weight), bias_w=cfg.fixed_weight; end
    
    
    
    
                        max_bias = max(0.4 * global_sigma, edge_span / 4);   % 用 global_sigma 替代 3
                        if ~cfg.no_bias_clamp
                        diag(5)=diag(5)+(abs(bias)>max_bias);
                        bias = sign(bias) * min(abs(bias), max_bias);
                    end
                        
                        if ~cfg.no_feedback, pred_val = pred_val + bias_w * bias; end
                        
    
                        local_max = max([xh, xv, xmd, xsd]);
                        local_min = min([xh, xv, xmd, xsd]);
                        
                        soft_margin = max(0.4 * global_sigma, 10);  % 原来的 ±10 改成跟 sigma 挂钩
                        if ~cfg.no_soft_clamp
                        diag(6)=diag(6)+(pred_val<local_min-soft_margin || pred_val>local_max+soft_margin);
                        pred_val = max(local_min-soft_margin,min(local_max+soft_margin,pred_val));
                    end
                                            val = round(pred_val);
                    end
                end
                
            end
            
            end % all_off: retain the basic weighted predictor
            PredBlock(i, j) = min(255,max(0,round(val)));
        end
    end
end

