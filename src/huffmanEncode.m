function [encoded, tree] = huffmanEncode(text,tree)
    if isempty(text)
        encoded = '';
        tree = [];
        return;
    end
    
    %%tree = buildHuffmanTree(text);
    codes = generateCodes(tree, '');
    
    % 处理单字符情况
    if codes.Count == 1
        codes(string(text(1))) = '0';
    end
    
    encoded = cellfun(@(c) codes(c), num2cell(string(text)), 'UniformOutput', false);
    encoded = strjoin(encoded, '');
end
