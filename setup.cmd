@echo off
set script_dir=%~dp0

set arch=%1
set config=%2
set webkit_repo=D:\git\webkit-org
if NOT "%3" == "" set webkit_repo=%3
set ret=0

set vs_version=15
if %vs_version% EQU 15 set vs_year=2017
if %vs_version% EQU 14 set vs_year=2015

if "%arch%" == "x86" (
    set vs_arch=Win32
	set vs_generator="Visual Studio %vs_version% %vs_year%"
    goto :arch_done
)
if "%arch%" == "x64" (
    set vs_arch=x64
	set vs_generator="Visual Studio %vs_version% %vs_year% Win64"
    goto :arch_done
)
echo Architecture ^(param 1^) must be x64 or x86
set ret=1
goto :done
:arch_done

if "%config%" == "Debug" (
    set vcpkg_path=%webkit_repo%\WPEWinLibs\vcpkg\installed\%arch%-windows\debug
	set vs_variant=Debug
	goto :config_done
)
if "%config%" == "Release" (
    set vcpkg_path=%webkit_repo%\WPEWinLibs\vcpkg\installed\%arch%-windows
	set vs_variant=RelWithDebInfo
    goto :config_done
)
echo Config ^(param 2^) must be Debug or Release
set ret=1
goto :done
:config_done

if NOT exist %webkit_repo% (
    set ret=1
	echo WebKit repo ^(param 3^) must refer to a valid location
	goto :done
)

if %vs_version% == 14 set setup_script="C:\Program Files (x86)\Microsoft Visual Studio %vs_version%.0\VC\vcvarsall.bat"
if %vs_version% == 15 set setup_script="C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"

if NOT exist %setup_script% (
    echo Please install Visual Studio Enterprise 2017
    set ret=1
    goto :exit_setup
)

echo %setup_script% %arch%
call %setup_script% %arch%
if %ret% NEQ 0 (
    echo Error returned from %setup_script% %arch%
    goto :done
)
cd /d %script_dir%

if exist %script_dir%\build\%config%-%arch% (
    echo %script_dir%\build\%config%-%arch% found, skipping CMake project generation.
    goto :setup_done
)
pushd .
mkdir %script_dir%\build\%config%-%arch%
cd %script_dir%\build\%config%-%arch%
echo * > ..\.gitignore

set install_dir=%script_dir%\build\%config%-%arch%\installed

if NOT exist %install_dir%\include mkdir %install_dir%\include

xcopy /F /Y /S %vcpkg_path% %install_dir%
if "%config%" == "Debug" xcopy /F /Y /S %webkit_repo%\WPEWinLibs\vcpkg\installed\%arch%-windows\include %install_dir%\include

@echo on
cmake -DBUILD_TYPE=%config% -DCMAKE_INSTALL_PREFIX=%install_dir% -P %webkit_repo%\WebKitBuild-WPE--soup-%arch%\%config%\cmake_install.cmake
@echo off

if %errorlevel% neq 0 (
    echo WebKit install failed.
    exit /b 1
)

@echo on
cmake -G %vs_generator% ..\.. -DCMAKE_INCLUDE_PATH=%install_dir%\include -DCMAKE_LIBRARY_PATH=%install_dir%\lib -DCMAKE_CONFIGURATION_TYPES="%vs_variant%"
devenv /build "%vs_variant%|%vs_arch%" WPELauncher.sln
@echo off

popd
:setup_done

if "%original_path%" == "" set original_path=%PATH%

set PATH=%vcpkg_path%\bin;%original_path%
set WEBKIT_EXEC_PATH=%webkit_repo%\WebKitBuild-WPE--soup-%arch%\%config%\bin\%vs_variant%
set FONTCONFIG_PATH=%webkit_repo%\WPEWinLibs\vcpkg\installed\%arch%-windows\tools\fontconfig\fonts

echo Type devenv build\%config%-%arch%\WPELauncher.sln to open Visual Studio.
echo Set as startup executable: %script_dir%build\%config%-%arch%\launcher\%vs_variant%\WPELauncher.exe
echo Use for command arguments: ^<URL^> --injected-bundle-path %script_dir%build\%config%-%arch%\injectedbundle\%vs_variant%\WPEInjectedBundle.dll

:done
exit /b %ret%