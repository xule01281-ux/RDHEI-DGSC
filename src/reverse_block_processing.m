function recovered_blocked1 = reverse_block_processing(N, w, h, block_data)
    % N: 模式标号 (1, 2, 3, 4)
    % w, h: 块的宽和高
    % block_data: 一维列向量，包含该块的压缩数据

    % 1. 还原 select3 的二维矩阵结构 (h * w)
    % 编码时使用的 asa1=reshape(select3.',[],h*w); 是按行展平的
    % 解码时先 reshape 成 w*h，再转置即可完美复原 h*w 的 select3
    select3 =block_data;
    
    % 初始化我们要恢复的 3D 块 (h * w * 8位平面)
    recovered_blocked1 = zeros(h, w, 8);
    n_h = floor(h / 8);
    
    % 2. 根据不同的 N (分块模式) 进行逆向还原
    switch N
        case 1  %% 第一种 1*8
            for n = 1:8
                sum_num = 0;
                for z = 1:h
                    for q = 1:8:w
                        % 完全复刻编码时的索引逻辑
                        if q == 1
                            sum_num = sum_num + 1;
                        end
                        if sum_num == 9
                            sum_num = 1;
                        end
                        wn = floor(q / 8);
                        hn = ceil(z / 8);
                        
                        % 取出十进制数值
                        val = select3((n-1)*n_h + hn, sum_num + wn*8);
                        % 转换为8位二进制数组 (例如 11 -> [0 0 0 0 1 0 1 1])
                        bits = dec2bin(val, 8) - '0';
                        
                        % 填入原始位置
                        for Q = 0:7
                            recovered_blocked1(z, q+Q, n) = bits(Q+1);
                        end
                    end
                end
            end
            
        case 2  %% 第二种 2*4
            for n = 1:8
                sum_num = 0; 
                sum_num_h = 1;
                for z = 1:2:h
                    for R = 0:(w/4)-1
                        % 索引逻辑
                        sum_num = sum_num + 1;
                        if sum_num == w + 1
                            sum_num = 1;
                            sum_num_h = sum_num_h + 1;
                            if sum_num_h == n_h + 1
                                sum_num_h = 1;    
                            end
                        end
                        
                        val = select3((n-1)*n_h + sum_num_h, sum_num);
                        bits = dec2bin(val, 8) - '0';
                        
                        bit_idx = 1;
                        for Z = 0:1
                            for q = 1:4
                                recovered_blocked1(z+Z, q+R*4, n) = bits(bit_idx);
                                bit_idx = bit_idx + 1;
                            end
                        end
                    end
                end
            end
            
        case 3  %% 第三种 4*2
            for n = 1:8
                sum_num = 0; 
                sum_num_h = 1;
                for z = 1:4:h
                    for R = 0:(w/2)-1
                        % 索引逻辑
                        sum_num = sum_num + 1;
                        if sum_num == w + 1
                            sum_num = 1;
                            sum_num_h = sum_num_h + 1;
                            if sum_num_h == n_h + 1
                                sum_num_h = 1;    
                            end
                        end
                        
                        val = select3((n-1)*n_h + sum_num_h, sum_num);
                        bits = dec2bin(val, 8) - '0';
                        
                        bit_idx = 1;
                        for Z = 0:3
                            for q = 1:2
                                recovered_blocked1(z+Z, q+R*2, n) = bits(bit_idx);
                                bit_idx = bit_idx + 1;
                            end
                        end
                    end
                end
            end
            
        case 4  %% 第四种 8*1
            for n = 1:8
                sum_num = 0; 
                sum_num_h = 1;
                for z = 1:8:h
                    for R = 0:w-1
                        % 索引逻辑
                        sum_num = sum_num + 1;
                        if sum_num == w + 1
                            sum_num = 1;
                            sum_num_h = sum_num_h + 1;
                            if sum_num_h == n_h + 1
                                sum_num_h = 1;    
                            end
                        end
                        
                        val = select3((n-1)*n_h + sum_num_h, sum_num);
                        bits = dec2bin(val, 8) - '0';
                        
                        bit_idx = 1;
                        for Z = 0:7
                            for q = 1:1
                                recovered_blocked1(z+Z, q+R*1, n) = bits(bit_idx);
                                bit_idx = bit_idx + 1;
                            end
                        end
                    end
                end
            end
    end
end