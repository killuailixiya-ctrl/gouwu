$env:JAVA_HOME = "C:\Android\jdk\jdk-21.0.6+7"
$env:ANDROID_HOME = "C:\Android"
$env:ANDROID_SDK_ROOT = "C:\Android"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

Set-Location "C:\Trea_project\GouWu\gouwu\android"

$java = "$env:JAVA_HOME\bin\java.exe"
$wrapperJar = "gradle\wrapper\gradle-wrapper.jar"

Write-Host "Running Gradle wrapper..."
& $java -jar $wrapperJar assembleDebug 2>&1 | Tee-Object -FilePath "C:\Trea_project\GouWu\gouwu\gradle_result.txt"
Write-Host "Exit code: $LASTEXITCODE"