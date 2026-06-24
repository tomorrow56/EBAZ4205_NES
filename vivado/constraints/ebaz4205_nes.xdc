################################################################################
# ebaz4205_nes.xdc
# Constraints for EBAZ4205 NES (tarunes port)
################################################################################

#===============================================================================
# System Clock
#===============================================================================
set_property PACKAGE_PIN N18 [get_ports CLK]
set_property IOSTANDARD LVCMOS33 [get_ports CLK]
create_clock -period 30.000 -name sys_clk_pin -waveform {0.000 15.000} [get_ports CLK]

#===============================================================================
# HDMI TMDS Output (Adapter board)
#===============================================================================
# HDMI Clock
set_property PACKAGE_PIN F19 [get_ports HDMI_CLK_P]
set_property IOSTANDARD TMDS_33 [get_ports HDMI_CLK_P]
# set_property PACKAGE_PIN F20 [get_ports HDMI_CLK_N]
# set_property IOSTANDARD TMDS_33 [get_ports HDMI_CLK_N]

# HDMI Data 0 (Blue)
set_property PACKAGE_PIN D19 [get_ports {HDMI_P[0]}]
set_property IOSTANDARD TMDS_33 [get_ports {HDMI_P[0]}]
# set_property PACKAGE_PIN D20 [get_ports {HDMI_N[0]}]
# set_property IOSTANDARD TMDS_33 [get_ports {HDMI_N[0]}]

# HDMI Data 1 (Green)
set_property PACKAGE_PIN C20 [get_ports {HDMI_P[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {HDMI_P[1]}]
# set_property PACKAGE_PIN B20 [get_ports {HDMI_N[1]}]
# set_property IOSTANDARD TMDS_33 [get_ports {HDMI_N[1]}]

# HDMI Data 2 (Red)
set_property PACKAGE_PIN B19 [get_ports {HDMI_P[2]}]
set_property IOSTANDARD TMDS_33 [get_ports {HDMI_P[2]}]
# set_property PACKAGE_PIN A20 [get_ports {HDMI_N[2]}]
# set_property IOSTANDARD TMDS_33 [get_ports {HDMI_N[2]}]

#===============================================================================
# Buttons (Adapter board)
#===============================================================================
set_property PACKAGE_PIN T19 [get_ports {BTN[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BTN[0]}]

set_property PACKAGE_PIN P19 [get_ports {BTN[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BTN[1]}]

set_property PACKAGE_PIN U20 [get_ports {BTN[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BTN[2]}]

set_property PACKAGE_PIN U19 [get_ports {BTN[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BTN[3]}]

set_property PACKAGE_PIN V20 [get_ports {BTN[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BTN[4]}]

#===============================================================================
# I2S Audio Output (Mapped to free GPIO pins)
#===============================================================================
set_property PACKAGE_PIN N17 [get_ports I2S_BCLK]
set_property IOSTANDARD LVCMOS33 [get_ports I2S_BCLK]

set_property PACKAGE_PIN R19 [get_ports I2S_LRCK]
set_property IOSTANDARD LVCMOS33 [get_ports I2S_LRCK]

set_property PACKAGE_PIN P20 [get_ports I2S_DOUT]
set_property IOSTANDARD LVCMOS33 [get_ports I2S_DOUT]

#===============================================================================
# RGB LED (Adapter board)
#===============================================================================
set_property PACKAGE_PIN E19 [get_ports {LED_RGB[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED_RGB[0]}]

set_property PACKAGE_PIN K17 [get_ports {LED_RGB[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED_RGB[1]}]

set_property PACKAGE_PIN H18 [get_ports {LED_RGB[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED_RGB[2]}]

#===============================================================================
# Timing Exceptions
#===============================================================================
# Asynchronous paths between PS AXI clock (100MHz) and PL pixel clock (27MHz)
# BRAM ports are dual-port, crossing is handled by the BRAM primitive.
set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks -of_objects [get_pins mmcm_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins mmcm_inst/CLKOUT0]] -to [get_clocks clk_fpga_0]
