@echo off

locate /x /nr /w %1 %2 %3 %4 %5 %6 %7 %8 %9
IF ERRORLEVEL 1 goto failure
goto end

:failure
echo.There are no executable programs in this folder.
echo.

:end