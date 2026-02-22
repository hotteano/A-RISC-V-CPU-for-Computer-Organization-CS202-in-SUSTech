################################################################################
# EGO1 FPGA Board Pin Constraints for RISC-V CPU
# Target: Xilinx Artix-7 XC7A35TCSG324-1
################################################################################

################################################################################
# Clock (100MHz from on-board oscillator)
################################################################################
set_property PACKAGE_PIN P17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]

################################################################################
# Reset (Active Low - BTN0)
################################################################################
set_property PACKAGE_PIN P15 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property PULLUP true [get_ports rst_n]

################################################################################
# LEDs (16 LEDs - LD0 to LD15)
################################################################################
set_property PACKAGE_PIN F6  [get_ports {led_o[0]}]
set_property PACKAGE_PIN G4  [get_ports {led_o[1]}]
set_property PACKAGE_PIN G3  [get_ports {led_o[2]}]
set_property PACKAGE_PIN J4  [get_ports {led_o[3]}]
set_property PACKAGE_PIN H4  [get_ports {led_o[4]}]
set_property PACKAGE_PIN J3  [get_ports {led_o[5]}]
set_property PACKAGE_PIN J2  [get_ports {led_o[6]}]
set_property PACKAGE_PIN K2  [get_ports {led_o[7]}]
set_property PACKAGE_PIN K1  [get_ports {led_o[8]}]
set_property PACKAGE_PIN H6  [get_ports {led_o[9]}]
set_property PACKAGE_PIN H5  [get_ports {led_o[10]}]
set_property PACKAGE_PIN J5  [get_ports {led_o[11]}]
set_property PACKAGE_PIN K6  [get_ports {led_o[12]}]
set_property PACKAGE_PIN L1  [get_ports {led_o[13]}]
set_property PACKAGE_PIN M1  [get_ports {led_o[14]}]
set_property PACKAGE_PIN K3  [get_ports {led_o[15]}]

set_property IOSTANDARD LVCMOS33 [get_ports {led_o[*]}]
set_property DRIVE 12 [get_ports {led_o[*]}]
set_property SLEW SLOW [get_ports {led_o[*]}]

################################################################################
# 7-Segment Display (4 digits - AN0 to AN3, CA to CG, DP)
################################################################################
# Anodes (active low)
set_property PACKAGE_PIN G2  [get_ports {an_o[0]}]
set_property PACKAGE_PIN C2  [get_ports {an_o[1]}]
set_property PACKAGE_PIN C1  [get_ports {an_o[2]}]
set_property PACKAGE_PIN H1  [get_ports {an_o[3]}]

# Cathodes (active low) - segments A to G and DP
set_property PACKAGE_PIN B4  [get_ports {seg_o[0]}]  ;# CA
set_property PACKAGE_PIN A4  [get_ports {seg_o[1]}]  ;# CB
set_property PACKAGE_PIN A3  [get_ports {seg_o[2]}]  ;# CC
set_property PACKAGE_PIN B1  [get_ports {seg_o[3]}]  ;# CD
set_property PACKAGE_PIN A1  [get_ports {seg_o[4]}]  ;# CE
set_property PACKAGE_PIN B3  [get_ports {seg_o[5]}]  ;# CF
set_property PACKAGE_PIN B2  [get_ports {seg_o[6]}]  ;# CG
set_property PACKAGE_PIN D5  [get_ports {seg_o[7]}]  ;# DP

set_property IOSTANDARD LVCMOS33 [get_ports {an_o[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_o[*]}]
set_property DRIVE 12 [get_ports {an_o[*]}]
set_property DRIVE 12 [get_ports {seg_o[*]}]

################################################################################
# DIP Switches (16 switches - SW0 to SW15)
################################################################################
set_property PACKAGE_PIN P5  [get_ports {switch_i[0]}]
set_property PACKAGE_PIN P4  [get_ports {switch_i[1]}]
set_property PACKAGE_PIN P3  [get_ports {switch_i[2]}]
set_property PACKAGE_PIN P2  [get_ports {switch_i[3]}]
set_property PACKAGE_PIN R2  [get_ports {switch_i[4]}]
set_property PACKAGE_PIN M4  [get_ports {switch_i[5]}]
set_property PACKAGE_PIN N4  [get_ports {switch_i[6]}]
set_property PACKAGE_PIN R1  [get_ports {switch_i[7]}]
set_property PACKAGE_PIN U3  [get_ports {switch_i[8]}]
set_property PACKAGE_PIN U2  [get_ports {switch_i[9]}]
set_property PACKAGE_PIN V2  [get_ports {switch_i[10]}]
set_property PACKAGE_PIN V5  [get_ports {switch_i[11]}]
set_property PACKAGE_PIN V4  [get_ports {switch_i[12]}]
set_property PACKAGE_PIN R3  [get_ports {switch_i[13]}]
set_property PACKAGE_PIN T3  [get_ports {switch_i[14]}]
set_property PACKAGE_PIN T5  [get_ports {switch_i[15]}]

set_property IOSTANDARD LVCMOS33 [get_ports {switch_i[*]}]
set_property PULLUP true [get_ports {switch_i[*]}]

################################################################################
# Push Buttons (5 buttons - BTN0 to BTN4)
################################################################################
set_property PACKAGE_PIN P15 [get_ports {btn_i[0]}]  ;# BTN0 (also used as reset)
set_property PACKAGE_PIN P16 [get_ports {btn_i[1]}]  ;# BTN1
set_property PACKAGE_PIN T18 [get_ports {btn_i[2]}]  ;# BTN2
set_property PACKAGE_PIN R18 [get_ports {btn_i[3]}]  ;# BTN3

set_property IOSTANDARD LVCMOS33 [get_ports {btn_i[*]}]
set_property PULLUP true [get_ports {btn_i[*]}]

################################################################################
# UART Interface (USB-UART Bridge)
################################################################################
# UART TX (FPGA -> PC) - Connected to Uart_TXD on schematic
set_property PACKAGE_PIN T16 [get_ports uart_txd_o]
set_property IOSTANDARD LVCMOS33 [get_ports uart_txd_o]
set_property DRIVE 12 [get_ports uart_txd_o]
set_property SLEW SLOW [get_ports uart_txd_o]

# UART RX (PC -> FPGA) - Connected to Uart_RXD on schematic
set_property PACKAGE_PIN U17 [get_ports uart_rxd_i]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd_i]

################################################################################
# PS/2 Keyboard Interface
################################################################################
# PS/2 Clock
set_property PACKAGE_PIN G17 [get_ports ps2_clk_i]
set_property IOSTANDARD LVCMOS33 [get_ports ps2_clk_i]
set_property PULLUP true [get_ports ps2_clk_i]

# PS/2 Data
set_property PACKAGE_PIN H18 [get_ports ps2_data_i]
set_property IOSTANDARD LVCMOS33 [get_ports ps2_data_i]
set_property PULLUP true [get_ports ps2_data_i]

################################################################################
# VGA Interface (12-bit color: 4-bit R, 4-bit G, 4-bit B)
################################################################################
# VGA Horizontal Sync
set_property PACKAGE_PIN D7  [get_ports vga_hs_o]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hs_o]
set_property DRIVE 12 [get_ports vga_hs_o]

# VGA Vertical Sync
set_property PACKAGE_PIN C4  [get_ports vga_vs_o]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vs_o]
set_property DRIVE 12 [get_ports vga_vs_o]

# VGA Red (4 bits)
set_property PACKAGE_PIN F5  [get_ports {vga_r_o[0]}]
set_property PACKAGE_PIN C6  [get_ports {vga_r_o[1]}]
set_property PACKAGE_PIN C5  [get_ports {vga_r_o[2]}]
set_property PACKAGE_PIN B7  [get_ports {vga_r_o[3]}]

# VGA Green (4 bits)
set_property PACKAGE_PIN B6  [get_ports {vga_g_o[0]}]
set_property PACKAGE_PIN A6  [get_ports {vga_g_o[1]}]
set_property PACKAGE_PIN A5  [get_ports {vga_g_o[2]}]
set_property PACKAGE_PIN D8  [get_ports {vga_g_o[3]}]

# VGA Blue (4 bits)
set_property PACKAGE_PIN C7  [get_ports {vga_b_o[0]}]
set_property PACKAGE_PIN E6  [get_ports {vga_b_o[1]}]
set_property PACKAGE_PIN E5  [get_ports {vga_b_o[2]}]
set_property PACKAGE_PIN E7  [get_ports {vga_b_o[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {vga_r_o[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g_o[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b_o[*]}]
set_property DRIVE 12 [get_ports {vga_r_o[*]}]
set_property DRIVE 12 [get_ports {vga_g_o[*]}]
set_property DRIVE 12 [get_ports {vga_b_o[*]}]

################################################################################
# Configuration Settings
################################################################################
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

################################################################################
# False Paths (for unrelated clocks or asynchronous inputs)
################################################################################
# Buttons and switches are asynchronous - add false paths
set_false_path -from [get_ports {btn_i[*]}]
set_false_path -from [get_ports {switch_i[*]}]
set_false_path -from [get_ports rst_n]

################################################################################
# Timing Constraints for IO
################################################################################
# Set input delay for switches and buttons
set_input_delay -clock [get_clocks sys_clk_pin] -min -add_delay 0.000 [get_ports {switch_i[*]}]
set_input_delay -clock [get_clocks sys_clk_pin] -max -add_delay 10.000 [get_ports {switch_i[*]}]
set_input_delay -clock [get_clocks sys_clk_pin] -min -add_delay 0.000 [get_ports {btn_i[*]}]
set_input_delay -clock [get_clocks sys_clk_pin] -max -add_delay 10.000 [get_ports {btn_i[*]}]

# Set output delay for LEDs and 7-segment
set_output_delay -clock [get_clocks sys_clk_pin] -min -add_delay 0.000 [get_ports {led_o[*]}]
set_output_delay -clock [get_clocks sys_clk_pin] -max -add_delay 10.000 [get_ports {led_o[*]}]
set_output_delay -clock [get_clocks sys_clk_pin] -min -add_delay 0.000 [get_ports {an_o[*]}]
set_output_delay -clock [get_clocks sys_clk_pin] -max -add_delay 10.000 [get_ports {an_o[*]}]
set_output_delay -clock [get_clocks sys_clk_pin] -min -add_delay 0.000 [get_ports {seg_o[*]}]
set_output_delay -clock [get_clocks sys_clk_pin] -max -add_delay 10.000 [get_ports {seg_o[*]}]

################################################################################
# Multi-Cycle Paths (for IO operations that take multiple cycles)
################################################################################
# IO operations may take multiple cycles
set_multicycle_path -setup 2 -from [get_cells io_inst/*] -to [get_cells hazard_inst/*]
set_multicycle_path -hold 1 -from [get_cells io_inst/*] -to [get_cells hazard_inst/*]

################################################################################
# Max Fanout Constraints for Control Signals
################################################################################
set_max_fanout 50 [get_nets rst_n]
set_max_fanout 30 [get_nets trap_taken]
set_max_fanout 30 [get_nets mret_taken]
