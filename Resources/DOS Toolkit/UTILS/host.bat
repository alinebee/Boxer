@echo off

rem If no port was specified in the Boxer configuration file, use default
IF "%IPXPORT%"=="" SET IPXPORT=2130

rem Use the user-specified port
IF NOT "%1"=="" SET IPXPORT=%1

ipx true
ipxnet startserver %IPXPORT%
ipxnet status