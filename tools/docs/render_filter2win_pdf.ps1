param([Parameter(Mandatory=$true)][string]$Package)
$ErrorActionPreference='Stop'
$chrome='C:\Program Files\Google\Chrome\Application\chrome.exe'
if (!(Test-Path -LiteralPath $chrome)) { throw 'Chrome renderer is unavailable' }
$packagePath=(Resolve-Path -LiteralPath $Package).Path
$proof=@()
foreach ($name in @('filter2win','fifo_double')) {
    $html=Join-Path $packagePath "docs\html\$name.html"
    $pdf=Join-Path $packagePath "docs\$name.pdf"
    if (Test-Path -LiteralPath $pdf) { throw "Refuse to overwrite $pdf" }
    $profile=Join-Path $env:TEMP ([guid]::NewGuid().ToString('N'))
    $process=$null
    try {
        $uri=([uri]$html).AbsoluteUri
        $arguments=@('--headless','--disable-gpu','--no-first-run','--no-default-browser-check',
            "--user-data-dir=`"$profile`"",'--no-pdf-header-footer','--timeout=15000',
            "--print-to-pdf=`"$pdf`"","`"$uri`"")
        $process=Start-Process -FilePath $chrome -ArgumentList $arguments -PassThru
        if (!$process.WaitForExit(60000)) { throw "Renderer timed out: $name" }
        if (!(Test-Path -LiteralPath $pdf)) { throw "Renderer produced no PDF: $name" }
        $proof+=@{document=$name;renderer=$chrome;version=(Get-Item $chrome).VersionInfo.FileVersion;
            html_sha256=(Get-FileHash $html -Algorithm SHA256).Hash;
            pdf_sha256=(Get-FileHash $pdf -Algorithm SHA256).Hash}
    } finally {
        # Restrict cleanup to processes carrying this unique executor-owned profile.
        Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object {
            $_.CommandLine -like "*$profile*"
        } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        if ($process) { $process.Dispose() }
        if (Test-Path $profile) { Remove-Item -LiteralPath $profile -Recurse -Force }
    }
}
$proof | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $packagePath 'results\pdf_render.json')