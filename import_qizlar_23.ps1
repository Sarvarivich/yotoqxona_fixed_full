# =====================================================================
# TALABALARNI CSV DAN IMPORT QILISH
#
# DAVOM ETTIRISH
# --------------
# Skript muvaffaqiyatli kiritilgan har bir email ni
# import_bajarildi.txt ga yozib boradi. Qaytadan ishlatilganda
# ularni otkazib yuboradi.
#
# Shuning uchun internet uzilsa yoki xato chiqsa, shunchaki qayta
# ishlating - boshidan emas, toxtagan joyidan davom etadi.
#
# Ishlatilishi:
#   cd D:\yotoqxona_fixed_full
#   powershell -ExecutionPolicy Bypass -File import_talabalar_v2.ps1
# =====================================================================

# --- SOZLAMALAR ------------------------------------------------------

$CsvYol    = "D:\qizlar_23_import.csv"
$ApiManzil = "https://web-production-53ebe.up.railway.app/api"
$Email     = "superadmin@kuhostel.uz"
$Parol     = "Super12345"

# Bajarilganlar royxati. Ochirilsa, skript hammasini qaytadan
# kiritishga urinadi (mavjudlari 422 bilan otkaziladi).
$BelgiYol  = "D:\qizlar23_bajarildi.txt"

# $true  = hech narsa yozilmaydi, faqat tekshiriladi
# $false = haqiqiy kiritish
$SinovRejimi = $false

# Nechta qator kiritilsin. 0 = hammasi.
# Birinchi marta 3 qoyib sinang.
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
    Write-Host "Login muvaffaqiyatsiz: $($_.ErrorDetails.Message)" -ForegroundColor Red
    exit 1
}

$Token = $javob.token
if (-not $Token) {
    Write-Host "Token olinmadi." -ForegroundColor Red
    exit 1
}
$Sarlavhalar = @{ Authorization = "Bearer $Token" }
Write-Host "Kirildi: $($javob.user.full_name) ($($javob.user.role))" -ForegroundColor Green

# --- Serverdagi mavjud emaillar --------------------------------------
#
# Email takrorlansa backend 422 qaytaradi va talaba kiritilmay qoladi.
# Shuning uchun oldindan royxatni olib, to'qnashganiga raqam qo'shamiz.

Write-Host ""
Write-Host "Mavjud emaillar yuklanmoqda..." -ForegroundColor Cyan

$mavjudEmail = @{}
$sahifa = 1
$oxirgi = 1
do {
    $s = Invoke-RestMethod -Headers $Sarlavhalar `
        -Uri "$ApiManzil/students?per_page=100&page=$sahifa"
    foreach ($t in $s.data) {
        if ($t.email) { $mavjudEmail[$t.email.ToLower()] = $true }
    }
    if ($s.meta -and $s.meta.last_page) { $oxirgi = $s.meta.last_page }
    $sahifa++
} while ($sahifa -le $oxirgi -and $sahifa -le 50)

Write-Host "Mavjud: $($mavjudEmail.Count) ta email" -ForegroundColor Green

# --- Bajarilganlarni oqish -------------------------------------------

$bajarildi = @{}
if (Test-Path $BelgiYol) {
    Get-Content $BelgiYol | ForEach-Object {
        $e = $_.Trim()
        if ($e) { $bajarildi[$e] = $true }
    }
    Write-Host "Ilgari kiritilgan: $($bajarildi.Count) ta" -ForegroundColor DarkGray
}

# --- CSV oqish -------------------------------------------------------

$hammasi = Import-Csv $CsvYol
$qatorlar = $hammasi | Where-Object { -not $bajarildi.ContainsKey($_.email) }

Write-Host ""
Write-Host "CSV'da jami:  $($hammasi.Count)" -ForegroundColor Cyan
Write-Host "Qolgan:       $($qatorlar.Count)" -ForegroundColor Cyan

if ($Limit -gt 0) {
    $qatorlar = $qatorlar | Select-Object -First $Limit
    Write-Host "Bu safar:     $($qatorlar.Count) (Limit=$Limit)" -ForegroundColor Yellow
}

if ($SinovRejimi) {
    Write-Host ""
    Write-Host "*** SINOV REJIMI - hech narsa yozilmaydi ***" -ForegroundColor Yellow
}
Write-Host ""

# --- Kiritish --------------------------------------------------------

$muvaffaqiyat = 0
$xato = 0
$otkazildi = 0
$xatolar = @()
$boshlandi = Get-Date

foreach ($q in $qatorlar) {

    # Majburiy maydonlar
    $kamchilik = @()
    if ([string]::IsNullOrWhiteSpace($q.full_name)) { $kamchilik += "full_name" }
    if ([string]::IsNullOrWhiteSpace($q.email))     { $kamchilik += "email" }
    if ([string]::IsNullOrWhiteSpace($q.password))  { $kamchilik += "password" }

    if ($kamchilik.Count -gt 0) {
        Write-Host "  OTKAZILDI: $($q.full_name) - $($kamchilik -join ', ')" -ForegroundColor Yellow
        $otkazildi++
        continue
    }

    # So'rov tanasi. Bosh maydonlar yuborilmaydi - backend ularni
    # nullable deb biladi, lekin bosh satr validatsiyaga tushishi
    # mumkin.
    # To'qnashuvni tekshiramiz
    $email = $q.email.Trim().ToLower()
    if ($mavjudEmail.ContainsKey($email)) {
        $asos = $email -replace '@ku\.uz$', ''
        $n = 1
        do {
            $n++
            $email = "$asos$n@ku.uz"
        } while ($mavjudEmail.ContainsKey($email) -and $n -lt 50)
    }
    $mavjudEmail[$email] = $true

    $tana = @{
        full_name = $q.full_name.Trim()
        email     = $email
        password  = $q.password.Trim()
        role      = if ($q.role) { $q.role.Trim() } else { "talaba" }
        hostel    = if ($q.hostel) { $q.hostel.Trim() } else { "boys" }
    }

    if ($q.phone)       { $tana.phone       = $q.phone.Trim() }
    if ($q.faculty)     { $tana.faculty     = $q.faculty.Trim() }
    if ($q.group_name)  { $tana.group_name  = $q.group_name.Trim() }
    if ($q.passport_id) { $tana.passport_id = $q.passport_id.Trim() }
    if ($q.birth_date)  { $tana.birth_date  = $q.birth_date.Trim() }
    if ($q.region)      { $tana.region      = $q.region.Trim() }
    if ($q.district)    { $tana.district    = $q.district.Trim() }

    if ($q.course) {
        $raqam = ($q.course -replace '[^0-9]', '')
        if ($raqam) { $tana.course = [int]$raqam }
    }

    if ($SinovRejimi) {
        Write-Host "  [sinov] $($tana.full_name) | $($tana.email)" -ForegroundColor DarkGray
        $muvaffaqiyat++
        continue
    }

    try {
        Invoke-RestMethod -Uri "$ApiManzil/students" -Method Post `
            -Headers $Sarlavhalar -ContentType "application/json; charset=utf-8" `
            -Body ([System.Text.Encoding]::UTF8.GetBytes(($tana | ConvertTo-Json))) | Out-Null

        # Darhol belgilaymiz - uzilsa shu yerdan davom etadi.
        Add-Content -Path $BelgiYol -Value $q.email -Encoding UTF8

        $muvaffaqiyat++
        Write-Host "  OK  $muvaffaqiyat/$($qatorlar.Count)  $($tana.full_name)" -ForegroundColor Green

        # Backend'ni bosmaslik uchun kichik tanaffus
        Start-Sleep -Milliseconds 150

    } catch {
        $kod = $_.Exception.Response.StatusCode.value__
        $xabar = $_.ErrorDetails.Message

        # 422 "email taken" - allaqachon kiritilgan, belgilaymiz
        if ($kod -eq 422 -and $xabar -match 'email') {
            Add-Content -Path $BelgiYol -Value $q.email -Encoding UTF8
            Write-Host "  MAVJUD: $($tana.full_name)" -ForegroundColor DarkGray
            $otkazildi++
            continue
        }

        Write-Host "  XATO ($kod): $($tana.full_name)" -ForegroundColor Red
        if ($xabar) { Write-Host "         $xabar" -ForegroundColor DarkRed }
        $xato++
        $xatolar += "$($tana.full_name) | $($tana.email) | [$kod] $xabar"
    }
}

# --- Yakun -----------------------------------------------------------

$davomiyligi = (Get-Date) - $boshlandi

Write-Host ""
Write-Host "=== YAKUN ===" -ForegroundColor Cyan
Write-Host "Muvaffaqiyatli: $muvaffaqiyat" -ForegroundColor Green
Write-Host "Otkazildi:      $otkazildi" -ForegroundColor DarkGray
Write-Host "Xato:           $xato" -ForegroundColor $(if ($xato -gt 0) { "Red" } else { "Gray" })
Write-Host "Vaqt:           $([math]::Round($davomiyligi.TotalMinutes,1)) daqiqa"

if ($xatolar.Count -gt 0) {
    $xatolar | Out-File "D:\qizlar23_xatolari.txt" -Encoding UTF8
    Write-Host ""
    Write-Host "Xatolar D:\qizlar23_xatolari.txt ga yozildi." -ForegroundColor Yellow
}

if ($SinovRejimi) {
    Write-Host ""
    Write-Host "Bu SINOV edi. Haqiqiy kiritish uchun skript ichida:" -ForegroundColor Yellow
    Write-Host '  $SinovRejimi = $false'
    Write-Host '  $Limit = 0'
} else {
    Write-Host ""
    Write-Host "Tekshirish:" -ForegroundColor Cyan
    Write-Host '  $s = Invoke-RestMethod -Uri "' + $ApiManzil + '/students?role=talaba&hostel=girls&per_page=1" -Headers $Sarlavhalar'
    Write-Host '  "Jami: $($s.meta.total)"'
}
