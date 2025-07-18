:copype
setlocal

set TEMPL=media
set FWFILES=fwfiles

rem
rem Input validation
rem
if /i "%1"=="/?" goto usage
if /i "%1"=="" goto usage
if /i "%~2"=="" goto usage
if /i not "%3"=="" goto usage

rem
rem Set environment variables for use in the script
rem
set WINPE_ARCH=%1
set SOURCE=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\%WINPE_ARCH%
set FWFILESROOT=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\%WINPE_ARCH%\Oscdimg
set DEST=%~2
set WIMSOURCEPATH=%SOURCE%\en-us\winpe.wim

rem
rem Validate input architecture
rem
rem If the source directory as per input architecture does not exist,
rem it means the architecture is not present
rem
if not exist "%SOURCE%" (
  echo ERROR: The following processor architecture was not found: %WINPE_ARCH%.
  exit /b 1
)

rem
rem Validate the boot app directory location
rem
rem If the input architecture is validated, this directory must exist
rem This check is only to be extra careful
rem
if not exist "%FWFILESROOT%" (
  echo ERROR: The following path for firmware files was not found: "%FWFILESROOT%".
  exit /b 1
)

rem
rem Make sure the appropriate winpe.wim is present
rem
if not exist "%WIMSOURCEPATH%" (
  echo ERROR: WinPE WIM file does not exist: "%WIMSOURCEPATH%".
  exit /b 1
)

rem
rem Make sure the destination directory does not exist
rem
if exist "%DEST%" (
  echo ERROR: Destination directory exists: %2.
  exit /b 1
)

mkdir "%DEST%"
if errorlevel 1 (
  echo ERROR: Unable to create destination: %2.
  exit /b 1
)

echo.
echo ===================================================
echo Creating Windows PE customization working directory
echo.
echo     %DEST%
echo ===================================================
echo.

mkdir "%DEST%\%TEMPL%"
if errorlevel 1 goto :FAIL
mkdir "%DEST%\mount"
if errorlevel 1 goto :FAIL
mkdir "%DEST%\%FWFILES%"
if errorlevel 1 goto :FAIL

rem
rem Copy the boot files and WinPE WIM to the destination location
rem
xcopy /cherky "%SOURCE%\Media" "%DEST%\%TEMPL%\"
if errorlevel 1 goto :FAIL
mkdir "%DEST%\%TEMPL%\sources"
if errorlevel 1 goto :FAIL
copy "%WIMSOURCEPATH%" "%DEST%\%TEMPL%\sources\boot.wim"
if errorlevel 1 goto :FAIL

rem
rem Copy the boot apps to enable ISO boot
rem
rem  UEFI boot uses efisys.bin
rem  BIOS boot uses etfsboot.com
rem
copy "%FWFILESROOT%\efisys.bin" "%DEST%\%FWFILES%"
if errorlevel 1 goto :FAIL
if exist "%FWFILESROOT%\etfsboot.com" (
  copy "%FWFILESROOT%\etfsboot.com" "%DEST%\%FWFILES%"
  if errorlevel 1 goto :FAIL
)

endlocal
echo.
echo Success
echo.

cd /d "%~2"

goto :EOF

:usage
echo Creates working directories for WinPE image customization and media creation.
echo.
echo copype { amd64 ^| x86 ^| arm } ^<workingDirectory^>
echo.
echo  amd64             Copies amd64 boot files and WIM to ^<workingDirectory^>\media.
echo  x86               Copies x86 boot files and WIM to ^<workingDirectory^>\media.
echo  arm               Copies arm boot files and WIM to ^<workingDirectory^>\media.
echo                    Note: ARM content may not be present in this ADK.
echo  workingDirectory  Creates the working directory at the specified location.
echo.
echo Example: copype amd64 C:\WinPE_amd64
goto :EOF

:FAIL
echo ERROR: Failed to create working directory.
set EROP=YEs
exit /b 1
Rem CopyPE created by Microsoft and Edited by Lucas Elliott and wjsorensen on technet
::------------------------ END --------------------------