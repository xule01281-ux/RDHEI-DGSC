function test_huffman_singleton()
% A one-symbol alphabet must retain its value and use a one-bit code.
for value=[0 1 7 53]
    tree=buildHuffmanTree(repmat(value,1,10));
    assert(strcmp(huffmanEncode(value,tree),'0'));
    assert(strcmp(huffmanEncode(repmat(value,1,4),tree),'0000'));
end
tree=buildHuffmanTree([0 0 0 1 2 2]);
codes=generateCodes(tree,'');
assert(codes.Count==3);
assert(~isempty(huffmanEncode([0 1 2],tree)));
end
