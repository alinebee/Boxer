@echo off

IF "%1"=="" goto usage

type %1 %2 %3 %4 %5 %6 %7 %8 %9 > PRN
goto end

:usage
echo.
echo.Print one or more files to the emulated printer. Files will be printed
echo.as plain text: for formatting and margin control, you should print using
echo.the program that created the file instead.
echo.
echo.[33;1mUSAGE:[0m    [34;1mprint [path/to/file.txt1] [path/to/file2.txt][...][0m
echo.
echo.[33;1mEXAMPLES:[0m print readme.txt
echo.          print doc1.txt doc2.txt doc3.txt
echo.

:end