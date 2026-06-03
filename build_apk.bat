@echo off
setlocal enabledelayedexpansion

set JAVA_HOME=C:\Android\jdk\jdk-21.0.6+7
set ANDROID_HOME=C:\Android
set ANDROID_SDK_ROOT=C:\Android
set FLUTTER_ROOT=C:\download_software\flutter_windows_3.41.9-stable\flutter
set PATH=%JAVA_HOME%\bin;%FLUTTER_ROOT%\bin;%PATH%

cd /d C:\Trea_project\GouWu\gouwu

echo ========================================
echo   Step 1: Cleaning up old processes...
echo ========================================
taskkill /f /im dart.exe >nul 2>&1
taskkill /f /im java.exe >nul 2>&1

echo ========================================
echo   Step 2: Downloading Gradle 8.11.1...
echo ========================================
set GRADLE_ZIP=%TEMP%\gradle-8.11.1-all.zip
set GRADLE_DIST=%USERPROFILE%\.gradle\wrapper\dists\gradle-8.11.1-all\2qik7nd48slq1ooc2496ixf4i

if exist "%GRADLE_DIST%\gradle-8.11.1-all.zip" (
    echo Gradle already downloaded, skipping...
) else (
    echo Downloading from services.gradle.org...
    powershell -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri 'https://services.gradle.org/distributions/gradle-8.11.1-all.zip' -OutFile '%GRADLE_ZIP%' -TimeoutSec 600"
    if not exist "%GRADLE_ZIP%" (
        echo ERROR: Failed to download Gradle!
        pause
        exit /b 1
    )
    mkdir "%GRADLE_DIST%" 2>nul
    copy /y "%GRADLE_ZIP%" "%GRADLE_DIST%\gradle-8.11.1-all.zip"
    echo Gradle downloaded successfully!
)

echo.
echo ========================================
echo   Step 3: Cleaning old build cache...
echo ========================================
echo.
call flutter clean
if %ERRORLEVEL% neq 0 (
    echo WARNING: flutter clean had issues, continuing...
)

echo.
echo ========================================
echo   Step 4: Getting Flutter dependencies...
echo ========================================
echo.

call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo ERROR: flutter pub get failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Step 5: Building APK with Gradle...
echo   (This may take 5-10 minutes)
echo ========================================
echo.

cd android
call gradlew.bat assembleDebug
set BUILD_RESULT=%ERRORLEVEL%
cd ..

echo.
echo ========================================
if %BUILD_RESULT% equ 0 (
    echo   BUILD SUCCESS!
    echo   APK: build\app\outputs\flutter-apk\app-debug.apk
) else (
    echo   BUILD FAILED (exit code: %BUILD_RESULT%)
    echo   If Gradle download timed out, just run this script again.
)
echo ========================================
pause