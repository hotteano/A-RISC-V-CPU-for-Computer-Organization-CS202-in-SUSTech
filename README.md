# CS202 RISC-V 处理器项目文档

本仓库包含面向《计算机组成原理（CS202）》课程的 RISC-V 处理器实现，以及扩展片上系统设计。整体分为两个实现：

- **sample_cpu**：课程项目版的五级流水线 RISC-V 处理器，面向 EGO1 FPGA 开发板。
- **new_cpu**：带缓存、总线、外设、特权级的 RV32IM 片上系统设计，目标支持更完整的系统运行。

下文对项目结构、功能、架构和构建方式进行统一整理，便于快速理解与使用。

---

## 目录结构

```text
.
├── sample_cpu/                # 课程项目版处理器（五级流水线）
│   ├── src/                   # Verilog HDL 源码
│   ├── sim/                   # 仿真测试平台
│   ├── software/              # 测试程序
│   ├── constraints/           # FPGA 约束文件
│   └── Makefile / *.bat       # 构建与测试脚本
│
├── new_cpu/                   # 扩展片上系统（RV32IM + 特权架构）
│   ├── src/                   # Verilog HDL 源码
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

- **Icarus Verilog（iverilog, vvp）**：仿真编译/运行
- **GTKWave**：波形查看（可选）
- **RISC-V GNU 工具链**：编译软件测试程序（riscv32-unknown-elf-*）

FPGA 相关（如上板）：

- **Xilinx Vivado 2020.2+**
- 开发板：**EGO1 (Artix-7 XC7A35TCSG324-1)**

---

## sample_cpu：课程项目版五级流水线处理器

### 目标与特性

- **指令集**：RV32I + RV32M
- **流水线**：5 段（IF/ID/EX/MEM/WB）
- **寄存器文件**：32 x 32-bit
- **缓存**：指令缓存/数据缓存（1KB 直接映射）
- **分支预测**：锦标赛预测器（Local + Gshare）+ BTB + RAS
- **特权支持**：M/S/U 模式，CSR
- **MMU**：Sv32
- **PMP**：物理内存保护（4 区域）
- **总线/外设 IO**：类 Wishbone 总线，UART/VGA/PS2/LED/DMA 等

### 关键模块分层

```
src/
├── core/            # ALU / 控制 / 冒险 / 异常 / DMA / IO
├── pipeline/        # IF/ID/EX/MEM/WB + RegFile
├── memory/          # 指令/数据 BRAM
├── cache/           # I-Cache / D-Cache
├── utils/           # CSR / MMU / PMP / 分支预测
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

Linux/WSL 环境：

```bash
cd sample_cpu
make          # 编译并运行仿真
make clean    # 清理产物
```

Windows 环境：

```bat
cd sample_cpu
build.bat     # 编译
run_tests.bat # 运行测试集合
test_cpu.bat  # CPU 集成测试
```

---

## new_cpu：扩展片上系统（RV32IM + 特权架构）

### 目标与特性

- 计划支持运行 **Linux RV32**
- **RV32I + RV32M + Zicsr + 特权架构（部分）**
- 五级流水线 + 分支预测（GShare / 局部预测 / RAS）
- **指令/数据缓存、DMA、UART/VGA/PS2/LED 外设**
- **MMU（Sv32）+ PMP**
- CLINT / PLIC 中断体系

### 片上系统顶层结构（概念）

```
soc_top
├── riscv_cpu_top（五级流水线）
│   ├── 指令缓存 / 数据缓存
│   └── IF/ID/EX/MEM/WB
├── I_BRam / D_BRam
├── 总线（仲裁 / 译码 / 复用 / DMA）
├── 外设（UART / VGA / PS2 / LED）
└── 启动（Bootloader / SBI / DTB）
```

### 主要模块清单（节选）

- `soc_top.v`：SoC 顶层
- `cpu.v`：CPU 顶层
- `pipline/IF.v`、`ID.v`、`EX.v`、`MEM.v`、`WB.v`（目录名为 `pipline`，与源码保持一致）
- `core/ALU.v`、`CU.v`、`HC.v`
- `cache/I_Cache.v`、`cache/D_Cache.v`
- `bus/Arbiter.v`、`Decoder.v`、`Mux.v`、`DMA.v`
- `peripherals/UART.v`、`VGA.v`、`PS2.v`、`LED.v`
- `utils/CSR/*`、`utils/MMU/*`、`utils/Interrupt/*`
- `utils/BOOT/*`、`utils/Atomic/*`

### 地址映射（new_cpu）

| 地址范围 | 大小 | 设备 |
|---------|------|------|
| 0x0000_0000 - 0x0000_3FFF | 16KB | 指令 BRAM（哈佛结构，指令总线） |
| 0x0000_0000 - 0x0000_3FFF | 16KB | 数据 BRAM（哈佛结构，数据总线） |
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
- `sim/` 目录提供多个测试平台（处理器集成测试、CSR/MMU/PMP/缓存测试等）。

---

## 开发与扩展建议

1. **新增指令**：同步更新控制单元（CU）、ALU、冒险处理单元（Hazard Unit）与测试用例。
2. **修改流水线**：注意 IF/ID/EX/MEM/WB 级间寄存器接口，必要时更新前递与停顿逻辑。
3. **新增外设**：添加外设模块并更新总线译码/复用地址映射。
4. **上板时序**：目标频率 50MHz，调整约束文件与时序优化。

---

## 参考与更多细节

- `sample_cpu/README_CN.md`：更完整的处理器规格、测试结果与调试记录
- `new_cpu/README.md`：新片上系统架构概览
- `new_cpu/architecture.md`：结构图（Mermaid）
- `new_cpu/instructions.md`：需求与模块清单
