<# :
@echo off
:: Cek privileges Administrator (Penting untuk Windows 7)
net session >nul 2>&1 || (powershell start -verb runas '%~f0' & exit)

:: Setup Hotspot Windows 7 (Ganti SSID/Key jika mau)
netsh wlan set hostednetwork mode=allow ssid=cekks key=12345678
netsh wlan start hostednetwork

setlocal
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ([System.IO.File]::ReadAllText('%~f0'))"
pause
exit /b
#>

# --- CONFIG SERVER ---
# Otomatis mencari IP Laptop di Windows 7
$ip = (gwmi Win32_NetworkAdapterConfiguration | ?{ $_.IPAddress -ne $null }).IPAddress[0]
if (-not $ip) { $ip = "localhost" }

$port = 3000
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:$port/")

$global:status = "true"
$global:user = "MENUNGGU GURU..."

Clear-Host
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "      SERVER BEL CERDAS CERMAT (WIN 7) " -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Minta murid buka browser dan ketik:"
Write-Host "👉 http://$($ip):3000" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Cyan

# --- KONTEN HTML (100% ASLI KAMU) ---
$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Bel Cerdas Cermat</title>
    <style>
        body { display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #ecf0f1; font-family: sans-serif; }
        .bel { padding: 60px 100px; font-size: 50px; font-weight: bold; cursor: pointer; background: #2980b9; color: white; border: none; border-radius: 25px; box-shadow: 0 12px #1c5980; }
        .bel:disabled { background: #95a5a6 !important; box-shadow: none; transform: translateY(8px); cursor: not-allowed; }
        #info { font-size: 30px; margin-bottom: 30px; font-weight: bold; color: #2c3e50; text-align: center; }
        
        #adminPanel { display: none; margin-top: 50px; padding: 20px; background: white; border-radius: 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .btn-admin { padding: 15px 30px; font-size: 18px; margin: 5px; border: none; border-radius: 8px; cursor: pointer; font-weight: bold; color: white; }
        .btn-start { background: #27ae60; }
        .btn-reset { background: #e74c3c; }
    </style>
</head>
<body>
    <div id="info">Menghubungkan...</div>
    
    <button id="btn" class="bel" onclick="pencet()">TEKAN!</button>
    
    <div id="adminPanel">
        <div style="margin-bottom:10px; color:#7f8c8d">PANEL GURU</div>
        <button class="btn-admin btn-start" onclick="updateServer('false', '')">MULAI KUIS</button>
        <button class="btn-admin btn-reset" onclick="updateServer('true', 'RESET OLEH GURU')">RESET / STOP</button>
    </div>

    <script>
        const idDefault = 'Murid_' + Math.floor(1000 + Math.random() * 9000);
        const myId = prompt("Masukkan Nama Anda (Ketik username khusus untuk Guru):", idDefault) || idDefault;
        
        const btn = document.getElementById('btn');
        const info = document.getElementById('info');
        const panel = document.getElementById('adminPanel');

        if (myId.toLowerCase() === 'admin#123') {
            panel.style.display = 'block';
            btn.style.display = 'none'; 
            info.innerText = "Mode Guru Aktif";
        }

        function bunyi() {
            try {
                const ctx = new (window.AudioContext || window.webkitAudioContext)();
                const osc = ctx.createOscillator();
                osc.type = 'sawtooth';
                osc.connect(ctx.destination);
                osc.start(); setTimeout(() => osc.stop(), 600);
            } catch(e){}
        }

        async function pencet() {
            bunyi();
            btn.disabled = true; 
            await fetch('/update?lock=true&user=' + encodeURIComponent(myId));
        }

        async function updateServer(s, u) {
            await fetch('/update?lock=' + s + '&user=' + encodeURIComponent(u));
        }

        setInterval(async () => {
            try {
                const res = await fetch('/data');
                const data = await res.json();
                
                if (myId.toLowerCase() !== 'admin#123') {
                    if (data.isLocked === "true") {
                        btn.disabled = true;
                        info.innerText = data.user === "RESET OLEH GURU" || data.user === "MENUNGGU GURU..." ? data.user : "PEMENANG: " + data.user;
                        info.style.color = "#c0392b";
                    } else {
                        btn.disabled = false;
                        info.innerText = "AYO TEKAN!";
                        info.style.color = "#27ae60";
                    }
                } else {
                    info.innerText = data.isLocked === "true" ? "Status: TERKUNCI (" + data.user + ")" : "Status: KUIS BERJALAN";
                }
            } catch (e) {}
        }, 100);
    </script>
</body>
</html>
"@

$listener.Start()
try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        $res.AddHeader("Access-Control-Allow-Origin", "*")
        $path = $req.Url.LocalPath

        if ($path -eq "/update") {
            $newLock = $req.QueryString["lock"]
            $newUser = $req.QueryString["user"]
            if ($global:status -eq "false" -or $newLock -eq "false" -or $newUser -eq "RESET OLEH GURU") {
                $global:status = $newLock
                $global:user = $newUser
                Write-Host "Update: $global:user ($global:status)" -ForegroundColor Green
            }
            $buffer = [System.Text.Encoding]::UTF8.GetBytes("OK")
        } 
        elseif ($path -eq "/data") {
            $json = '{"isLocked": "' + $global:status + '", "user": "' + $global:user + '"}'
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $res.ContentType = "application/json"
        } 
        else {
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $res.ContentType = "text/html"
        }
        $res.ContentLength64 = $buffer.Length
        $res.OutputStream.Write($buffer, 0, $buffer.Length)
        $res.Close()
    }
} finally { $listener.Stop() }
