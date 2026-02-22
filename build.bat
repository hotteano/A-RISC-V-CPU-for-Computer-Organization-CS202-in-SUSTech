@echo off
cd /d "%~dp0"
echo Building RISC-V CPU with MMU, CSR, and PMP...
echo.

:: Create sim directory if not exists
if not exist sim mkdir sim

:: Compile all modules
iverilog -g2012 -Isrc -o sim/sim.vvp ^
    src/defines.vh ^
    src/core/ALU.v ^
    src/core/control_unit.v ^
    src/core/hazard_unit.v ^
    src/utils/branch_predictor.v ^
    src/utils/csr_reg.v ^
    src/utils/mmu.v ^
    src/utils/pmp.v ^
    src/pipeline/regfile.v ^
    src/pipeline/if_stage_bp.v ^
    src/pipeline/id_stage.v ^
    src/pipeline/ex_stage.v ^
    src/pipeline/mem_stage.v ^
    src/pipeline/wb_stage.v ^
    src/riscv_cpu_top.v ^
    sim/tb_riscv_cpu.v

if %errorlevel% neq 0 (
    echo Build failed!
    pause
    exit /b 1
)

echo Build success!
echo.
echo Running simulation...
cd sim
vvp sim.vvp
pause
