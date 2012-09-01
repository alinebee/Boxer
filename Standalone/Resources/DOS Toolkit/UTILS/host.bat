@echo off

rem If no port was specified in the Boxer configuration file, use default
IF "%IPXPORT%"=="" SET IPXPORT=2130
IF "%SERIALPORT%"=="" SET SERIALPORT=2131

rem Use the user-specified port
IF NOT "%1"=="" SET IPXPORT=%1
IF NOT "%2"=="" SET SERIALPORT=%2

ipx true
ipxnet startserver %IPXPORT%
serial1 nullmodem port:%SERIALPORT%