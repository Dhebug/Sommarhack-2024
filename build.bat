@ECHO OFF
cls
setlocal

:: Create a ESC environment variable containing the escape character
:: See: https://gist.github.com/mlocati/fdabcaeb8071d5c75a2d51712db24011#file-win10colors-cmd
for /F %%a in ('"prompt $E$S & echo on & for %%b in (1) do rem"') do set "ESC=%%a"

echo %ESC%[1mBuild started: %date% %time%%ESC%[0m

md export
bin\PictConv.exe -m1 -f3 -o2 data\dbug_surprise.png export\surprise.bin
bin\PictConv.exe -m1 -f3 -o2 data\top_banner.png export\top_banner.bin
bin\PictConv.exe -m1 -f3 -o2 data\made_in_5_days.png export\made_in_5_days.bin
bin\PictConv.exe -m1 -f3 -o2 data\credits.png export\credits.bin
bin\PictConv.exe -m1 -f3 -o2 data\greetings.png export\greetings.bin
bin\PictConv.exe -m1 -f3 -o2 data\title.png export\title.bin
bin\PictConv.exe -m1 -f3 -o2 data\mind_bender.png export\mind_bender.bin
bin\PictConv.exe -m1 -f3 -o2 data\mono_slide.png export\mono_slide.bin
bin\PictConv.exe -m1 -f3 -o2 data\slide_show.png export\slide_show.bin
bin\PictConv.exe -m1 -f3 -o2 data\the_end.png export\the_end.bin

::
:: http://sun.hasenbraten.de/vasm/index.php?view=tutorial
:: http://sun.hasenbraten.de/vasm/release/vasm.html
::
del 0Bitplan.prg 2>NUL
del final\1Bitplan.prg

:: -quiet 
bin\vasm.exe -m68000 -Ftos -noesc -no-opt -o 0Bitplan.prg ZeroBitplan.s
IF ERRORLEVEL 1 GOTO ErrorVasm

:: Copy to the emulator folder
copy 0Bitplan.prg D:\_emul_\atari\_mount_\DEFENCEF.RCE\0Bitplan

:: Copy to the SD Card for the UltraSatan is available
if exist S:\sommarhack\0Bitplan.prg copy 0Bitplan.prg S:\sommarhack\0Bitplan.prg

::pause
goto :End

:ErrorVasm
ECHO. 
ECHO %ESC%[41mAn Error has happened. Build stopped%ESC%[0m
::pause
goto :End


:End
ECHO done

