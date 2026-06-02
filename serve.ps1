$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://+:8766/")
$listener.Start()

$mime = @{".html"="text/html; charset=utf-8"; ".js"="application/javascript"; ".css"="text/css"; ".wasm"="application/wasm"; ".json"="application/json"; ".png"="image/png"; ".jpg"="image/jpeg"; ".svg"="image/svg+xml"; ".ico"="image/x-icon"}

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $p = $ctx.Request.Url.LocalPath
    if ($p -eq '/') { $p = '/index.html' }
    $fp = "C:\Trea_project\GouWu\gouwu\build\web$p"
    if (Test-Path $fp) {
        $ext = [System.IO.Path]::GetExtension($fp)
        if ($mime[$ext]) { $ctx.Response.ContentType = $mime[$ext] }
        $ctx.Response.Headers.Add("Cache-Control", "no-cache")
        $c = [System.IO.File]::ReadAllBytes($fp)
        $ctx.Response.ContentLength64 = $c.Length
        $ctx.Response.OutputStream.Write($c,0,$c.Length)
    } else {
        $ctx.Response.StatusCode = 404
    }
    $ctx.Response.Close()
}