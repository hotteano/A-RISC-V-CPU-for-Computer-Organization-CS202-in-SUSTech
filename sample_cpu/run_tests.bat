@echo off
REM Windows batch script for running all CPU tests

echo ==========================================
echo    RISC-V CPU Test Suite
echo ==========================================

set IVERILOG=iverilog
set VVP=vvp

REM Create output directory
if not exist sim\out mkdir sim\out

echo.
echo [1/7] Running CSR Register Tests...
%IVERILOG% -o sim\out\tb_csr_reg.vvp -I src src\utils\csr_reg.v sim\tb_csr_reg.v 2>nul
if %errorlevel% neq 0 goto error
%VVP% sim\out\tb_csr_reg.vvp 2>&1 | findstr /C:"STATUS:"
echo.

echo [2/7] Running PMP Tests...
%IVERILOG% -o sim\out\tb_pmp.vvp -I src src\utils\pmp.v sim\tb_pmp.v 2>nul
if %errorlevel% neq 0 goto error
%VVP% sim\out\tb_pmp.vvp 2>&1 | findstr /C:"STATUS:"
echo.

echo [3/7] Running MMU Tests...
%IVERILOG% -o sim\out\tb_mmu.vvp -I src src\utils\mmu.v sim\tb_mmu.v 2>nul
if %errorlevel% neq 0 goto error
%VVP% sim\out\tb_mmu.vvp 2>&1 | findstr /C:"STATUS:"
echo.

echo [4/7] Running Branch Predictor Tests...
%IVERILOG% -o sim\out\tb_branch_predictor.vvp -I src src\utils\advanced_branch_predictor.v sim\tb_branch_predictor.v 2>nul
if %errorlevel% neq 0 goto error
%VVP% sim\out\tb_branch_predictor.vvp 2>&1 | findstr /C:"STATUS:"
echo.

echo [5/7] Running Basic CPU Tests...
%IVERILOG% -o sim\out\tb_riscv_cpu.vvp -I src^
    src\core\ALU.v src\core\control_unit.v src\core\hazard_unit.v^
    src\pipeline\*.v src\memory\*.v^
    src\utils\csr_reg.v src\utils\mmu.v src\utils\pmp.v^
    src\utils\branch_predictor.v src\utils\advanced_branch_predictor.v^
    src\riscv_cpu_top.v sim\tb_riscv_cpu.v 2>nul
if %errorlevel% neq 0 goto error
%VVP% sim\out\tb_riscv_cpu.vvp 2>&1 | findstr /C:"Simulation"
echo.

echo [6/7] Running Comprehensive CPU Tests...
%IVERILOG% -o sim\out\tb_riscv_cpu_full.vvp -I src^
    src\core\ALU.v src\core\control_unit.v src\core\hazard_unit.v^
    src\pipeline\*.v src\memory\*.v^
    src\utils\csr_reg.v src\utils\mmu.v src\utils\pmp.v^
    src\utils\branch_predictor.v src\utils\advanced_branch_predictor.v^
    src\riscv_cpu_top.v sim\tb_riscv_cpu_full.v 2>nul
if %errorlevel% neq 0 goto error
%VVP% sim\out\tb_riscv_cpu_full.vvp 2>&1 | findstr /C:"STATUS:"
echo.

echo [7/7] Running System Tests...
%IVERILOG% -o sim\out\tb_system.vvp -I src^
    src\core\ALU.v src\core\control_unit.v src\core\hazard_unit.v^
    src\pipeline\*.v src\memory\*.v^
    src\utils\csr_reg.v src\utils\mmu.v src\utils\pmp.v^
    src\utils\branch_predictor.v src\utils\advanced_branch_predictor.v^
    src\riscv_cpu_top.v sim\tb_system.v 2>nul
if %errorlevel% neq 0 goto error
%VVP% sim\out\tb_system.vvp 2>&1 | findstr /C:"Test Complete"
echo.

echo ==========================================
echo    All Tests Completed
echo ==========================================
goto end

:error
echo ERROR: Test compilation failed!
exit /b 1

:end
pause
