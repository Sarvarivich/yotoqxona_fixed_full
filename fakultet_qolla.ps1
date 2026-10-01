# =====================================================================
# FAKULTETLARNI RO'YXAT BO'YICHA MOSLASHTIRISH
#
# fakultet_royxat.csv dagi har bir email uchun fakultet o'rnatiladi.
# Ro'yxatda bo'lmaganlar va fakulteti bo'sh berilganlar TEGILMAYDI.
#
# Ishlatilishi:
#   Avval ko'rish:
#     powershell -ExecutionPolicy Bypass -File fakultet_qolla.ps1
#   Keyin qo'llash:
#     powershell -ExecutionPolicy Bypass -File fakultet_qolla.ps1 -Qolla
# =====================================================================

param(
    [switch]$Qolla
)

$ErrorActionPreference = "Stop"

$api    = "https://kuhostel.up.railway.app/api"
$CsvYol = "D:\fakultet_royxat.csv"

if (-not (Test-Path $CsvYol)) {
    Write-Host "XATO: $CsvYol topilmadi." -ForegroundColor Red
    exit 1
}

$royxat = Import-Csv $CsvYol -Encoding UTF8
Write-Host "Ro'yxatda: $($royxat.Count) ta" -ForegroundColor Cyan

# --- Login ---
$r = Invoke-RestMethod -Uri "$api/login" -Method Post -ContentType "application/json" `
    -Body '{"email":"superadmin@kuhostel.uz","password":"Super12345"}'
$H = @{ Authorization = "Bearer $($r.token)" }

# --- Barcha foydalanuvchilar: email -> yozuv ---
Write-Host "Foydalanuvchilar yuklanmoqda..." -ForegroundColor Cyan
$baza = @{}
$sahifa = 1; $oxirgi = 1
do {
    $s = Invoke-RestMethod -Headers $H -Uri "$api/students?per_page=100&page=$sahifa"
    foreach ($u in $s.data) {
        if ($u.email) { $baza[$u.email.ToLower()] = $u }
    }
    if ($s.meta.last_page) { $oxirgi = $s.meta.last_page }
    $sahifa++
} while ($sahifa -le $oxirgi -and $sahifa -le 30)
Write-Host "Bazada: $($baza.Count) ta" -ForegroundColor Green
Write-Host ""

# --- Solishtirish ---
$ozgaradi = @(); $togri = 0; $topilmadi = @()
foreach ($q in $royxat) {
    $email = $q.email.Trim().ToLower()
    $yangi = $q.faculty.Trim()
    if (-not $baza.ContainsKey($email)) { $topilmadi += $email; continue }
    $u = $baza[$email]
    if ([string]$u.faculty -eq $yangi) { $togri++; continue }
    $ozgaradi += [PSCustomObject]@{
        Id = $u.id; Email = $email; Eski = [string]$u.faculty; Yangi = $yangi
    }
}

Write-Host "Allaqachon to'g'ri:  $togri ta" -ForegroundColor DarkGray
Write-Host "O'zgaradi:           $($ozgaradi.Count) ta" -ForegroundColor Cyan
Write-Host "Bazada topilmadi:    $($topilmadi.Count) ta" -ForegroundColor Yellow
Write-Host ""

if ($ozgaradi.Count -gt 0) {
    Write-Host "O'ZGARISHLAR (eski -> yangi):" -ForegroundColor Cyan
    $ozgaradi | Group-Object { "$($_.Eski)  ->  $($_.Yangi)" } |
        Select-Object Count, Name | Sort-Object Count -Descending | Format-Table -AutoSize
}

if ($topilmadi.Count -gt 0) {
    Write-Host "TOPILMAGAN EMAILLAR:" -ForegroundColor Yellow
    $topilmadi | ForEach-Object { "  $_" }
    Write-Host ""
}

if (-not $Qolla) {
    Write-Host "Bu faqat KO'RISH edi. Qo'llash uchun:" -ForegroundColor Yellow
    Write-Host "  powershell -ExecutionPolicy Bypass -File fakultet_qolla.ps1 -Qolla"
    exit 0
}

# --- Qo'llash ---
Write-Host "Qo'llanmoqda..." -ForegroundColor Yellow
$ok = 0; $xato = 0
foreach ($o in $ozgaradi) {
    try {
        $body = [System.Text.Encoding]::UTF8.GetBytes((@{ faculty = $o.Yangi } | ConvertTo-Json))
        Invoke-RestMethod -Uri "$api/students/$($o.Id)" -Method Put -Headers $H `
            -ContentType "application/json; charset=utf-8" -Body $body | Out-Null
        $ok++
        if ($ok % 25 -eq 0) { Write-Host "  $ok ta..." -ForegroundColor DarkGray }
    } catch {
        $xato++
        Write-Host "  XATO: $($o.Email) - $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}
Write-Host ""
Write-Host "Yangilandi: $ok ta | Xato: $xato ta" -ForegroundColor Green
