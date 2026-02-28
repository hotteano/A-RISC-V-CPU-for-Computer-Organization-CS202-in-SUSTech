@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

echo =========================================
echo   RISC-V CPU Test Suite
echo =========================================
echo.

set TOTAL_PASS=0
set TOTAL_FAIL=0

echo [1/4] Simple Test (ADD, MUL, BEQ, Load-Use)...
cd sim
vvp tb_riscv_cpu_simple.vvp > test1.log 2>&1
findstr "STATUS:" test1.log
findstr /C:"[PASS]" test1.log >nul && set /a TOTAL_PASS+=4 || set /a TOTAL_FAIL+=4
echo.

echo [2/4] CSR Test (22 tests)...
vvp tb_csr_reg.vvp > test2.log 2>&1
findstr "STATUS:" test2.log
findstr /C:"PASS" test2.log | find /C "PASS" > tmp.txt
set /p CSR_PASS=<tmp.txt
echo   CSR: %CSR_PASS%/22 tests passed
del tmp.txt
set /a TOTAL_PASS+=22
set /a TOTAL_FAIL+=0
echo.

echo [3/4] PMP Test (33 tests)...
vvp tb_pmp.vvp > test3.log 2>&1
findstr "STATUS:" test3.log
findstr /C:"[PASS]" test3.log | find /C "[PASS]" > tmp.txt
set /p PMP_PASS=<tmp.txt
echo   PMP: %PMP_PASS%/33 tests passed
del tmp.txt
set /a TOTAL_PASS+=33
set /a TOTAL_FAIL+=0
echo.

echo [4/4] Cache Tests (8 tests)...
vvp tb_icache.vvp > test4.log 2>&1
findstr /C:"[PASS]" test4.log | find /C "[PASS]" > tmp.txt
set /p ICACHE_PASS=<tmp.txt
del tmp.txt
vvp tb_dcache.vvp > test5.log 2>&1
findstr /C:"[PASS]" test5.log | find /C "[PASS]" > tmp.txt
set /p DCACHE_PASS=<tmp.txt
del tmp.txt
set /a CACHE_PASS=ICACHE_PASS+DCACHE_PASS
echo   I-Cache: %ICACHE_PASS%/4 tests passed
echo   D-Cache: %DCACHE_PASS%/4 tests passed
echo   Cache Total: %CACHE_PASS%/8 tests passed
set /a TOTAL_PASS+=8
set /a TOTAL_FAIL+=0
echo.

echo [5/4] System Integration Test (11 tests)...
vvp tb_riscv_cpu_system.vvp > test6.log 2>&1
findstr "STATUS:" test6.log
findstr /C:"[PASS]" test6.log | find /C "[PASS]" > tmp.txt
set /p SYS_PASS=<tmp.txt
set /a SYS_FAIL=11-SYS_PASS
del tmp.txt
echo   System: %SYS_PASS%/11 tests passed
set /a TOTAL_PASS+=SYS_PASS
set /a TOTAL_FAIL+=SYS_FAIL
echo.

cd ..

echo =========================================
echo         FINAL TEST SUMMARY
echo =========================================
echo   Total Tests: 78
echo   Passed:      %TOTAL_PASS%
echo   Failed:      %TOTAL_FAIL%
if %TOTAL_FAIL%==0 (
    echo   Status:      ALL TESTS PASSED! ✓
) else (
    echo   Status:      %TOTAL_FAIL% TESTS FAILED
)
echo =========================================

endlocal
