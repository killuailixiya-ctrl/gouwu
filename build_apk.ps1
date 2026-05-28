$env:JAVA_HOME = "C:\Android\jdk\jdk-21.0.6+7"
$env:ANDROID_HOME = "C:\Android"
$env:ANDROID_SDK_ROOT = "C:\Android"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

$flutterBin = "C:\download_software\flutter_windows_3.41.9-stable\flutter\bin\flutter.bat"

Write-Host "=== Flutter Version ==="
& $flutterBin --version

Write-Host "=== Building APK ==="
& $flutterBin build apk --debug

Write-Host "=== Build Complete ==="