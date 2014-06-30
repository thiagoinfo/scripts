@echo off
REM
REM %1 = SSH connection string (user@IMM)
REM %2 = IMM password
REM

echo y | plink -pw %2 %1 "asu set BootOrder.BootOrder ""CD/DVD Rom=Embedded Hypervisor"""
echo y | plink -pw %2 %1 "asu set BootOrder.WolBootOrder ""CD/DVD Rom=Embedded Hypervisor"""
echo y | plink -pw %2 %1 "asu set DevicesandIOPorts.SASController Disable"
echo y | plink -pw %2 %1 "asu show BootOrder.BootOrder"
echo y | plink -pw %2 %1 "asu show BootOrder.WolBootOrder"
echo y | plink -pw %2 %1 "asu show DevicesandIOPorts.SASController"
