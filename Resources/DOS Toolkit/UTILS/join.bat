@echo off

ipx true

rem If no port was specified in the Boxer configuration file, use default
IF "%IPXPORT%"=="" SET IPXPORT=2130

rem Use any user-specified IP address and port
IF NOT "%1"=="" SET IPXIP=%1
IF NOT "%2"=="" SET IPXPORT=%2

rem Skip IP confirmation if user gave an IP address on the commandline
IF NOT "%1"=="" goto connect

rem If the user didn't specify an IP address, prompt them for one
rem This defaults to the IP address from the last connection attempt

wbat box @:ip-prompt > %TEMP%\WBATVARS.BAT
IF ERRORLEVEL 100 goto exit
call %TEMP%\WBATVARS.BAT

IF "%IPXIP%"=="" goto exit

:connect

ipxnet connect %IPXIP% %IPXPORT%

:exit
del %TEMP%\WBATVARS.BAT > nul