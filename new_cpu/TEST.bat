@echo off
REM Test script for RISC-V CPU simulation

echo ========================================
echo Running RISC-V CPU simulation
echo ========================================

set OUT_DIR=build

if not exist %OUT_DIR%\cpu_sim.vvp (
    echo Simulation file not found. Running build first...
    call BUILD.bat
)

echo Starting simulation...
vvp %OUT_DIR%\cpu_sim.vvp

echo ========================================
echo Simulation complete
echo View waveforms: gtkwave cpu.vcd
echo ========================================
