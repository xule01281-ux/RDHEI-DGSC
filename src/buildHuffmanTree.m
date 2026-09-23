function root = buildHuffmanTree(text)
    freqDict=tabulate(string(text));
% 创建初始节点数组
    nodes = HuffmanNode.empty;
    keys = freqDict(:,1);
    values  = cell2mat(freqDict(:,2));
    for i = 1:length(keys)
        nodes(end+1) = HuffmanNode(keys{i}, values(i));
    end
    
    % 构建优先队列（通过排序实现）
    while length(nodes) > 1
        % 按频率排序（升序）
        [~, idx] = sort(cellfun(@(x) x.freq, num2cell(nodes)));
        nodes = nodes(idx);
        
        % 取出两个最小节点
        left = nodes(1);
        right = nodes(2);
        
        % 创建合并节点
        merged = HuffmanNode(NaN, left.freq + right.freq);
        merged.left = left;
        merged.right = right;
        
        % 更新队列
        nodes = [nodes(3:end), merged];
    end
    
    root = nodes(1);
    % Preserve the symbol when the tree has a single leaf.
    if ~isempty(root.left) || ~isempty(root.right), root.char=''; end
end