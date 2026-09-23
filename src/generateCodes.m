function codes = generateCodes(root, currentCode, codes)
    if isempty(root)
        codes = containers.Map();
        return;
    end
    
    if nargin < 3
        codes = containers.Map();
    end
      if isnan(root.char)
          root.char='';
      end
    if ~isempty(root.char)
      
        q=length(currentCode);
         if q==0, currentCode='0'; end % One-symbol alphabet uses one bit.
         codes(root.char) = currentCode;
        return;
    end
    
    if ~isempty(root.left)
        codes = generateCodes(root.left, [currentCode '0'], codes);
    end
    if ~isempty(root.right)
        codes = generateCodes(root.right, [currentCode '1'], codes);
    end
end