@echo off
echo ========================================
echo    RISC-V CPU Quick Test
echo ========================================

set SRC=src/core/ALU.v src/core/control_unit.v src/core/hazard_unit.v^
    src/pipeline/regfile.v src/pipeline/if_stage.v src/pipeline/if_stage_bp.v^
    src/pipeline/id_stage.v src/pipeline/ex_stage.v src/pipeline/mem_stage.v^
    src/pipeline/wb_stage.v src/memory/inst_bram.v src/memory/data_bram.v^
    src/utils/csr_reg.v src/utils/mmu.v src/utils/pmp.v^
    src/utils/branch_predictor.v src/utils/advanced_branch_predictor.v^
    src/utils/return_address_stack.v src/riscv_cpu_top.v

echo Compiling CPU...
iverilog -o sim/tb_riscv_cpu_simple.vvp -I src %SRC% sim/tb_riscv_cpu_simple.v 2>nul
if %errorlevel% neq 0 (
    echo Compilation FAILED!
    exit /b 1
)

echo Running tests...
vvp sim/tb_riscv_cpu_simple.vvp 2>&1 | findstr /V "^$"

echo.
echo ========================================
echo Test complete!
echo ========================================
pause
