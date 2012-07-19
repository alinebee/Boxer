@echo off
wbat box @:network-menu
IF ERRORLEVEL 100 goto exit
IF ERRORLEVEL 3 goto status
IF ERRORLEVEL 2 goto join
IF ERRORLEVEL 1 goto host

:host
call %BOXERUTILS%\host.bat
goto exit

:join
call %BOXERUTILS%\join.bat
goto exit

:status
ipx true
ipxnet status
goto exit

:exit