# =====================================================================
# talaba_profile_screen.dart — profil yuklashni Firestore'dan
# Laravel API'ga o'tkazish.
#
# Ishlatilishi (loyiha ildizidan):
#   cd D:\yotoqxona_fixed_full
#   powershell -ExecutionPolicy Bypass -File tuzat_profil.ps1
#
# Skript hech narsani ko'r-ko'rona o'zgartirmaydi: har bir qadamda
# kutilgan matn topilmasa, ogohlantirish beradi va davom etadi.
# Zaxira nusxa avtomatik olinadi.
# =====================================================================

$ErrorActionPreference = "Stop"
$f = "lib\roles\talaba_profile_screen.dart"

if (-not (Test-Path $f)) {
    Write-Host "XATO: $f topilmadi. Loyiha ildizida turganingizni tekshiring." -ForegroundColor Red
    exit 1
}

# --- Zaxira ----------------------------------------------------------
$bak = "$f.pre_api.bak"
Copy-Item $f $bak -Force
Write-Host "Zaxira olindi: $bak" -ForegroundColor DarkGray

$lines = [System.Collections.Generic.List[string]](Get-Content $f)
$ozgarish = 0

# --- 1. _userSubscription maydonini o'chirish ------------------------
$i = $lines.FindIndex({ param($x) $x -match '^\s*StreamSubscription<.*>\?\s+_userSubscription;' })
if ($i -ge 0) {
    $lines.RemoveAt($i)
    Write-Host "1. _userSubscription maydoni o'chirildi" -ForegroundColor Green
    $ozgarish++
} else {
    Write-Host "1. _userSubscription maydoni topilmadi (allaqachon o'chirilganmi?)" -ForegroundColor Yellow
}

# --- 2. initState dagi chaqiruvni almashtirish -----------------------
$i = $lines.FindIndex({ param($x) $x -match '^\s*_listenToStudentProfile\(\);\s*$' })
if ($i -ge 0) {
    $lines[$i] = $lines[$i].Replace("_listenToStudentProfile();", "_loadStudentProfile();")
    Write-Host "2. initState chaqiruvi yangilandi" -ForegroundColor Green
    $ozgarish++
} else {
    Write-Host "2. initState chaqiruvi topilmadi" -ForegroundColor Yellow
}

# --- 3. Metodning o'zini almashtirish --------------------------------
# Boshlanish qatorini topamiz, keyin qavslarni sanab oxirini aniqlaymiz.
$start = $lines.FindIndex({ param($x) $x -match '^\s*void _listenToStudentProfile\(\)\s*\{' })
if ($start -ge 0) {
    $depth = 0
    $end = -1
    for ($j = $start; $j -lt $lines.Count; $j++) {
        $ochiq = ([regex]::Matches($lines[$j], '\{')).Count
        $yopiq = ([regex]::Matches($lines[$j], '\}')).Count
        $depth += $ochiq - $yopiq
        if ($depth -eq 0 -and $j -gt $start) { $end = $j; break }
        if ($depth -eq 0 -and $j -eq $start -and $ochiq -gt 0) { $end = $j; break }
    }

    if ($end -ge $start) {
        $yangi = @(
            "  // Profil ma'lumotini Laravel backend'dan yuklaydi."
            "  // Ilgari Firestore snapshots() orqali real vaqtda kuzatilardi;"
            "  // endi ekran ochilganda bir marta yuklanadi."
            "  Future<void> _loadStudentProfile() async {"
            "    try {"
            "      final response = await ApiService().getMe();"
            ""
            "      // Backend javobi {success, data: {...}} yoki {success, user: {...}}"
            "      // ko'rinishida kelishi mumkin - ikkalasini ham qo'llab-quvvatlaymiz."
            "      final raw = response['data'] ?? response['user'];"
            "      if (raw == null || !mounted) return;"
            ""
            "      final updated ="
            "          UserModel.fromJson(Map<String, dynamic>.from(raw as Map));"
            ""
            "      if (_tab == 2 && !updated.hasRoom) {"
            "        _tab = 0;"
            "      }"
            "      setState(() => _user = updated);"
            "    } catch (e) {"
            "      // Xato bo'lsa login paytida olingan ma'lumot bilan davom etamiz."
            "      debugPrint('Profilni yuklashda xatolik: `$e');"
            "    }"
            "  }"
        )

        $lines.RemoveRange($start, $end - $start + 1)
        $lines.InsertRange($start, [string[]]$yangi)
        Write-Host "3. _listenToStudentProfile -> _loadStudentProfile almashtirildi" -ForegroundColor Green
        $ozgarish++
    } else {
        Write-Host "3. Metod oxiri aniqlanmadi - qo'lda tuzating" -ForegroundColor Red
    }
} else {
    Write-Host "3. _listenToStudentProfile metodi topilmadi" -ForegroundColor Yellow
}

# --- 4. dispose ichidagi cancel() ni o'chirish -----------------------
$i = $lines.FindIndex({ param($x) $x -match '^\s*_userSubscription\?\.cancel\(\);\s*$' })
while ($i -ge 0) {
    $lines.RemoveAt($i)
    $ozgarish++
    $i = $lines.FindIndex({ param($x) $x -match '^\s*_userSubscription\?\.cancel\(\);\s*$' })
}
Write-Host "4. _userSubscription?.cancel() chaqiruvlari tozalandi" -ForegroundColor Green

# --- 5. ApiService importini qo'shish --------------------------------
$bor = $lines.FindIndex({ param($x) $x -match "services/api_service\.dart" })
if ($bor -lt 0) {
    # Oxirgi import qatoridan keyin qo'yamiz.
    $oxirgiImport = -1
    for ($j = 0; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match "^import ") { $oxirgiImport = $j }
    }
    if ($oxirgiImport -ge 0) {
        $lines.Insert($oxirgiImport + 1, "import '../modules/services/api_service.dart';")
        Write-Host "5. ApiService importi qo'shildi" -ForegroundColor Green
        $ozgarish++
    } else {
        Write-Host "5. Import bo'limi topilmadi" -ForegroundColor Red
    }
} else {
    Write-Host "5. ApiService importi allaqachon bor" -ForegroundColor DarkGray
}

# --- Saqlash ---------------------------------------------------------
if ($ozgarish -gt 0) {
    Set-Content -Path $f -Value $lines -Encoding UTF8
    Write-Host ""
    Write-Host "Tayyor. $ozgarish ta o'zgarish saqlandi." -ForegroundColor Cyan
    Write-Host "Qaytarish kerak bo'lsa:  Move-Item '$bak' '$f' -Force" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Endi tekshiring:" -ForegroundColor Cyan
    Write-Host "  flutter analyze --no-pub $f"
} else {
    Write-Host ""
    Write-Host "Hech narsa o'zgarmadi." -ForegroundColor Yellow
}
