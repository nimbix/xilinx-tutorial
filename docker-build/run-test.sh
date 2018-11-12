#!/bin/bash
# SDAccel Example to test
app_source=/opt/example
krnl_name=vdotprod
# <tag> will be replaced by Dockerfile
dsa_name=<xcl-dsa-name>
# Setup Xilinx SDAccel environment
source /opt/xilinx/xrt/setup.sh
# SDAccel Examples use hard coded path to *.xclbin file
# This behavior is set in the host C/C++ code
# and is NOT a requirement for the Xilinx runtime
# Create expected file path in ${HOME}
cp ${app_source}/${krnl_name} ${HOME}
mkdir -p ${HOME}/xclbin
# Link to example FPGA bitstream (*.xclbin)
link_name=${HOME}/xclbin/krnl_${krnl_name}.hw.${dsa_name}.xclbin
ln -s ${app_source}/test.xclbin ${link_name} 
# Run SDAccel Example test
PATH=${HOME}:${PATH}
${krnl_name}
