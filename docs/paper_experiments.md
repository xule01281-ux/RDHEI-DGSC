# 论文实验复现索引

对应手稿：中文_预测公式同步与医学场景修订稿，2026年9月20日。
本档案版本为1.1.0，全部 `src/` 主链路文件与1.0.0逐字节相同。本次补充实验入口、公开参数和已有结果，没有更改预测或编码算法。

## 1 图表与材料对应

| 论文位置 | 可运行入口 | 论文原始记录 | 设置及计量 |
|---|---|---|---|
| 表2 辅助字段分析 | `docs/bitstream.md`及主链路字段解析 | `results/paper/verification/leakage_audit.json` | 区分受保护字段与公开结构 |
| 表3 检测实验 | `paper_table3`；`detection/analyze_detection.py` | `results/paper/table3/` | 200幅预跑＋1000幅正式源图；正式700训练／300测试；固定源图划分、302维统计＋格式解析标志 |
| 表4 图像差异与恢复 | `paper_table4` | `results/paper/table4/` | 四图各5次；每次独立密钥／IV；20次完整提取和恢复 |
| 表5 块尺寸 | `paper_table5` | `results/paper/table5/` | 四图×8、16、32、64；只计算真实净容量 |
| 表7及细分消融回复 | `paper_table7` | `results/paper/table7/` | 七组×四图；固定DGP分区、重新选向；正文显示其中四组 |
| 表8 定位对照 | `paper_table8` | `results/paper/table8/` | 11次定位测量／图；有限搜索取其中10个候选的最大实际净容量 |
| 表10 明文RDH直接用于AES密文 | `baselines/`下Python入口；`paper_table10_proposed` | `results/paper/table10/` | 两方法的毛嵌入率与本文净ECC分列；没有运行对比方法的完整恢复 |
| 表11 预测至置乱耗时 | `paper_table11` | `results/paper/table11/` | 每图2次预热＋10次正式运行，逐轮轮换图像顺序；实际输入载荷8,000,000 bit |
| 表12 含密图像受损 | `paper_table12` | `results/paper/table12/` | 144次扰动＋4次对照；保留完整公共头与凭据 |
| 残差与协议边界验证 | 原有 `tests/`、码流说明 | `results/paper/verification/` | 65,536像素／预测值组合、511种残差及MED条件验证记录 |

正文表6、表9及图11—12含原实验配置的数据，不由上述当前配置入口生成。当前BOSSBase与BOWS-2各10,000幅容量尚未全量运行；本包的分批脚本仍需由使用者显式启动。表11其他方法的旧耗时也不是本包的同环境测量。

## 2 目录与输入

- `results/paper/`：论文正式记录，只读使用。
- `results/reference/`：1.0.0发布验证记录，包含较短计时、快速受损测试及另一组DGP启发式对照。
- `results/paper_summary/`：根据正式原始记录重新汇总出的CSV和核验报告。
- `results/generated/`：使用者运行时的新输出，不覆盖论文记录。
- `docs/paper_provenance.json`：历史来源、源文件哈希与移植说明。
- `docs/paper_dependencies.json`：新增MATLAB入口的包内依赖。

Man为`11.png`。另外三图为`Jetplane.tiff`、`Baboon.tiff`、`Tiffany.tiff`，均为512×512、uint8灰度图。原始标准图和完整数据集不随包分发。`paper_inputs`检查解码像素SHA-256，拒绝同名但内容不同的图像；文件重新封装而像素相同不影响检查。

MATLAB环境沿用主README。Python统计与对照代码需要Python 3.10或更新版本、NumPy和Pillow；具体整理环境见`docs/paper_environment.json`。新增入口不依赖作者机器的绝对路径。下列命令中的图像目录由使用者填写。

## 3 直接从已有结果重建表格

在包根目录执行：

```text
python experiments/paper/summarize_paper.py
```

该命令从原始JSON生成表3、4、5、7、8、10、11、12的CSV，重新训练固定检测器并复算配对自助采样区间，检查源图划分、样本数和容量一致性。它不重新编码图像，不启动大数据集。输出在`results/generated/paper_summary/`。

表4的历史PSNR等指标可由20次原始数值重算均值和标准差。重新执行加密实验会使用新的密钥与IV，因此不要求再次得到完全相同的密文指标。表12的精确受损成功次数及表3特征同样可能随新密文改变；本包保留正式历史记录以支持原表数值复核，不公开自然图像实验的私密凭据。

## 4 MATLAB论文实验入口

先将当前目录设为解压后的根目录：

```matlab
rdhei_setup
image_dir = 'your_standard_image_folder';
paper_table4(image_dir)
paper_table5(image_dir)
paper_table7(image_dir)
paper_table8(image_dir)
paper_table10_proposed(image_dir)
paper_table11(image_dir)
paper_table12(image_dir)
```

这些调用逐项执行，互不自动触发。容量组在真实编码和辅助信息计量完成后停止。表4、表11和表12需要完整流程；表11仅将预测到置乱区间计入所报时间，后续校验不计时。正式计时须单独串行运行。

表8按以下顺序测量：`(1,1)`、`(256,256)`、误差重心，以及`{128,256,384}×{128,256,384}`中除中心外的八点。有限候选最佳从中心、重心和八点共十个测量中选出，不包含`(1,1)`。每个候选重新计算该交点下的分布模式、选向、预测辅助信息和真实容量。该比较不等于只移动交点而冻结其余派生量，也不证明全局最优。

表12沿用原实验的一组固定随机载荷，四图共用；比特翻转和高斯扰动每图每档5次，区域丢失和平移每档1次。解码失败检查不是认证机制。新增入口不保存含秘密密钥的中间MAT夹具。

原有`run_dgp_comparison`和`benchmark_forward`仍可使用，但它们分别是其他定位启发式对照和快速计时验证，不能用其默认结果替换论文表8、表11。

## 5 表3完整源图检测

已保存200＋1000个源图的文件名、哈希、顺序和训练／测试标签：`results/paper/table3/security_manifest.json`。无需再次随机选择源图。将两个数据集的PGM文件分别放在其根目录下，执行：

```matlab
paper_table3('your_BOSS_folder','your_BOWS_folder',[],'pilot',1,2)
paper_table3('your_BOSS_folder','your_BOWS_folder',[],'pilot',2,2)
paper_table3('your_BOSS_folder','your_BOWS_folder',[],'formal',1,2)
paper_table3('your_BOSS_folder','your_BOWS_folder',[],'formal',2,2)
```

各分片支持按源图ID续跑；源图缺失、哈希不符或计算失败时停止报错，避免默默减少样本数。完成后：

```text
python experiments/paper/detection/analyze_detection.py --input results/generated/paper/table3 --output results/generated/paper/table3_analysis
```

正式协议为两分片。训练／测试按源图隔离，同一源图的五种密文变体不能跨集合。特征标准化只使用训练集，岭回归系数固定为10，判定阈值0.5，自助采样500次，种子7819。统计检测限于图像像素，公开载荷长度仍可直接揭示载荷是否存在。

## 6 表10容量对照

`experiments/paper/baselines/inputs/`保留原实验的四幅普通AES密文像素，供固定输入重算；没有原始标准图、密钥或秘密载荷。先提供自己的对应原图并验证：

```text
python experiments/paper/baselines/prepare_inputs.py --images your_standard_image_folder --output results/generated/paper/table10_inputs
```

随后设置两个环境变量（以下为PowerShell）：

```powershell
$env:RDHEI_BASELINE_INPUT='results/generated/paper/table10_inputs'
$env:RDHEI_BASELINE_OUTPUT='results/generated/paper/table10'
python experiments/paper/baselines/run_comparison.py --method idpvo
python experiments/paper/baselines/run_gross_reference.py
```

以上两条是表10对比方法的主入口。I-DPVO执行水平—垂直—水平三轮；HC-MHM搜索δ=1…6；另存载荷种子1、2，主表固定种子0。若需要原实验的辅助开销诊断，再运行`run_comparison.py --method mhm`。诊断中的余额估计不是已验证的净载荷。

Python代码按两篇论文的公式独立实现，不是作者源代码。MHM阈值目标为本实验的最大容量，I-DPVO采用已说明的对称误差分支解释；压缩模型和辅助串放置的限制详见`baselines/measurement_notes.md`。不应将毛容量与本文净ECC的差值表述为同口径净增益。

## 7 本次验证范围

本次由正式原始记录重新汇总八张表，所有核对通过。新入口抽测包括Man的11个DGP候选、计时入口1次预热＋2次运行、1次表4完整流程、2项受损测试、1幅检测源图，以及四图16×16容量和本文表10容量。对比方法的算术码、优化及公式检查通过。

这些抽测仅验证移植后的入口和依赖，不替换正式实验记录。主链路源码未变，未重跑全部正式实验，未启动两个万图数据集，尚未上传公开仓库。
