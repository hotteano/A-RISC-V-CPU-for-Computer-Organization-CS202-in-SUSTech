# new_cpu — RISC-V SoC (RV32IM + Privileged)

预期支持运行 Linux RV32。模块已创建，正在进行集成连线。

---

## 架构总览

```text
                              soc_top (SoC Top Level)
    +-------------------------------------------------------------------------+
    |                                                                         |
    |  +------------------------+                                             |
    |  |   riscv_cpu_top        |                                             |
    |  |   (5-Stage RISC-V CPU) |                                             |
    |  +----------+-------------+                                             |
    |             |                                                           |
    |             | imem_addr / imem_data                                     |
    |    +--------v---------+   +------------------+                          |
    |    |   I_BRam         |   | Bootloader       |                          |
    |    | (16KB Inst BRAM) |<--| (SBI/DTB)        |                          |
    |    +------------------+   +------------------+                          |
    |             |                                                           |
    |             | dmem_addr / dmem_wdata / dmem_rdata                       |
    |             v                                                           |
    |  +------------------------+                                             |
    |  |   Address Decoder      |                                             |
    |  |   & Read Data Mux      |                                             |
    |  +--+--+--+--+--+--+--+--+                                             |
    |    |  |  |  |  |  |  |  |                                              |
    |    v  v  v  v  v  v  v  v                                              |
    |  +----+ +----+ +----+ +----+ +----+ +----+ +----+                       |
    |  |D   | |C   | |P   | |U   | |L   | |V   | |P   |                       |
    |  |BRam| |LINT| |LIC | |ART | |ED  | |GA  | |S2  |                       |
    |  +----+ +----+ +----+ +----+ +----+ +----+ +----+                       |
    |                                    +----+                               |
    |                                    |DMA |                               |
    |                                    +----+                               |
    |                                                                         |
    +----------------------------- External Pins -----------------------------+
           uart_tx/rx   led[7:0]   vga_r/g/b/hs/vs   ps2_clk/data
```

---

## CPU 核心流水线 (5级)

```text
    IF (取指)          ID (译码)         EX (执行)        MEM (访存)       WB (写回)
  +---------------+   +---------------+   +---------------+   +---------------+   +---------------+
  |      IF       |   |      ID       |   |      EX       |   |      MEM      |   |      WB       |
  |   (Fetch)     |-->|   (Decode)    |-->|  (Execute)    |-->|   (Memory)    |-->| (WriteBack)   |
  |  PC/Branch    |   | Reg/Ctrl/Imm  |   |  ALU/Branch   |   | D_BRam / IO   |   | Result->Rd    |
  | Predict + RAS |   |     Gen       |   |   Forward     |   |               |   |               |
  +---------------+   +---------------+   +---------------+   +---------------+   +---------------+
       |                   |                   |                   |                   |
       v                   v                   v                   v                   v
   IF/ID Reg           ID/EX Reg           EX/MEM Reg          MEM/WB Reg
```

---

## 模块清单

| 类别 | 文件路径 | 说明 |
|------|---------|------|
| **顶层** | `soc_top.v` | SoC 顶层，实例化 CPU + 存储 + 外设 |
| **顶层** | `cpu.v` | CPU 顶层 `riscv_cpu_top`，连接5级流水线 |
| **流水线** | `pipline/IF.v` | 取指阶段，含分支预测 + RAS |
| **流水线** | `pipline/ID.v` | 译码阶段，含寄存器堆读、控制信号生成 |
| **流水线** | `pipline/EX.v` | 执行阶段，含 ALU、分支判断 |
| **流水线** | `pipline/MEM.v` | 访存阶段，数据存储器接口 |
| **流水线** | `pipline/WB.v` | 写回阶段，结果写回寄存器堆 |
| **核心** | `core/ALU.v` | 算术逻辑单元 |
| **核心** | `core/CU.v` | 控制单元，指令译码 |
| **核心** | `core/HC.v` | 冒险控制单元 |
| **寄存器** | `pipline/regfile.v` | 32 x 32-bit 寄存器堆 |
| **存储** | `memory/I_BRam.v` | 指令 BRAM (16KB)，双端口 |
| **存储** | `memory/D_BRam.v` | 数据 BRAM (16KB)，双端口 |
| **缓存** | `cache/I_Cache.v` | 指令缓存 |
| **缓存** | `cache/D_Cache.v` | 数据缓存 |
| **外设** | `peripherals/UART.v` | 串口控制器 |
| **外设** | `peripherals/LED.v` | LED 控制器 |
| **外设** | `peripherals/VGA.v` | VGA 控制器 |
| **外设** | `peripherals/PS2.v` | PS/2 键盘控制器 |
| **总线** | `bus/Arbiter.v` | 总线仲裁器 |
| **总线** | `bus/DMA.v` | DMA 控制器 |
| **总线** | `bus/Decoder.v` | 总线地址译码 |
| **总线** | `bus/Mux.v` | 总线多路选择 |
| **分支预测** | `utils/BP/branch_prediction.v` | 分支预测器 |
| **分支预测** | `utils/BP/RAS.v` | 返回地址栈 |
| **CSR** | `utils/CSR/csr_reg.v` | CSR 寄存器文件 |
| **CSR** | `utils/CSR/privilege.v` | 特权级控制 |
| **中断** | `utils/Interrupt/CLINT.v` | 核本地中断器 |
| **中断** | `utils/Interrupt/PLIC.v` | 平台级中断控制器 |
| **中断** | `utils/Interrupt/MRET.v` | MRET 处理 |
| **中断** | `utils/Interrupt/SRET.v` | SRET 处理 |
| **中断** | `utils/Interrupt/WFI.v` | WFI 处理 |
| **中断** | `utils/Interrupt/interrupt_deleg.v` | 中断委托 |
| **MMU** | `utils/MMU/MMU.v` | 内存管理单元 (Sv32) |
| **MMU** | `utils/MMU/PMP.v` | 物理内存保护 |
| **系统调用** | `utils/SystemCall/ECALL.v` | ECALL 处理 |
| **系统调用** | `utils/SystemCall/EBREAK.v` | EBREAK 处理 |
| **系统调用** | `utils/SystemCall/FENCE_I.v` | FENCE.I 处理 |
| **系统调用** | `utils/SystemCall/SFENCE_VMA.v` | SFENCE.VMA 处理 |
| **原子操作** | `utils/Atomic/AMO.v` | 原子内存操作 |
| **原子操作** | `utils/Atomic/Rer_station.v` | 保留站 |
| **启动** | `utils/BOOT/bootloader.v` | Bootloader |
| **启动** | `utils/BOOT/SBI.v` | SBI 固件接口 |
| **启动** | `utils/BOOT/DTB.v` | 设备树Blob |

---

## 地址映射

| 地址范围 | 大小 | 设备 |
|---------|------|------|
| `0x0000_0000` - `0x0000_3FFF` | 16KB | 指令 BRAM (I_Bram) |
| `0x0000_0000` - `0x0000_3FFF` | 16KB | 数据 BRAM (D_Bram) |
| `0x0200_0000` - `0x0200_FFFF` | 64KB | CLINT |
| `0x0C00_0000` - `0x0FFF_FFFF` | 64MB | PLIC |
| `0x1000_0000` - `0x1000_0FFF` | 4KB | UART |
| `0x1000_1000` - `0x1000_1FFF` | 4KB | LED |
| `0x1000_3000` - `0x1000_3FFF` | 4KB | VGA |
| `0x1000_4000` - `0x1000_4FFF` | 4KB | PS/2 |
| `0x1000_5000` - `0x1000_5FFF` | 4KB | DMA |

---

## 支持的指令集

- **RV32I** — 基础整数指令集
- **RV32M** — 乘除法扩展
- **Zicsr** — CSR 指令
- **Privileged** — M/S/U 特权架构 (部分)

---

## 目录结构

```text
new_cpu/
├── src/
│   ├── soc_top.v          # SoC 顶层
│   ├── cpu.v              # CPU 顶层 (5级流水线)
│   ├── defines.vh         # 全局宏定义
│   ├── pipline/           # 流水线阶段
│   ├── core/              # ALU / CU / HC
│   ├── memory/            # I_BRam / D_BRam
│   ├── cache/             # I_Cache / D_Cache
│   ├── bus/               # 总线 (Arbiter / DMA / Decoder / Mux)
│   ├── peripherals/       # 外设 (UART / LED / VGA / PS2)
│   └── utils/             # 高级模块
│       ├── BP/            # 分支预测
│       ├── CSR/           # CSR / 特权级
│       ├── Interrupt/     # 中断处理
│       ├── MMU/           # MMU / PMP
│       ├── SystemCall/    # 系统调用
│       ├── Atomic/        # 原子操作
│       └── BOOT/          # 启动相关
├── constraint/            # FPGA 约束文件
├── software/              # 测试程序
└── sim/                   # 仿真文件
```
