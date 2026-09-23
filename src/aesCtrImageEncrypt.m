function [encryptedImageMatlab, originalImageProperties] = aesCtrImageEncrypt(imagePath, key, iv)
% encryptImageAES_CTR: 使用AES-CTR模式加密图像。
%
% 输入:
%   imagePath: 待加密图像的路径。
%   key: 加密密钥 (Java byte[] 或 MATLAB uint8[]，长度为16, 24或32字节)。
%   iv: 初始向量 (Java byte[] 或 MATLAB uint8[]，长度为16字节)。
%
% 输出:
%   encryptedImageMatlab: 加密后的图像数据 (MATLAB uint8[]，形状与原始图像相同)。
%   originalImageProperties: 包含原始图像尺寸和通道数的结构体。

% --- 图像数据准备 ---
img =uint8(imagePath);

if ~isa(img, 'uint8')
    if max(img(:)) <= 255 && min(img(:)) >= 0
        img = uint8(round(img));
        % fprintf('加密函数：图像数据已从 %s 转换为 uint8 类型。\n', class(img));
    else
        error('加密函数：图像数据类型不是 uint8，且值不在0-255范围内，无法处理。');
    end
end

[rows, cols, channels] = size(img);
originalImageBytes = img(:); % 将图像展平为字节数组

% 存储原始图像属性，用于解密时恢复形状
originalImageProperties.rows = rows;
originalImageProperties.cols = cols;
originalImageProperties.channels = channels;
originalImageProperties.originalImage = img; % 也可以存储原始图像用于比较

% 将MATLAB的key和iv转换为Java byte[] (如果它们已经是Java byte[]则无需转换)
if ~isa(key, 'java.io.Serializable') % 检查是否为Java对象
    keyBytesJava = typecast(key, 'int8');
else
    keyBytesJava = key;
end

if ~isa(iv, 'java.io.Serializable')
    ivBytesJava = typecast(iv, 'int8');
else
    ivBytesJava = iv;
end


% --- AES-CTR 加密 ---
try
    % 创建 SecretKeySpec
    keySpec = javax.crypto.spec.SecretKeySpec(keyBytesJava, 'AES');
    
    % 创建 IvParameterSpec (用于CTR模式)
    ivSpec = javax.crypto.spec.IvParameterSpec(ivBytesJava);
    
    % 获取 Cipher 实例，指定算法和模式
    cipher = javax.crypto.Cipher.getInstance('AES/CTR/NoPadding');
    
    % 初始化为加密模式
    cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, keySpec, ivSpec);
    
    % 执行加密
    encryptedBytesJava = cipher.doFinal(originalImageBytes); % Java byte[]
    % fprintf('加密函数：图像加密成功。\n');
    
catch ME
    disp(['加密函数：加密失败：' ME.message]);
    encryptedImageMatlab = [];
    originalImageProperties = [];
    return;
end

% 将Java的byte[]转换为MATLAB的uint8[]以便后续显示或存储
encryptedImageMatlab = typecast(encryptedBytesJava, 'uint8');

end