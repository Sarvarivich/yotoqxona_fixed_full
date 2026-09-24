# =====================================================================
# MAVJUD TALABALARNING EMAILINI QISQARTIRISH
#
# Ilgari email toliq ismdan yasalardi:
#   TURG'UNOV SIROJIDDIN AKMAL O'G'LI
#   -> turgunov.sirojiddin.akmal.ogli@ku.uz
#
# Endi faqat familiya va ism:
#   -> turgunov.sirojiddin@ku.uz
#
# Skript talabalarni F.I.Sh. boyicha topadi va emailini yangilaydi.
#
# Ishlatilishi:
#   cd D:\yotoqxona_fixed_full
#   powershell -ExecutionPolicy Bypass -File email_yangilash.ps1
# =====================================================================

# --- SOZLAMALAR ------------------------------------------------------

$CsvYol    = "D:\email_yangilash.csv"
$ApiManzil = "https://web-production-53ebe.up.railway.app/api"
$Email     = "superadmin@kuhostel.uz"
$Parol     = "Super12345"

# $true  = hech narsa ozgartirilmaydi, faqat korsatiladi
# $false = haqiqiy yangilash
$SinovRejimi = $false

# Nechta yangilansin. 0 = hammasi.
$Limit = 0

# ---------------------------------------------------------------------

$ErrorActionPreference = "Stop"

if (-not (Test-Path $CsvYol)) {
    Write-Host "XATO: $CsvYol topilmadi." -ForegroundColor Red
    exit 1
}

# --- Login -----------------------------------------------------------

Write-Host "Tizimga kirilmoqda..." -ForegroundColor Cyan
try {
    $javob = Invoke-RestMethod -Uri "$ApiManzil/login" -Method Post `
        -ContentType "application/json" `
        -Body (@{ email = $Email; password = $Parol } | ConvertTo-Json)
} catch {
    Write-Host "Login muvaffaqiyatsiz." -ForegroundColor Red
    exit 1
}

$Sarlavhalar = @{ Authorization = "Bearer $($javob.token)" }
Write-Host "Kirildi: $($javob.user.full_name)" -ForegroundColor Green

# --- Mavjud talabalarni yuklash --------------------------------------
#
# Backend bir sorovda 100 tadan kop bermaydi.

Write-Host ""
Write-Host "Talabalar yuklanmoqda..." -ForegroundColor Cyan

$mavjud = @{}
$sahifa = 1
$oxirgi = 1

do {
    $s = Invoke-RestMethod -Headers $Sarlavhalar `
        -Uri "$ApiManzil/students?role=talaba&hostel=boys&per_page=100&page=$sahifa"

    foreach ($t in $s.data) {
        $kalit = $t.full_name.Trim()
        if (-not $mavjud.ContainsKey($kalit)) {
            $mavjud[$kalit] = $t
        }
    }

    if ($s.meta -and $s.meta.last_page) { $oxirgi = $s.meta.last_page }
    $sahifa++
} while ($sahifa -le $oxirgi -and $sahifa -le 50)

Write-Host "Topildi: $($mavjud.Count) ta" -ForegroundColor Green

# --- CSV oqish -------------------------------------------------------

$qatorlar = Import-Csv $CsvYol
if ($Limit -gt 0) {
    $qatorlar = $qatorlar | Select-Object -First $Limit
}

Write-Host ""
if ($SinovRejimi) {
    Write-Host "*** SINOV REJIMI - hech narsa ozgartirilmaydi ***" -ForegroundColor Yellow
    Write-Host ""
}

# --- Yangilash -------------------------------------------------------

$yangilandi = 0
$otkazildi = 0
$topilmadi = 0
$xato = 0
$xatolar = @()

foreach ($q in $qatorlar) {
    $ism = $q.full_name.Trim()
    $yangiEmail = $q.email.Trim().ToLower()

    if (-not $mavjud.ContainsKey($ism)) {
        Write-Host "  TOPILMADI: $ism" -ForegroundColor Yellow
        $topilmadi++
        continue
    }

    $talaba = $mavjud[$ism]
    $eskiEmail = $talaba.email.Trim().ToLower()

    if ($eskiEmail -eq $yangiEmail) {
        $otkazildi++
        continue
    }

    if ($SinovRejimi) {
        Write-Host "  [sinov] $eskiEmail" -ForegroundColor DarkGray
        Write-Host "       -> $yangiEmail" -ForegroundColor DarkCyan
        $yangilandi++
        continue
    }

    try {
        $tana = @{ email = $yangiEmail } | ConvertTo-Json

        Invoke-RestMethod -Uri "$ApiManzil/students/$($talaba.id)" -Method Put `
            -Headers $Sarlavhalar -ContentType "application/json; charset=utf-8" `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($tana)) | Out-Null

        $yangilandi++
        Write-Host "  OK  $yangiEmail" -ForegroundColor Green

        Start-Sleep -Milliseconds 120

    } catch {
        $kod = $_.Exception.Response.StatusCode.value__
        $xabar = $_.ErrorDetails.Message
        Write-Host "  XATO ($kod): $ism" -ForegroundColor Red
        if ($xabar) { Write-Host "         $xabar" -ForegroundColor DarkRed }
        $xato++
        $xatolar += "$ism | $yangiEmail | [$kod] $xabar"
    }
}

# --- Yakun -----------------------------------------------------------

Write-Host ""
Write-Host "=== YAKUN ===" -ForegroundColor Cyan
Write-Host "Yangilandi:  $yangilandi" -ForegroundColor Green
Write-Host "Ozgarmadi:   $otkazildi" -ForegroundColor DarkGray
Write-Host "Topilmadi:   $topilmadi" -ForegroundColor $(if ($topilmadi -gt 0) { "Yellow" } else { "Gray" })
Write-Host "Xato:        $xato" -ForegroundColor $(if ($xato -gt 0) { "Red" } else { "Gray" })

if ($xatolar.Count -gt 0) {
    $xatolar | Out-File "D:\email_xatolari.txt" -Encoding UTF8
    Write-Host ""
    Write-Host "Xatolar D:\email_xatolari.txt ga yozildi." -ForegroundColor Yellow
}

if ($SinovRejimi) {
    Write-Host ""
    Write-Host "Bu SINOV edi. Haqiqiy yangilash uchun skript ichida:" -ForegroundColor Yellow
    Write-Host '  $SinovRejimi = $false'
    Write-Host '  $Limit = 0'
}
