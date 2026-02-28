# RISC-V CPU 五段流水线处理器 (CS202) - 南科大

一个完整的5段流水线RISC-V CPU Verilog实现，目标板为EGO1 FPGA开发板（Xilinx Artix-7 XC7A35TCSG324-1）。

---

## 目录

- [架构概览](#架构概览)
- [CPU规格](#cpu规格)
- [流水线阶段](#流水线阶段)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [测试结果](#测试结果)
- [指令集](#指令集)

---

## 架构概览

```
    ┌─────────────────────────────────────────────────────────────────────────┐
    │                        RISC-V 5段流水线架构                              │
    ├─────────────────────────────────────────────────────────────────────────┤
    │                                                                         │
    │   ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐     │
    │   │ IF  │───→│ ID  │───→│ EX  │───→│ MEM │───→│ WB  │───→│ Reg │     │
    │   │取指 │    │译码 │    │执行 │    │访存 │    │写回 │    │文件 │     │
    │   └──┬──┘    └──┬──┘    └──┬──┘    └──┬──┘    └──┬──┘    └──┬──┘     │
    │      │          │          │          │          │          │         │
    │   ┌──┴──┐    ┌──┴──┐    ┌──┴──┐    ┌──┴──┐    ┌──┴──┐              │
    │   │IF/ID│    │ID/EX│    │EX/MEM│   │MEM/WB│                           │
    │   │流水寄存器│   │流水寄存器│   │流水寄存器│   │流水寄存器│                           │
    │   └─────┘    └─────┘    └──────┘   └──────┘                           │
    │                                                                         │
    │   ◄──────────────── 数据前递路径 (旁路) ───────────────────►            │
    │                                                                         │
    └─────────────────────────────────────────────────────────────────────────┘
```

---

## CPU规格

| 参数 | 值 |
|-----------|-------|
| **指令集** | RV32I + RV32M (基础整数 + 乘除法扩展) |
| **流水线段数** | 5 (IF, ID, EX, MEM, WB) |
| **时钟频率** | 50 MHz (EGO1开发板) |
| **指令存储器** | 16KB BRAM (4K x 32-bit) |
| **数据存储器** | 16KB BRAM (4K x 32-bit) |
| **寄存器文件** | 32 x 32-bit (x0 恒为0) |
| **分支预测器** | Tournament预测器 (Local + Gshare) + BTB + RAS |
| **特权模式** | M-mode, S-mode, U-mode |
| **CSR支持** | 完整M-mode CSR支持 |
| **MMU** | Sv32 页式虚拟内存 |
| **PMP** | 4区域物理内存保护 |
| **I-Cache** | 1KB直接映射，64组，16B行大小，只读 |
| **D-Cache** | 1KB直接映射，64组，16B行大小，写回策略，字节写 |
| **总线架构** | 类Wishbone总线 + 仲裁器 |
| **DMA** | 4通道DMA控制器 |
| **字节序** | 小端序 |

---

## 流水线阶段

### 1. 取指阶段 (IF)

**功能：**
- 程序计数器 (PC) 管理
- 顺序取指 (PC+4) 或跳转目标
- 指令存储器访问（组合逻辑读取）

**关键信号：**
- `pc_stall`: 来自冒险控制单元的停顿信号
- `pc_src`: 跳转目标选择
- `pc_target`: 跳转目标地址

---

### 2. 译码阶段 (ID)

**功能：**
- 指令译码 (opcode, funct3, funct7)
- 寄存器文件读取 (2个读端口)
- 立即数生成
- 控制信号生成

**关键控制信号：**
| 信号 | 描述 |
|--------|-------------|
| `alu_op` | ALU操作选择 |
| `alu_src_a` | ALU A输入: 0=rs1, 1=PC |
| `alu_src_b` | ALU B输入: 0=rs2, 1=imm |
| `mem_read` | 数据存储器读使能 |
| `mem_write` | 数据存储器写使能 |
| `reg_write` | 寄存器写使能 |
| `mem_to_reg` | 写回源: 0=ALU, 1=Mem |
| `branch` | 分支指令 |
| `jump` | 跳转指令 |

---

### 3. 执行阶段 (EX)

**功能：**
- ALU运算（算术、逻辑、移位、比较）
- 分支/跳转目标地址计算
- 分支条件判断
- 来自MEM/WB阶段的数据前递

**数据前递：**
- 从EX/MEM前递 (Forward A/B = 2'b10)
- 从MEM/WB前递 (Forward A/B = 2'b01)

---

### 4. 访存阶段 (MEM)

**功能：**
- 数据存储器访问
- 加载/存储操作
- 分支预测更新
- 内存映射I/O接口

---

### 5. 写回阶段 (WB)

**功能：**
- 寄存器文件写回
- 数据源选择 (ALU结果/存储器数据/PC+4)
- 解决Load-Use数据冒险

---

## 项目结构

```
.
├── src/
│   ├── core/               # 核心模块
│   │   ├── ALU.v          # 算术逻辑单元 (RV32I + RV32M)
│   │   ├── control_unit.v # 控制单元
│   │   └── hazard_unit.v  # 冒险检测与前递单元
│   ├── pipeline/          # 流水线阶段
│   │   ├── if_stage.v     # 取指阶段 (基础版)
│   │   ├── if_stage_bp.v  # 取指阶段 (带分支预测)
│   │   ├── id_stage.v     # 译码阶段
│   │   ├── ex_stage.v     # 执行阶段
│   │   ├── mem_stage.v    # 访存阶段
│   │   ├── wb_stage.v     # 写回阶段
│   │   └── regfile.v      # 寄存器文件
│   ├── memory/            # 存储器模块
│   │   ├── inst_bram.v    # 指令BRAM
│   │   └── data_bram.v    # 数据BRAM
│   ├── utils/             # 实用模块
│   │   ├── csr_reg.v      # CSR寄存器
│   │   ├── mmu.v          # 内存管理单元
│   │   ├── pmp.v          # 物理内存保护
│   │   ├── branch_predictor.v      # 分支预测器
│   │   ├── advanced_branch_predictor.v  # 高级分支预测
│   │   └── return_address_stack.v   # 返回地址栈
│   ├── bus/               # 总线接口
│   └── peripherals/       # 外设控制器
├── sim/                   # 仿真测试
│   ├── tb_riscv_cpu_simple.v  # CPU集成测试
│   ├── tb_csr_reg.v       # CSR模块测试
│   ├── tb_pmp.v           # PMP模块测试
│   └── tb_*.v             # 其他测试
├── constraints/           # FPGA约束文件
└── software/              # 测试程序
```

---

## 快速开始

### 环境要求

- **仿真**: Icarus Verilog (iverilog) + GTKWave
- **综合**: Xilinx Vivado 2020.2+
- **开发板**: EGO1 (Xilinx Artix-7)

### 运行仿真测试

```bash
# 编译并运行CPU集成测试
make test

# 运行单个测试
iverilog -o sim/tb_riscv_cpu_simple.vvp -I src src/*.v src/**/*.v sim/tb_riscv_cpu_simple.v
vvp sim/tb_riscv_cpu_simple.vvp

# 查看波形
gtkwave sim/tb_riscv_cpu_simple.vcd
```

### FPGA上板

```bash
# 使用Vivado打开项目
vivado -mode batch -source scripts/create_project.tcl

# 生成bitstream文件
make bitstream

# 下载到开发板
make program
```

---

## 测试结果

### 集成测试

| 测试文件 | 描述 | 状态 |
|----------|------|------|
| tb_riscv_cpu_simple.v | CPU集成测试 (ADD, MUL, BEQ, Load-Use) | ✅ 4/4 通过 |
| tb_riscv_cpu_system.v | 系统级集成测试 (11个ALU/转发测试) | ✅ 11/11 通过 |
| tb_add_mul_branch.v | ALU + RV32M + 分支单元测试 | ✅ 3/3 通过 |
| tb_csr_reg.v | CSR模块测试 | ✅ 22/22 通过 |
| tb_pmp.v | PMP模块测试 | ✅ 33/33 通过 |
| tb_icache.v | 指令缓存测试 | ✅ 4/4 通过 |
| tb_dcache.v | 数据缓存测试 | ✅ 4/4 通过 |

**总体状态: 78/78 测试通过 ✅**

### 模块测试

| 模块 | 测试数 | 通过 | 状态 |
|------|--------|------|------|
| CSR寄存器 | 22 | 22 | ✅ 通过 |
| PMP | 33 | 33 | ✅ 通过 |
| I-Cache | 4 | 4 | ✅ 通过 |
| D-Cache | 4 | 4 | ✅ 通过 |
| 系统集成 | 11 | 11 | ✅ 通过 |

---

## 指令集

### RV32I (基础整数指令集)

**算术/逻辑指令:**
- `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`
- `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI`
- `LUI`, `AUIPC`

**分支/跳转指令:**
- `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`
- `JAL`, `JALR`

**加载/存储指令:**
- `LB`, `LH`, `LW`, `LBU`, `LHU`
- `SB`, `SH`, `SW`

**其他:**
- `FENCE`, `ECALL`, `EBREAK`, `CSRRW`, `CSRRS`, `CSRRC`, `CSRRWI`, `CSRRSI`, `CSRRCI`

### RV32M (乘除法扩展)

- `MUL`, `MULH`, `MULHSU`, `MULHU`
- `DIV`, `DIVU`, `REM`, `REMU`

---

## 关键特性

### 1. 数据前递 (Forwarding)

解决EX和MEM阶段的数据冒险，避免不必要的停顿：
```verilog
// EX阶段前递逻辑
assign alu_a_src = (forward_a_sel == 2'b10) ? forward_mem_data :
                   (forward_a_sel == 2'b01) ? forward_wb_data :
                   rs1_data;
```

### 2. Load-Use 冒险处理

当Load指令后紧跟使用其结果的指令时，插入一个气泡：
```verilog
// Load-Use检测
if (id_ex_mem_read && (id_ex_rd != 5'd0) && 
    ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))) begin
    pc_stall    = 1'b1;  // 停顿PC
    if_id_stall = 1'b1;  // 停顿IF/ID
    id_ex_flush = 1'b1;  // 冲刷ID/EX (插入气泡)
end
```

### 3. 分支预测

使用Tournament预测器组合本地历史和全局历史模式，提高预测准确率。

---

## 调试记录

### 已修复的问题

1. **BEQ分支目标计算错误** ✅
   - 原因: ALU没有处理ALU_BEQ等分支操作码，返回0
   - 修复: 在ALU.v中添加分支指令处理 (result = a + b)

2. **control_unit缺少ALU源选择** ✅
   - 原因: BRANCH/JAL/JALR指令没有设置alu_src_a/alu_src_b
   - 修复: 在control_unit.v中添加相应设置

3. **Load-Use前递信号错误** ✅
   - 原因: ID阶段使用了基于ID/EX阶段的前递信号
   - 修复: 在hazard_unit中分离ID和EX阶段的前递信号

---

## 许可证

MIT License - 详见 LICENSE 文件

---

## 作者

南方科技大学 计算机组成原理课程设计 (CS202)

---

*最后更新: 2026-02-23*


---

## ���ղ���״̬

### ����֤����

| �����׼� | ������ | ͨ�� | ״̬ |
|----------|--------|------|------|
| CPU���ɲ��� (tb_riscv_cpu_simple) | 4 | 4 | ? ȫ��ͨ�� |
| ALU+RV32M+��֧ (tb_add_mul_branch) | 3 | 3 | ? ȫ��ͨ�� |
| CSRģ�� (tb_csr_reg) | 22 | 22 | ? ȫ��ͨ�� |
| PMPģ�� (tb_pmp) | 33 | 33 | ? ȫ��ͨ�� |

**�ܼ�: 62/62 ����ͨ��**

### ����֤����

- ? RV32I��������ָ�� (ADD, SUB, AND, OR, XOR, SLT, SLL, SRL��)
- ? RV32M�˳�����չ (MUL, DIV, REM)
- ? ��ָ֧�� (BEQ������֧Ԥ��)
- ? Load-Useð�ռ���봦��
- ? ����ǰ�� (EX-to-EX, MEM-to-EX)
- ? CSR�Ĵ�������
- ? �����ڴ汣�� (PMP)

### ���в���

`ash
# ���벢����CPU���ɲ���
iverilog -o sim/tb_riscv_cpu_simple.vvp -I src src/core/*.v src/pipeline/*.v src/memory/*.v src/utils/*.v src/riscv_cpu_top.v sim/tb_riscv_cpu_simple.v
vvp sim/tb_riscv_cpu_simple.vvp

# ��ʹ���������ļ�
test_cpu.bat
`

---

*������֤: 2026-02-23*
*״̬: CPU���Ĺ�������֤ ?*

