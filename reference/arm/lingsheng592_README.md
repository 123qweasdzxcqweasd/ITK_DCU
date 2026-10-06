# 灵昇服务器：592 核混合精度测试

本目录是 **灵昇 HPC 上的最终测试入口**。编译当前 ITK、只跑已合格函数，都必须在灵昇上完成。登录节点只用来提交作业、看队列；计时结果以计算节点 592 核作业为准。

592 核实测用的改源码 ITK 5.4.0 在分支 [`lingsheng-itk-5.4-592`](https://github.com/yyq0210/ITK_ECNU/tree/lingsheng-itk-5.4-592)（`InsightToolkit-5.4.0/`，不是官方未改树）。

不要用鲲鹏脚本当本分支的验收流程。不要在登录节点跑 `run_qualified.sh`。

## 合格标准

只重测同时满足下面两条的函数（名单 `qualified_functions.tsv`，**304** 个）：

- 可判定的 `max_abs < 1e-5`（流水线里只打到 4 位小数的 `0.0000` 不算）
- `speedup = double_ms / float_ms > 1`

当前库打开 float 像素累加开关。Bilateral 复测误差约 4e-4～5e-4，不在名单里。`Mean(radius=15)`、`BoxMean(radius=15)` 仍合格。CAD / GAD 误差合格但 float 不更快，不测。pipeline / diffusion / bilateral 套件里没有同时满足两条的用例，脚本不会启动它们。

补测进名单的 3 个：`HoughTransform2DLinesImageFilter`（64×64 合成线）、`ImageRegistrationMethodv4`、`MultiResolutionImageRegistrationMethod`。细化、MRF、RGBGibbs 能跑但 float 不快。`CurvatureRegistrationFilter` 需要 FFTW。

另 4 个已在作业 1803853（cn23174，592 核）按官方用法补测：`BSplineSyNImageRegistrationMethod` 与 `TimeVaryingBSplineVelocityFieldImageRegistrationMethod` 同时满足误差和速度，已进名单；`VectorNeighborhoodOperatorImageFilter` 误差为 0 但 float 不快；`UnaryFrequencyDomainFilter` float 更快但复数 `max_abs` 约 7.7e-3，大于 1e-5。`CurvatureRegistrationFilter` 仍需要 FFTW。

全表 584 行见 `mixed_precision_lingsheng592.csv`：471 已测，1 失败（FFTW），112 未测（基类 / GPU / FFTW / FEM）。

## 灵昇环境

| 项 | 值 |
| --- | --- |
| 代码 | `/home/share/nsls_yyq/yyq/ITK_ECNU` |
| 本目录 | `/home/share/nsls_yyq/yyq/ITK_ECNU/lingsheng592` |
| 调度 | Donau：`dsub` / `djob` / `dqueue` / `dkill`（不是 Slurm） |
| 队列 | `q_hpcapp`，申请 `cpu=592` |
| CMake | **只用** `/usr/bin/cmake`（3.22）。不要用 `/usr/local/bin/cmake` |
| 链接 | gold：`$YYQ/ld-gold`，`-fno-use-linker-plugin` |
| 线程 | `ITK_DEFAULT_MAX_THREADS=592`，绑核避开每 NUMA 最后一个管家核 |
| 排除节点 | `cn22976`（NFS 错误）、`cn23018`（dattach 超时） |

计算核列表（592 = 16×37）：`0-36,38-74,76-112,114-150,152-188,190-226,228-264,266-302,304-340,342-378,380-416,418-454,456-492,494-530,532-568,570-606`。

不要对 `/opt` 或 `/home/share` 做全盘 `find`。不要把 SSH 密码写进仓库。不要堆作业。长时间任务用批处理 `dsub`（不要 `dsub -I`：CLI 一断交互作业就死）。

## 测试数据集

默认图：`$ROOT/test/data/BrainProtonDensity1024.png`（ITK 官方脑质子密度切片拉到 1024²）。

配准套件若单独跑，用同目录的 `BrainProtonDensity1024_fixed.png` / `_moving.png`。合格名单里的 v4 / MultiResolution 补测把 1024 主图当输入。Hough / 细化走 `precision_fail_retry_bench` 里的 64×64 合成图，不要用 1024 脑图。网格、路径、MRF、Gibbs 等由程序按 ITK 单测协议现场造数。

缺 1024 图时在仓库根目录执行：`python3 test/scripts/prepare_data.py`。

## 在灵昇上怎么跑

仓库克隆到上述代码路径后，切到本分支：

```bash
cd /home/share/nsls_yyq/yyq/ITK_ECNU
git checkout lingsheng-592-qualified
cd lingsheng592
```

确认 `../test/data/BrainProtonDensity1024.png` 存在，确认 `$YYQ/InsightToolkit-5.4.0.tar.gz` 在（现成安装树已是当前库时 `compile_itk.sh` 会直接退出）。

登录节点准备（绑核库、ITK、bench）。ITK 已装好时前两步很快：

```bash
bash build_pinpreload.sh
bash compile_itk.sh
bash compile_benches.sh
```

**提交计算节点测试**（最终计时必须走这一步）：

```bash
bash submit_592.sh
```

四个遗留接口（向量邻域、频率一元滤波、两个 B 样条配准）单独提交，同样必须在计算节点 592 核上跑：

```bash
bash compile_benches.sh
bash submit_four_retry.sh
```

结果在 `lingsheng592/results/four_retry_<时间戳>/four_retry.csv`。

查看作业：

```bash
djob
dqueue
```

日志：`lingsheng592/results/submit.out`、`submit.err`。计时目录：`lingsheng592/results/<时间戳>/`（`logs/`、`node_info.txt`）。不覆盖登录节点、16 核、全量 592、累加开关复测等旧结果。

`run_qualified.sh` 会检查 `nproc --all` ≥ 600，因此只能由 `submit_592.sh` 在计算节点拉起。登录节点不要直接跑它。

## 脚本

| 文件 | 作用 |
| --- | --- |
| `env.sh` | 灵昇路径。改机器时只改这里 |
| `compile_itk.sh` | 当前库已安装则退出；否则 `/usr/bin/cmake` + gold 编译安装 |
| `apply_float_accum.py` | float 累加开关写入源码，`ITK_USE_FLOAT_ACCUMULATION_FOR_FLOAT_PIXELS` 默认 ON |
| `compile_benches.sh` | 过滤套件 bench、拷贝补测源码、动态 libstdc++、编译 |
| `apply_bench_filter.py` | 套件 bench 读 `ITK_BENCH_ONLY_FILE` |
| `build_pinpreload.sh` / `pinpreload.c` | 每线程绑到 592 个计算核之一 |
| `run_qualified.sh` | **计算节点**只跑名单。由 `submit_592.sh` 调用 |
| `submit_592.sh` | `dsub` 提交到 `q_hpcapp`，`cpu=592`，排除坏节点 |
| `run_four_retry.sh` | **计算节点**逐个跑 4 个遗留接口 |
| `submit_four_retry.sh` | 提交上述 4 个补测 |
| `src/precision_fail_retry_bench.cxx` | 细化、Hough、MRF、Gibbs 小图 |
| `src/precision_remainder_instantiable_bench.cxx` | v4 / MultiResolution / SyN 等 |
| `src/precision_four_retry_bench.cxx` | 向量邻域、频率滤波、B 样条配准（官方 adaptor） |
| `qualified_functions.tsv` | 304 个合格函数 |
| `mixed_precision_lingsheng592.csv` | 584 行灵昇复测表 |
| `interface_status_584.md` | 584 个接口的合格 / 能做不合格 / 不能做说明 |

列表类 bench 接受单个算子名。套件类 bench 先写 `ITK_BENCH_ONLY_FILE` 再启动。

各程序数量：`fill_missing` 197，`remain` 49，`levelset` 14，`metric` 13，`extra35` 10，`path_mesh` 8，`cat3` 5，`conv` 3，`fail_retry` 1，`remainder_instantiable` 2，`four_retry` 2。
