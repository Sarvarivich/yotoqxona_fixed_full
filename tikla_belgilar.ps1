# =====================================================================
# BUZUQ BELGILARNI TIKLASH
#
# SABAB
# -----
# Fayllar bir necha marta notogri kodlashda qayta yozilgan:
# UTF-8 baytlari CP1251 sifatida oqilgan. Bu BIR NECHA MARTA
# takrorlangan, shuning uchun belgilar ikki-uch qavat buzilgan:
#
#   apostrof -> bir qavat buzilgan -> ikki qavat buzilgan -> ...
#
# YECHIM
# ------
# Jadval bilan emas, TESKARI OGIRISH bilan tiklaymiz:
#   matn -> CP1251 baytlari -> UTF-8 sifatida oqish
#
# Bu bitta qavatni yechadi. Kirill belgisi qolsa, yana takrorlanadi
# (eng kopi 4 marta).
#
# NEGA ISHONCHLI
# --------------
# Loyihada qonuniy kirill matn yoq - hammasi ozbek lotin. Shuning
# uchun har qanday kirill ketma-ketligi buzilgan belgi hisoblanadi.
#
# Tiklash muvaffaqiyatsiz bolsa (natijada "?" yoki yana kirill
# qolsa), qator TEGILMAY qoladi.
#
# Ishlatilishi (loyiha ildizidan):
#
#   Avval korish:
#     powershell -ExecutionPolicy Bypass -File tikla_belgilar.ps1
#
#   Keyin qollash:
#     powershell -ExecutionPolicy Bypass -File tikla_belgilar.ps1 -Qolla
# =====================================================================

param(
    [switch]$Qolla
)

$ErrorActionPreference = "Stop"

$cp1251 = [System.Text.Encoding]::GetEncoding(1251)
$utf8   = [System.Text.Encoding]::UTF8

# Buzuq ketma-ketlik: kirill va unga qoshni maxsus belgilar.
# Kamida bitta kirill harfi bolishi shart.
$naqsh = '[\u0400-\u04FF\u2010-\u203F\u2100-\u21FF\u00A0-\u00BF\u02C0-\u02DF]*[\u0400-\u04FF][\u0400-\u04FF\u2010-\u203F\u2100-\u21FF\u00A0-\u00BF\u02C0-\u02DF]*'

# --- Bitta buzuq boragni tiklaydi -----------------------------------
function Tikla([string]$xom) {
    $joriy = $xom

    for ($qavat = 1; $qavat -le 4; $qavat++) {
        # Kirill qolmagan bolsa - tayyor
        if ($joriy -notmatch '[\u0400-\u04FF]') { break }

        try {
            $baytlar = $cp1251.GetBytes($joriy)
            $yangi = $utf8.GetString($baytlar)
        } catch {
            return $null
        }

        # Ogirish buzilgan bolsa (almashtirish belgisi paydo bolsa)
        if ($yangi.Contains([char]0xFFFD)) { return $null }

        # CP1251 da mavjud bolmagan belgi "?" ga aylanadi.
        # Kirishda "?" yoq edi-yu chiqishda paydo bolsa - yoqotish.
        $savolKirish = ($joriy.ToCharArray() | Where-Object { $_ -eq '?' }).Count
        $savolChiqish = ($yangi.ToCharArray() | Where-Object { $_ -eq '?' }).Count
        if ($savolChiqish -gt $savolKirish) { return $null }

        # Ozgarmasa - boshi berk
        if ($yangi -eq $joriy) { return $null }

        $joriy = $yangi
    }

    # Hali kirill qolgan bolsa - tiklab bolmadi
    if ($joriy -match '[\u0400-\u04FF]') { return $null }

    # Natija bosh yoki juda qisqargan bolsa - shubhali
    if ($joriy.Length -eq 0) { return $null }

    return $joriy
}

# ---------------------------------------------------------------------

$fayllar = Get-ChildItem lib -Recurse -Filter "*.dart"

$ozgargan = 0
$jamiTiklandi = 0
$tiklanmadi = @()
$namunalar = @()

Write-Host ""
if ($Qolla) {
    Write-Host "QOLLASH REJIMI - fayllar ozgartiriladi" -ForegroundColor Yellow
} else {
    Write-Host "KORISH REJIMI - hech narsa ozgarmaydi" -ForegroundColor Cyan
}
Write-Host ""

foreach ($fayl in $fayllar) {
    $yol = $fayl.FullName
    $m = [System.IO.File]::ReadAllText($yol, $utf8)
    $asl = $m
    $soni = 0
    $nom = $yol.Replace("$PWD\lib\", "")

    $mosliklar = [regex]::Matches($m, $naqsh)
    if ($mosliklar.Count -eq 0) { continue }

    # Orqadan oldinga - indekslar buzilmasin
    for ($i = $mosliklar.Count - 1; $i -ge 0; $i--) {
        $mos = $mosliklar[$i]
        $xom = $mos.Value

        $tikPos = Tikla $xom

        if ($tikPos -ne $null) {
            $m = $m.Remove($mos.Index, $mos.Length).Insert($mos.Index, $tikPos)
            $soni++

            if ($namunalar.Count -lt 12) {
                $namunalar += [PSCustomObject]@{
                    Fayl = $nom
                    Yangi = $tikPos
                }
            }
        } else {
            $tiklanmadi += [PSCustomObject]@{ Fayl = $nom; Xom = $xom }
        }
    }

    if ($m -ne $asl) {
        if ($Qolla) {
            if (-not (Test-Path "$yol.pre_tikla.bak")) {
                Copy-Item $yol "$yol.pre_tikla.bak" -Force
            }
            [System.IO.File]::WriteAllText(
                $yol, $m, (New-Object System.Text.UTF8Encoding $false)
            )
        }

        $qoldi = ([regex]::Matches($m, '[\u0400-\u04FF]')).Count
        Write-Host ("  {0,-50} {1,4} ta tiklandi, {2} qoldi" -f $nom, $soni, $qoldi) -ForegroundColor Green

        $ozgargan++
        $jamiTiklandi += $soni
    }
}

Write-Host ""
Write-Host "$ozgargan ta faylda $jamiTiklandi ta belgi tiklanadi." -ForegroundColor Cyan

# --- Namunalar -------------------------------------------------------

if ($namunalar.Count -gt 0) {
    Write-Host ""
    Write-Host "NAMUNALAR (tiklangan koronishi):" -ForegroundColor Cyan
    foreach ($n in $namunalar) {
        $y = $n.Yangi
        if ($y.Length -gt 50) { $y = $y.Substring(0, 50) + "..." }
        Write-Host ("  {0,-42} -> [{1}]" -f $n.Fayl, $y) -ForegroundColor DarkGray
    }
}

# --- Tiklanmaganlar --------------------------------------------------

if ($tiklanmadi.Count -gt 0) {
    Write-Host ""
    Write-Host "TIKLAB BOLMADI: $($tiklanmadi.Count) ta (tegilmadi)" -ForegroundColor Yellow
    $tiklanmadi | Export-Csv "D:\tiklanmagan_belgilar.csv" -NoTypeInformation -Encoding UTF8
    Write-Host "Royxat: D:\tiklanmagan_belgilar.csv" -ForegroundColor DarkGray
}

Write-Host ""
if (-not $Qolla) {
    Write-Host "Qollash uchun:" -ForegroundColor Cyan
    Write-Host "  powershell -ExecutionPolicy Bypass -File tikla_belgilar.ps1 -Qolla"
} else {
    Write-Host "Tekshirish:" -ForegroundColor Cyan
    Write-Host "  flutter analyze --no-pub lib | Select-String '^\s*error'"
    Write-Host ""
    Write-Host "Qaytarish:" -ForegroundColor DarkGray
    Write-Host "  Get-ChildItem lib -Recurse -Filter '*.pre_tikla.bak' | ForEach-Object {"
    Write-Host "    Move-Item `$_.FullName (`$_.FullName -replace '\.pre_tikla\.bak`$','') -Force"
    Write-Host "  }"
}
