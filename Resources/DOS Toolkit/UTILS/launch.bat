@echo off

IF "%1"=="" goto usage

rem Get the batchfile to delete itself as soon as it is launched
echo @del %%%0 > %TEMP%\TEMPRUN.BAT

rem Find the first executable that matches the search string
locate %1 /x /f:1 /g /b8:"call" >> %TEMP%\TEMPRUN.BAT
IF ERRORLEVEL 1 goto failure

rem Now launch the executable
call %TEMP%\TEMPRUN.BAT %2 %3 %4 %5 %6 %7 %8
goto end

:failure
del %TEMP%\TEMPRUN.BAT > nul
echo No program matching the name "%1" could be found.
goto end

:usage
echo.
echo.Launch an executable program from anywhere in the DOS filesystem. 
echo The file extension is optional, and wildcards are supported.
echo.
echo.[33;1mUSAGE:[0m    [34;1mlaunch [name of program] [arguments for program][0m
echo.
echo.[33;1mEXAMPLES:[0m launch install
echo.          launch game.exe /param1 /param2
echo.          launch ultima*
echo.

:end