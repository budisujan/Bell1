@echo off
set "ps_file=%temp%\bel_logic.ps1"

:: Membuat file powershell sementara tanpa merusak kode asli
copy /y nul "%ps_file%" >nul

(
echo # --- CONFIG SERVER ---
echo $port = 3000
echo $listener = New-Object System.Net.HttpListener
echo $listener.Prefixes.Add("http://*:$port/"^)
echo.
echo # Variabel Penyimpan
echo $global:status = "true"
echo $global:user = "MENUNGGU GURU..."
echo.
echo Clear-Host
echo Write-Host "=======================================" -ForegroundColor Cyan
echo Write-Host "      SERVER BEL CERDAS CERMAT         " -ForegroundColor Cyan
echo Write-Host "=======================================" -ForegroundColor Cyan
echo Write-Host "Buka: http://localhost:3000" -ForegroundColor White
echo Write-Host "Gunakan nama 'admin' untuk mode Guru." -ForegroundColor Yellow
echo.
echo $html = @'
) > "%ps_file%"

:: Bagian HTML (Tanpa perubahan)
type <<EOF >> "%ps_file%"
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
        const myId = prompt("Masukkan Nama Anda (Ketik 'admin' untuk Guru):", idDefault) || idDefault;
        const btn = document.getElementById('btn');
        const info = document.getElementById('info');
        const panel = document.getElementById('adminPanel');
        if (myId.toLowerCase() === 'admin') {
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
                if (myId.toLowerCase() !== 'admin') {
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
EOF

:: Bagian akhir logika server
(
echo '@
echo.
echo $listener.Start(^)
echo try {
echo     while ($listener.IsListening^) {
echo         $ctx = $listener.GetContext(^)
echo         $req = $ctx.Request
echo         $res = $ctx.Response
echo         $res.AddHeader("Access-Control-Allow-Origin", "*"^)
echo         $path = $req.Url.LocalPath
echo         if ($path -eq "/update"^) {
echo             $newLock = $req.QueryString["lock"]
echo             $newUser = $req.QueryString["user"]
echo             if ($global:status -eq "false" -or $newLock -eq "false" -or $newUser -eq "RESET OLEH GURU"^) {
echo                 $global:status = $newLock
echo                 $global:user = $newUser
echo                 Write-Host "Update: $global:user ($global:status)" -ForegroundColor Green
echo             }
echo             $buffer = [System.Text.Encoding]::UTF8.GetBytes("OK"^)
echo         } elseif ($path -eq "/data"^) {
echo             $json = "{\`"isLocked\`": \`"$global:status\`", \`"user\`": \`"$global:user\`"}"
echo             $buffer = [System.Text.Encoding]::UTF8.GetBytes($json^)
echo             $res.ContentType = "application/json"
echo         } else {
echo             $buffer = [System.Text.Encoding]::UTF8.GetBytes($html^)
echo             $res.ContentType = "text/html"
echo         }
echo         $res.ContentLength64 = $buffer.Length
echo         $res.OutputStream.Write($buffer, 0, $buffer.Length^)
echo         $res.Close(^)
echo     }
echo } finally { $listener.Stop(^) }
) >> "%ps_file%"

:: Menjalankan file yang sudah dibuat
powershell -NoProfile -ExecutionPolicy Bypass -File "%ps_file%"
pause
