function index = findArrayIndex(currentArray, targetCellArray)
    if isnumeric(currentArray)
        % 转换为数字字符串（示例为数字连接，如[1,2,3] -> "123")
        str = strrep(num2str(currentArray(:)'), ' ', '');
        % 若需转为ASCII字符（如[97,98,99] -> "abc"），改用：str = char(currentArray);
    elseif ischar(currentArray)
        str = currentArray;
    else
        error('Unsupported array type.');
    end
    
    % 在目标cell数组中查找字符串
    matches = strcmp(str, targetCellArray);
    index = find(matches, 1); % 返回第一个匹配的索引
    
    % 若未找到，返回0
    if isempty(index)
        index = 0;
    end
end