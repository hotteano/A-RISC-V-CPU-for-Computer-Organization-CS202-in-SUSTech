# New CPU

## 项目需求

- GNU RISC-V TOOLCHAIN：建议安装在Ubuntu（或者Linux和MacOS上面）上
- iVerilog：辅助测试
- Vivado：综合与烧写工具
- UARTAssist：串口通信工具

## 项目需要实现的功能

- ALU支持RV32IM指令集
- Control Unit
- Hazard Detection和Hazard Resolution
- 支持五级流水线
- 分支预测（GShare算法、局部预测）
- Trap处理
- 支持中断
- 支持外设（如UART、VGA等）
- MMU和PMP
- 总线&DMA
- IDcache
- 控制和数据内存
- TOP模块

## 架构说明

- CPU Top
- Core
  - ALU
  - CU
  - HU
- MEM
  - IMEM
  - DMEM
- Cache
  - ICache
  - DCache
- BUS
  - BUS Arbiter
  - BUS Decoder
  - BUS Multiplexer
- Peripherals
  - UART
  - VGA
  - KEYBOARD
  - LED
- PIPLINE
  - IF & IF BP
  - ID
  - EX
  - MEM
  - WB
  - REG File
- Branch Prediction
  - GShare
  - Local Predictor
  - Global Predictor
  - Return Address Stack
- Security
  - MMU
  - PMP
  - CSR Registers
- Defines MACROS
