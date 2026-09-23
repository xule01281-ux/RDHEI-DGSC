classdef HuffmanNode < handle
    %%类的的定义
    properties
        char
        freq
        left
        right
    end
    methods
        function obj = HuffmanNode(char, freq)
            obj.char = char;
            obj.freq = freq;
            obj.left = [];
            obj.right = [];
        end
    end
end