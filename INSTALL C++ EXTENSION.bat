@ECHO OFF
CLS
ECHO Installing C++ Extension for Godot

git submodule add -f -b 4.2 https://github.com/godotengine/godot-cpp ./godot-cpp

cd godot-cpp

git submodule update --init
pip install scons

ECHO 1.Windows
ECHO 2.Linux
ECHO 3.MacOS

CHOICE /C 123 /M "Enter your OS: "

:: Note listed ERRORLEVELS are in decreasing order
IF ERRORLEVEL 3 GOTO MacOS
IF ERRORLEVEL 2 GOTO Linux
IF ERRORLEVEL 1 GOTO Windows

:Windows
scons platform=windows
scons platform=windows custom_api_file=gdextension/extension_api.json
GOTO End

:Linux
scons platform=Linux
scons platform=Linux custom_api_file=gdextension/extension_api.json
GOTO End

:MacOS
scons platform=macos
scons platform=macos custom_api_file=gdextension/extension_api.json
GOTO End

:End
PAUSE