# =====================================================================
# 1) ApiService.getComplaints() ga targetRole parametrini qo'shish
# 2) Backend ComplaintController::index() ga mudir/hostel va
#    target_role filtrlarini qo'shish
#
# Ishlatilishi (loyiha ildizidan):
#   cd D:\yotoqxona_fixed_full
#   powershell -ExecutionPolicy Bypass -File tuzat_apiservice.ps1
# =====================================================================

$ErrorActionPreference = "Stop"

# =====================================================================
# QISM 1 — Flutter: ApiService.getComplaints()
# =====================================================================

$f = "lib\modules\services\api_service.dart"

if (-not (Test-Path $f)) {
    Write-Host "XATO: $f topilmadi." -ForegroundColor Red
    exit 1
}

$bak = "$f.pre_target.bak"
Copy-Item $f $bak -Force
Write-Host "Zaxira: $bak" -ForegroundColor DarkGray

$lines = [System.Collections.Generic.List[string]](Get-Content $f)
$ozgarish = 0

# targetRole parametrini imzoga qo'shamiz
$i = $lines.FindIndex({ param($x) $x -match '^\s*Future<List<dynamic>> getComplaints\(\{' })
if ($i -ge 0) {
    if ($lines[$i + 1] -notmatch 'targetRole') {
        $lines.Insert($i + 1, "    String? targetRole,")
        Write-Host "1. targetRole parametri qo'shildi" -ForegroundColor Green
        $ozgarish++
    } else {
        Write-Host "1. targetRole allaqachon bor" -ForegroundColor DarkGray
    }

    # So'rov parametrlariga qo'shamiz — category blokidan keyin
    $j = $lines.FindIndex($i, { param($x) $x -match "parameters\['category'\] = category;" })
    if ($j -ge 0) {
        # yopuvchi } dan keyin
        if ($lines[$j + 2] -notmatch 'target_role') {
            $qoshimcha = @(
                ""
                "    if (targetRole != null && targetRole.isNotEmpty) {"
                "      parameters['target_role'] = targetRole;"
                "    }"
            )
            $lines.InsertRange($j + 2, [string[]]$qoshimcha)
            Write-Host "2. target_role so'rov parametri qo'shildi" -ForegroundColor Green
            $ozgarish++
        } else {
            Write-Host "2. target_role parametri allaqachon bor" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "2. category bloki topilmadi" -ForegroundColor Yellow
    }
} else {
    Write-Host "1. getComplaints metodi topilmadi" -ForegroundColor Red
}

if ($ozgarish -gt 0) {
    Set-Content -Path $f -Value $lines -Encoding UTF8
    Write-Host "   ApiService yangilandi." -ForegroundColor Cyan
}

# =====================================================================
# QISM 2 — Backend: ComplaintController::index()
# =====================================================================

Write-Host ""
$c = "backend_repo\app\Http\Controllers\Api\ComplaintController.php"

if (-not (Test-Path $c)) {
    Write-Host "XATO: $c topilmadi." -ForegroundColor Red
    exit 1
}

$cbak = "$c.pre_filter.bak"
Copy-Item $c $cbak -Force
Write-Host "Zaxira: $cbak" -ForegroundColor DarkGray

$clines = [System.Collections.Generic.List[string]](Get-Content $c)
$cozgarish = 0

# Talaba filtridan keyin mudir va target_role filtrlarini qo'shamiz
$i = $clines.FindIndex({ param($x) $x -match "\`$query->where\('student_id', \`$user->id\);" })
if ($i -ge 0) {
    # Yopuvchi } qatorini topamiz
    $close = -1
    for ($j = $i; $j -lt [Math]::Min($i + 4, $clines.Count); $j++) {
        if ($clines[$j] -match '^\s*\}\s*$') { $close = $j; break }
    }

    if ($close -ge 0) {
        # Allaqachon qo'shilganmi?
        $bor = $false
        for ($j = 0; $j -lt $clines.Count; $j++) {
            if ($clines[$j] -match "role === 'mudir'") { $bor = $true; break }
        }

        if (-not $bor) {
            $php = @(
                ""
                "        // Mudir faqat o'z binosidagi talabalarning murojaatlarini"
                "        // ko'radi. Admin va superAdmin uchun cheklov yo'q."
                "        if (`$user->role === 'mudir' && !empty(`$user->hostel)) {"
                "            `$query->whereHas('student', function (`$q) use (`$user) {"
                "                `$q->where('hostel', `$user->hostel);"
                "            });"
                "        }"
                ""
                "        // Kimga yo'naltirilgani bo'yicha filtr (mudir / admin / moliyachi)."
                "        if (`$request->filled('target_role')) {"
                "            `$query->where('target_role', `$request->target_role);"
                "        }"
            )
            $clines.InsertRange($close + 1, [string[]]$php)
            Write-Host "3. ComplaintController'ga mudir va target_role filtrlari qo'shildi" -ForegroundColor Green
            $cozgarish++
        } else {
            Write-Host "3. Filtrlar allaqachon qo'shilgan" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "3. Talaba filtri blokining oxiri aniqlanmadi" -ForegroundColor Red
    }
} else {
    Write-Host "3. Talaba filtri topilmadi" -ForegroundColor Yellow
}

if ($cozgarish -gt 0) {
    Set-Content -Path $c -Value $clines -Encoding UTF8
    Write-Host "   ComplaintController yangilandi." -ForegroundColor Cyan
}

# =====================================================================
Write-Host ""
Write-Host "Tekshirish:" -ForegroundColor Cyan
Write-Host "  php -l $c"
Write-Host "  flutter analyze --no-pub $f"
Write-Host ""
Write-Host "Qaytarish:" -ForegroundColor DarkGray
Write-Host "  Move-Item '$bak' '$f' -Force"
Write-Host "  Move-Item '$cbak' '$c' -Force"
