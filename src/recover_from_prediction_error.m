function [recovered, prediction, report] = recover_from_prediction_error(error_img, reference)
% 独立接收端：只输入有符号误差 E=P-I 和参考比特流。
% 不使用原图、原预测图、编码端变量、文件或全局状态。输出为 double。
    validateattributes(error_img,{'numeric'},{'2d','real','finite','integer','nonempty'});
    if isstruct(reference), reference=reference.bits; end
    [state,report]=prediction_reference_codec('decode',reference,size(error_img));
    if state.mode==1
        assert(all(error_img(:)==0),'prediction_reference:ConstantError', ...
            'A constant image must have zero residuals.');
        prediction=repmat(state.value,size(error_img));
    else
        [state.pos,state.val]=expand_prediction_references(error_img,state);
        state.error=double(error_img); % 仅为调用核心构造的临时状态，不存入辅助信息。
        sr=state.split(1); sc=state.split(2);
        R_zone=min(size(error_img))*0.25;
        prediction=med_4dir_prediction(zeros(size(error_img)),sr,sc, ...
            0,0,0,0,0,state.GlobalPattern,R_zone,state);
    end
    recovered=prediction-double(error_img);
    assert(all(isfinite(recovered(:))) && all(recovered(:)>=0 & recovered(:)<=255) ...
        && all(recovered(:)==round(recovered(:))), ...
        'prediction_reference:InvalidImage','Decoded pixels are outside the 8-bit range.');
end
