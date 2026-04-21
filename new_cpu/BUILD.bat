@echo off
REM Build script for RISC-V CPU simulation
REM Requires: iverilog, vvp

echo ========================================
echo Building RISC-V CPU simulation
echo ========================================

set SRC_DIR=src
set SIM_DIR=sim
set OUT_DIR=build

if not exist %OUT_DIR% mkdir %OUT_DIR%

REM Collect all Verilog source files
set SRC_FILES=%SRC_DIR%\defines.vh
set SRC_FILES=%SRC_FILES% %SRC_DIR%\cpu.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\cpu_top.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\pipline\IF.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\pipline\ID.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\pipline\EX.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\pipline\MEM.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\pipline\WB.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\pipline\regfile.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\core\ALU.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\core\CU.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\core\HC.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\cache\I_Cache.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\cache\D_Cache.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\memory\I_BRam.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\memory\D_BRam.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\bus\Arbiter.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\bus\Decoder.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\bus\Mux.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\bus\DMA.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\peripherals\UART.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\peripherals\VGA.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\peripherals\PS2.v
set SRC_FILES=%SRC_FILES% %SRC_DIR%\peripherals\LED.v

echo Compiling...
iverilog -g2012 -o %OUT_DIR%\cpu_sim.vvp %SRC_FILES% %SIM_DIR%\tb_cpu.v

if errorlevel 1 (
    echo Build failed!
    exit /b 1
) else (
    echo Build successful: %OUT_DIR%\cpu_sim.vvp
)
