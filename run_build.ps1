$dart = "C:\download_software\flutter_windows_3.41.9-stable\flutter\bin\cache\dart-sdk\bin\dart.exe"
$snapshot = "C:\download_software\flutter_windows_3.41.9-stable\flutter\bin\cache\flutter_tools.snapshot"
$packages = "C:\download_software\flutter_windows_3.41.9-stable\flutter\packages\flutter_tools\.dart_tool\package_config.json"

$env:JAVA_HOME = "C:\Android\jdk\jdk-21.0.6+7"
$env:ANDROID_HOME = "C:\Android"
$env:ANDROID_SDK_ROOT = "C:\Android"
$env:FLUTTER_ROOT = "C:\download_software\flutter_windows_3.41.9-stable\flutter"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

Write-Host "Starting Flutter build..."
$result = & $dart --packages="$packages" $snapshot build apk --debug 2>&1
Write-Host "Result: $result"
Write-Host "Exit code: $LASTEXITCODE"