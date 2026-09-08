# =====================================================================
# murojaatlar_list.dart — Firestore'dan Laravel API'ga o'tkazish.
#
# Ishlatilishi (loyiha ildizidan):
#   cd D:\yotoqxona_fixed_full
#   powershell -ExecutionPolicy Bypass -File tuzat_murojaat.ps1
#
# Nima o'zgaradi:
#   - FirebaseFirestore so'rovi olib tashlanadi
#   - StreamBuilder o'rniga FutureBuilder + ApiService().getComplaints()
#   - Talabani backend o'zi filtrlaydi (student_id bo'yicha)
#   - Admin/mudir uchun target_role filtri backend'ga uzatiladi
# =====================================================================

$ErrorActionPreference = "Stop"
$f = "lib\modules\murojaat\murojaatlar_list.dart"

if (-not (Test-Path $f)) {
    Write-Host "XATO: $f topilmadi. Loyiha ildizida turganingizni tekshiring." -ForegroundColor Red
    exit 1
}

$bak = "$f.pre_api.bak"
Copy-Item $f $bak -Force
Write-Host "Zaxira olindi: $bak" -ForegroundColor DarkGray

$lines = [System.Collections.Generic.List[string]](Get-Content $f)
$ozgarish = 0

# --- 1. ApiService importini qo'shish --------------------------------
$bor = $lines.FindIndex({ param($x) $x -match "services/api_service\.dart" })
if ($bor -lt 0) {
    $oxirgiImport = -1
    for ($j = 0; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match "^import ") { $oxirgiImport = $j }
    }
    if ($oxirgiImport -ge 0) {
        $lines.Insert($oxirgiImport + 1, "import '../services/api_service.dart';")
        Write-Host "1. ApiService importi qo'shildi" -ForegroundColor Green
        $ozgarish++
    }
} else {
    Write-Host "1. ApiService importi allaqachon bor" -ForegroundColor DarkGray
}

# --- 2. Firestore so'rovini olib tashlash ----------------------------
# build() ichidagi "Query query = FirebaseFirestore..." blokini
# oddiy o'zgaruvchiga almashtiramiz.
$qStart = $lines.FindIndex({ param($x) $x -match '^\s*Query query = FirebaseFirestore\.instance' })
if ($qStart -ge 0) {
    # Blok "query = query.where(...targetRole...);" bilan tugaydigan
    # if/else zanjirigacha davom etadi. Yopuvchi "}" qatorini qidiramiz.
    $qEnd = -1
    for ($j = $qStart; $j -lt [Math]::Min($qStart + 25, $lines.Count); $j++) {
        if ($lines[$j] -match "targetRole") {
            # shundan keyingi birinchi "    }" qatori blok oxiri
            for ($k = $j; $k -lt $lines.Count; $k++) {
                if ($lines[$k] -match '^\s*\}\s*$') { $qEnd = $k; break }
            }
            break
        }
    }

    if ($qEnd -gt $qStart) {
        $yangi = @(
            "    // Filtrlash endi backend tomonida bajariladi:"
            "    //   - talaba faqat o'z murojaatlarini oladi (student_id)"
            "    //   - mudir o'z binosidagilarni oladi (hostel)"
            "    // Bu yerda faqat target_role filtri uzatiladi."
            "    final String? targetRoleFilter ="
            "        widget.isAdmin ? widget.roleFilter?.value : null;"
        )
        $lines.RemoveRange($qStart, $qEnd - $qStart + 1)
        $lines.InsertRange($qStart, [string[]]$yangi)
        Write-Host "2. Firestore so'rovi olib tashlandi" -ForegroundColor Green
        $ozgarish++
    } else {
        Write-Host "2. So'rov bloki oxiri aniqlanmadi - qo'lda tuzating" -ForegroundColor Red
    }
} else {
    Write-Host "2. Firestore so'rovi topilmadi (allaqachon ko'chirilganmi?)" -ForegroundColor Yellow
}

# --- 3. StreamBuilder -> FutureBuilder -------------------------------
$sb = $lines.FindIndex({ param($x) $x -match 'StreamBuilder<QuerySnapshot>\(' })
if ($sb -ge 0) {
    $lines[$sb] = $lines[$sb].Replace("StreamBuilder<QuerySnapshot>(", "FutureBuilder<List<dynamic>>(")
    Write-Host "3. StreamBuilder -> FutureBuilder" -ForegroundColor Green
    $ozgarish++
} else {
    Write-Host "3. StreamBuilder topilmadi" -ForegroundColor Yellow
}

# --- 4. stream: -> future: -------------------------------------------
$st = $lines.FindIndex({ param($x) $x -match "stream: query\.orderBy" })
if ($st -ge 0) {
    $lines[$st] = "              future: ApiService().getComplaints("
    $lines.Insert($st + 1, "                targetRole: targetRoleFilter,")
    $lines.Insert($st + 2, "              ),")
    Write-Host "4. stream: -> future: ApiService().getComplaints()" -ForegroundColor Green
    $ozgarish++
} else {
    Write-Host "4. stream: qatori topilmadi" -ForegroundColor Yellow
}

# --- 5. snapshot.data!.docs -> snapshot.data ------------------------
$i = $lines.FindIndex({ param($x) $x -match 'var complaints = snapshot\.data!\.docs;' })
if ($i -ge 0) {
    $lines[$i] = "                var complaints = snapshot.data ?? const <dynamic>[];"
    Write-Host "5. snapshot.data!.docs -> snapshot.data" -ForegroundColor Green
    $ozgarish++
} else {
    Write-Host "5. complaints o'zgaruvchisi topilmadi" -ForegroundColor Yellow
}

# --- 6. Mahalliy qidiruv filtri --------------------------------------
$i = $lines.FindIndex({ param($x) $x -match 'final data = doc\.data\(\) as Map<String, dynamic>;' })
if ($i -ge 0) {
    $lines[$i] = "                    final data = Map<String, dynamic>.from(doc as Map);"
    # keyingi qatorlarda studentName o'qish - student obyektini ham tekshiramiz
    $j = $lines.FindIndex($i, { param($x) $x -match "\(data\['studentName'\] \?\? ''\)" })
    if ($j -ge 0) {
        $lines[$j] = "                        (data['student'] is Map"
        $lines.Insert($j + 1, "                                ? (data['student']['full_name'] ?? '')")
        $lines.Insert($j + 2, "                                : (data['studentName'] ?? ''))")
    }
    Write-Host "6. Qidiruv filtri yangilandi" -ForegroundColor Green
    $ozgarish++
} else {
    Write-Host "6. Qidiruv filtri topilmadi" -ForegroundColor Yellow
}

# --- 7. ListView.builder ichidagi model yaratish ---------------------
$i = $lines.FindIndex({ param($x) $x -match 'var complaint = ComplaintModel\.fromJson\(' })
if ($i -ge 0) {
    # Uch qatorli ifodani bitta qator bilan almashtiramiz.
    $end = $i
    for ($k = $i; $k -lt [Math]::Min($i + 5, $lines.Count); $k++) {
        if ($lines[$k] -match '\.copyWith\(id: complaints\[index\]\.id\);') { $end = $k; break }
    }
    $yangi = @(
        "                    final complaint = ComplaintModel.fromJson("
        "                      Map<String, dynamic>.from(complaints[index] as Map),"
        "                    );"
    )
    $lines.RemoveRange($i, $end - $i + 1)
    $lines.InsertRange($i, [string[]]$yangi)
    Write-Host "7. ComplaintModel yaratish yangilandi" -ForegroundColor Green
    $ozgarish++
} else {
    Write-Host "7. ComplaintModel.fromJson topilmadi" -ForegroundColor Yellow
}

# --- 8. cloud_firestore importi endi keraksiz ------------------------
$i = $lines.FindIndex({ param($x) $x -match "^import 'package:cloud_firestore/cloud_firestore\.dart';" })
if ($i -ge 0) {
    # Faylda boshqa Firestore ishlatilishi qolganmi?
    $qolgan = $false
    for ($j = 0; $j -lt $lines.Count; $j++) {
        if ($j -ne $i -and $lines[$j] -match 'FirebaseFirestore|QuerySnapshot|DocumentSnapshot|Timestamp') {
            $qolgan = $true; break
        }
    }
    if (-not $qolgan) {
        $lines.RemoveAt($i)
        Write-Host "8. cloud_firestore importi olib tashlandi" -ForegroundColor Green
        $ozgarish++
    } else {
        Write-Host "8. cloud_firestore hali ishlatilyapti - import qoldirildi" -ForegroundColor DarkGray
    }
}

# --- Saqlash ---------------------------------------------------------
if ($ozgarish -gt 0) {
    Set-Content -Path $f -Value $lines -Encoding UTF8
    Write-Host ""
    Write-Host "Tayyor. $ozgarish ta o'zgarish saqlandi." -ForegroundColor Cyan
    Write-Host "Qaytarish:  Move-Item '$bak' '$f' -Force" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "MUHIM: ApiService.getComplaints() ga targetRole parametri" -ForegroundColor Yellow
    Write-Host "kerak. tuzat_apiservice.ps1 skriptini ham ishga tushiring." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Keyin tekshiring:" -ForegroundColor Cyan
    Write-Host "  flutter analyze --no-pub $f"
} else {
    Write-Host ""
    Write-Host "Hech narsa o'zgarmadi." -ForegroundColor Yellow
}
