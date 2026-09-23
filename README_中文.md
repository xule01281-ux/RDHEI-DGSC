# RDHEI-DGSC 完整主链路复现包

本包包含预测、分段rANS编解码、辅助信息压缩、AES-CTR加密、嵌入、提取、置乱及原图恢复的完整源码。无需另外下载闭源编码模块。原工程未改动；本包中的改动记录见 `docs/changes.md`。

## 1 运行

环境：Windows、MATLAB R2023a、Image Processing Toolbox、Statistics and Machine Learning Toolbox；保留MATLAB的Java支持。

将当前目录切换到解压后的 `RDHEI-DGSC`，执行：

```matlab
rdhei_setup
main
```

默认合成图可直接运行完整流程，输出在 `results/generated/synthetic`。更换图像：

```matlab
main(fullfile('data','11.png'))
```

输入为8位灰度图，宽高应为分块尺寸的整数倍。默认16×16、entropy选向、取消极值干预、SCEC阈值0.40/0.10。

## 2 实验入口

| 入口 | 用途 |
|---|---|
| `test_full_release` | 边界、辅助码表、短载荷、合成图及固定码流向量验证 |
| `test_full_release('图像目录')` | 加测Man、Jetplane、Baboon、Tiffany完整恢复及真实容量 |
| `run_capacity_suite('图像目录')` | 8/16/32/64分块容量；算到真实净容量即停止 |
| `run_scec_ablation('图像目录')` | 七组SCEC净ECC消融，固定DGP分区并重新选向 |
| `run_dgp_comparison('图像目录')` | 当前SCEC条件下的DGP、几何中心、峰值和行列定位对照 |
| `benchmark_forward('图像目录',3)` | 后四图预热后重复计时，范围为预测开始到置乱结束 |
| `run_damage_suite` | 受损实验，默认144次攻击及4次无损对照 |
| `run_dataset_ecc_part`、`merge_dataset_ecc` | 两数据集前后5000分批、续跑、极值和编号统计及合并 |

常规四图文件名为 `11.png`、`Jetplane.tiff`、`Baboon.tiff`、`Tiffany.tiff`。Man即11.png。图像不随包分发，具体文件哈希在 `results/reference/input_manifest.json`。

## 3 结果口径

净ECC使用实际秘密载荷位数除以原图像素数，已计入块头、rANS状态、全局辅助、预测参考、折叠位置图、不可编码块排列和回填开销。图外53字节公共头单独报告。内核打印的旧估计值不作为最终容量，请读取结果结构或JSON。

`forward_seconds`从调用预测函数前开始，到最终置乱完成结束，不包含提取和恢复。`roundtrip_seconds`是整次调用时间，两者不能混用。性能实验应在空闲机器上串行运行。

保留发送端真值数组用于逐元素、逐块及最终结果校验。本包提供完整流程复现实验，没有额外声称已改造独立接收端接口。

## 4 上传

可将本目录整体上传仓库，保留源码、说明、测试及参考结果。运行时生成的秘密密钥不应上传；包内固定密钥只存在于明确标识的合成测试向量中。

本包已含rANS源码，替代此前“先公开预测器、录用后再公开编码”的计划。上传完成后在论文中填写真实仓库链接和版本号，才表述为“代码已公开”。


## Paper experiment archive / 论文实验档案

See [docs/paper_experiments.md](docs/paper_experiments.md) for the manuscript table index, exact protocols, preserved raw records and portable commands. The main-chain code is unchanged from v1.0.0. Reference records are separate from newly generated results.
