function decryptedImage = aesCtrImageDecrypt(encryptedImageMatlab, rows, cols, channels, key, iv)
% decryptImageAES_CTR: 使用AES-CTR模式解密图像。
%
% 输入:
%   encryptedImageMatlab: 待解密的加密图像数据 (MATLAB uint8[])。
%   rows: 原始图像的行数。
%   cols: 原始图像的列数。
%   channels: 原始图像的通道数。
%   key: 加密密钥 (Java byte[] 或 MATLAB uint8[]，长度为16, 24或32字节)。
%   iv: 初始向量 (Java byte[] 或 MATLAB uint8[]，长度为16字节)。
%
% 输出:
%   decryptedImage: 解密后的图像数据 (MATLAB uint8[])，形状与原始图像相同。

% 将MATLAB的uint8加密数据转换回Java byte[]
encryptedBytesJava = typecast(encryptedImageMatlab, 'int8');

% 将MATLAB的key和iv转换为Java byte[]
if ~isa(key, 'java.io.Serializable')
    keyBytesJava = typecast(key, 'int8');
else
    keyBytesJava = key;
end

if ~isa(iv, 'java.io.Serializable')
    ivBytesJava = typecast(iv, 'int8');
else
    ivBytesJava = iv;
end


% --- AES-CTR 解密 ---
try
    % 创建 SecretKeySpec
    keySpec = javax.crypto.spec.SecretKeySpec(keyBytesJava, 'AES');
    
    % 创建 IvParameterSpec (用于CTR模式)
    ivSpec = javax.crypto.spec.IvParameterSpec(ivBytesJava);
    
    % 获取 Cipher 实例，指定算法和模式
    cipher = javax.crypto.Cipher.getInstance('AES/CTR/NoPadding');
    
    % 初始化为解密模式
    cipher.init(javax.crypto.Cipher.DECRYPT_MODE, keySpec, ivSpec);
    
    % 执行解密
    decryptedBytesJava = cipher.doFinal(encryptedBytesJava); % Java byte[]
    fprintf('解密函数：图像解密成功。\n');
    
catch ME
    disp(['解密函数：解密失败：' ME.message]);
    decryptedImage = [];
    return;
end

% 将Java的byte[]转换为MATLAB的uint8[]并恢复图像形状
decryptedBytesMatlab = typecast(decryptedBytesJava, 'uint8');
decryptedImage = reshape(decryptedBytesMatlab, rows, cols, channels);

end