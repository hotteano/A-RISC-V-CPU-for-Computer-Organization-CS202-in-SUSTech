# A RISC-V CPU for CS202 (SUSTech) — 项目文档

本仓库包含一个面向《计算机组成原理（CS202）》课程的 RISC-V CPU 实现与扩展 SoC 设计。整体上分为两个实现：

- **sample_cpu**：课程项目版的 5 段流水线 RISC-V CPU，面向 EGO1 FPGA 开发板。
- **new_cpu**：带缓存/总线/外设/特权级的 RV32IM SoC 设计，目标是支持更完整的系统运行。

下文对项目结构、功能、架构和构建方式进行统一整理，方便快速理解与使用。

---

## 目录结构

```text
.
├── sample_cpu/                # 课程项目版 CPU (5 段流水线)
│   ├── src/                   # Verilog 源码
│   ├── sim/                   # 仿真测试平台
│   ├── software/              # 测试程序
│   ├── constraints/           # FPGA 约束文件
│   └── Makefile / *.bat       # 构建与测试脚本
│
├── new_cpu/                   # 扩展 SoC 设计 (RV32IM + Privileged)
│   ├── src/                   # Verilog 源码
│   ├── sim/                   # 仿真测试平台
│   ├── software/              # 测试程序
│   ├── constraint/            # FPGA 约束文件
│   └── BUILD.bat / TEST.bat   # 构建与测试脚本
│
├── build.sbt                  # Scala 工程配置（如需）
└── LICENSE
```

---

## 环境依赖

通用依赖：

- **Icarus Verilog (iverilog, vvp)**：仿真编译/运行
- **GTKWave**：波形查看（可选）
- **RISC-V GNU Toolchain**：编译软件测试程序（riscv32-unknown-elf-*）

FPGA 相关（如上板）：

- **Xilinx Vivado 2020.2+**
- 开发板：**EGO1 (Artix-7 XC7A35TCSG324-1)**

---

## sample_cpu：课程项目版 5 段流水线 CPU

### 目标与特性

- **指令集**：RV32I + RV32M
- **流水线**：5 段（IF/ID/EX/MEM/WB）
- **寄存器文件**：32 x 32-bit
- **缓存**：I-Cache + D-Cache（1KB 直接映射）
- **分支预测**：Tournament（Local + Gshare）+ BTB + RAS
- **特权支持**：M/S/U 模式，CSR
- **MMU**：Sv32
- **PMP**：物理内存保护（4 区域）
- **总线/IO**：类 Wishbone 总线，UART/VGA/PS2/LED/DMA 等

### 关键模块分层

```
src/
├── core/            # ALU / Control / Hazard / Trap / DMA / IO
├── pipeline/        # IF/ID/EX/MEM/WB + RegFile
├── memory/          # 指令/数据 BRAM
├── cache/           # I-Cache / D-Cache
├── utils/           # CSR / MMU / PMP / Branch Predictor
├── bus/             # 总线仲裁/译码/复用
└── peripherals/     # UART / VGA / PS2 / LED
```

### 地址映射（sample_cpu）

| 地址范围 | 大小 | 设备 |
|---------|------|------|
| 0x0000_0000 - 0x0000_3FFF | 16KB | 指令 BRAM |
| 0x0000_4000 - 0x0000_7FFF | 16KB | 数据 BRAM |
| 0x1000_0000 - 0x1000_0FFF | 4KB | UART |
| 0x1000_1000 - 0x1000_1FFF | 4KB | GPIO/LED |
| 0x1000_2000 - 0x1000_2FFF | 4KB | Timer |
| 0x1000_3000 - 0x1000_3FFF | 4KB | VGA |
| 0x1000_4000 - 0x1000_4FFF | 4KB | PS/2 |
| 0x1000_5000 - 0x1000_5FFF | 4KB | DMA |
| 0x0200_0000 - 0x0200_BFFF | 48KB | CLINT |

### 构建与仿真

Linux/WSL：

```bash
cd sample_cpu
make          # 编译并运行仿真
make clean    # 清理产物
```

Windows：

```bat
cd sample_cpu
build.bat     # 编译
run_tests.bat # 运行测试集合
test_cpu.bat  # CPU 集成测试
```

---

## new_cpu：扩展 SoC (RV32IM + Privileged)

### 目标与特性

- 计划支持运行 **Linux RV32**
- **RV32I + RV32M + Zicsr + Privileged（部分）**
- 5 段流水线 + 分支预测（GShare / 局部预测 / RAS）
- **I/D Cache、DMA、UART/VGA/PS2/LED 外设**
- **MMU (Sv32) + PMP**
- CLINT / PLIC 中断体系

### SoC 顶层结构（概念）

```
soc_top
├── riscv_cpu_top (5 段流水线)
│   ├── I-Cache / D-Cache
│   └── IF/ID/EX/MEM/WB
├── I_BRam / D_BRam
├── Bus (Arbiter / Decoder / Mux / DMA)
├── Peripherals (UART / VGA / PS2 / LED)
└── Boot (Bootloader / SBI / DTB)
```

### 主要模块清单（节选）

- `soc_top.v`：SoC 顶层
- `cpu.v`：CPU 顶层
- `pipline/IF.v`、`ID.v`、`EX.v`、`MEM.v`、`WB.v`
- `core/ALU.v`、`CU.v`、`HC.v`
- `cache/I_Cache.v`、`cache/D_Cache.v`
- `bus/Arbiter.v`、`Decoder.v`、`Mux.v`、`DMA.v`
- `peripherals/UART.v`、`VGA.v`、`PS2.v`、`LED.v`
- `utils/CSR/*`、`utils/MMU/*`、`utils/Interrupt/*`
- `utils/BOOT/*`、`utils/Atomic/*`

### 地址映射（new_cpu）

| 地址范围 | 大小 | 设备 |
|---------|------|------|
| 0x0000_0000 - 0x0000_3FFF | 16KB | I-BRAM |
| 0x0000_0000 - 0x0000_3FFF | 16KB | D-BRAM |
| 0x0200_0000 - 0x0200_FFFF | 64KB | CLINT |
| 0x0C00_0000 - 0x0FFF_FFFF | 64MB | PLIC |
| 0x1000_0000 - 0x1000_0FFF | 4KB | UART |
| 0x1000_1000 - 0x1000_1FFF | 4KB | LED |
| 0x1000_3000 - 0x1000_3FFF | 4KB | VGA |
| 0x1000_4000 - 0x1000_4FFF | 4KB | PS/2 |
| 0x1000_5000 - 0x1000_5FFF | 4KB | DMA |

### 构建与仿真（Windows 脚本）

```bat
cd new_cpu
BUILD.bat     # 编译仿真
TEST.bat      # 运行仿真
```

---

## 软件与测试

- `sample_cpu/software` 与 `new_cpu/software` 中包含汇编/C 测试程序与链接脚本。
- `sim/` 目录提供多个 testbench（CPU 集成测试、CSR/MMU/PMP/Cache 测试等）。

---

## 开发与扩展建议

1. **新增指令**：同步更新控制单元（CU）、ALU、冒险处理（Hazard Unit）与测试用例。
2. **修改流水线**：注意 IF/ID/EX/MEM/WB 级间寄存器接口，必要时更新前递与停顿逻辑。
3. **新增外设**：添加外设模块并更新总线 Decoder/Mux 地址映射。
4. **上板时序**：目标频率 50MHz，调整约束文件与时序优化。

---

## 参考与更多细节

- `sample_cpu/README_CN.md`：更完整的 CPU 规格、测试结果与调试记录
- `new_cpu/README.md`：新 SoC 架构概览
- `new_cpu/architecture.md`：结构图（Mermaid）
- `new_cpu/instructions.md`：需求与模块清单

