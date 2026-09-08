# =====================================================================
# talaba_profile_screen.dart — _NotificationBell widgetini
# Firestore'dan Laravel API'ga o'tkazish.
#
# Ishlatilishi (loyiha ildizidan):
#   cd D:\yotoqxona_fixed_full
#   powershell -ExecutionPolicy Bypass -File tuzat_qongiroq.ps1
#
# StreamBuilder (real vaqt) o'rniga FutureBuilder ishlatiladi:
# o'qilmagan bildirishnomalar soni ekran ochilganda bir marta
# hisoblanadi. Bildirishnomalar ro'yxatidan qaytilganda son
# avtomatik yangilanadi.
# =====================================================================

$ErrorActionPreference = "Stop"
$f = "lib\roles\talaba_profile_screen.dart"

if (-not (Test-Path $f)) {
    Write-Host "XATO: $f topilmadi. Loyiha ildizida turganingizni tekshiring." -ForegroundColor Red
    exit 1
}

$bak = "$f.pre_bell.bak"
Copy-Item $f $bak -Force
Write-Host "Zaxira olindi: $bak" -ForegroundColor DarkGray

$lines = [System.Collections.Generic.List[string]](Get-Content $f)

# --- _NotificationBell klassini topamiz ------------------------------
$start = $lines.FindIndex({ param($x) $x -match '^class _NotificationBell extends StatelessWidget \{' })

if ($start -lt 0) {
    Write-Host "_NotificationBell klassi topilmadi." -ForegroundColor Red
    Write-Host "Ehtimol allaqachon o'zgartirilgan (StatefulWidget bo'lib qolgan)." -ForegroundColor Yellow
    exit 1
}

# Qavslarni sanab klass oxirini aniqlaymiz.
$depth = 0
$end = -1
for ($j = $start; $j -lt $lines.Count; $j++) {
    $ochiq  = ([regex]::Matches($lines[$j], '\{')).Count
    $yopiq  = ([regex]::Matches($lines[$j], '\}')).Count
    $depth += $ochiq - $yopiq
    if ($depth -eq 0 -and $j -gt $start) { $end = $j; break }
}

if ($end -lt 0) {
    Write-Host "Klass oxiri aniqlanmadi - qo'lda tuzating." -ForegroundColor Red
    exit 1
}

Write-Host "Topildi: $($start + 1)-$($end + 1) qatorlar" -ForegroundColor DarkGray

# --- Yangi widget ----------------------------------------------------
# Backtick bilan ekranlangan $ belgilari Dart kodida oddiy $ bo'ladi.
$yangi = @(
    "// Bildirishnoma qo'ng'irog'i - o'qilmagan xabarlar sonini ko'rsatadi."
    "// Ilgari Firestore StreamBuilder orqali real vaqtda sanardi;"
    "// endi Laravel API'dan bir marta yuklanadi va ro'yxatdan"
    "// qaytilganda qayta hisoblanadi."
    "class _NotificationBell extends StatefulWidget {"
    "  final String userId;"
    "  final String hostel;"
    ""
    "  const _NotificationBell({"
    "    required this.userId,"
    "    required this.hostel,"
    "  });"
    ""
    "  @override"
    "  State<_NotificationBell> createState() => _NotificationBellState();"
    "}"
    ""
    "class _NotificationBellState extends State<_NotificationBell> {"
    "  int _unreadCount = 0;"
    ""
    "  @override"
    "  void initState() {"
    "    super.initState();"
    "    _loadUnreadCount();"
    "  }"
    ""
    "  Future<void> _loadUnreadCount() async {"
    "    try {"
    "      final items = await ApiService().getNotifications();"
    "      if (!mounted) return;"
    ""
    "      // Backend 'is_read' maydonini qaytaradi. Eski Firestore"
    "      // ma'lumotlarida 'isRead' bo'lishi mumkin - ikkalasini tekshiramiz."
    "      final count = items.where((n) {"
    "        if (n is! Map) return false;"
    "        final read = n['is_read'] ?? n['isRead'] ?? false;"
    "        return read == false || read == 0;"
    "      }).length;"
    ""
    "      setState(() => _unreadCount = count);"
    "    } catch (e) {"
    "      debugPrint('Bildirishnomalarni yuklashda xatolik: `$e');"
    "    }"
    "  }"
    ""
    "  @override"
    "  Widget build(BuildContext context) {"
    "    return GestureDetector("
    "      onTap: () async {"
    "        await Navigator.push("
    "          context,"
    "          MaterialPageRoute("
    "            builder: (_) => BildirishnomalarList("
    "              userId: widget.userId,"
    "              hostel: widget.hostel,"
    "            ),"
    "          ),"
    "        );"
    "        // Ro'yxatdan qaytgach sonni yangilaymiz."
    "        _loadUnreadCount();"
    "      },"
    "      child: Container("
    "        width: 38,"
    "        height: 38,"
    "        decoration: BoxDecoration("
    "          color: Colors.white.withOpacity(0.06),"
    "          borderRadius: BorderRadius.circular(12),"
    "          border: Border.all(color: Colors.white.withOpacity(0.1)),"
    "        ),"
    "        child: Stack("
    "          clipBehavior: Clip.none,"
    "          alignment: Alignment.center,"
    "          children: ["
    "            const Icon("
    "              Icons.notifications_outlined,"
    "              size: 19,"
    "              color: _C.soft,"
    "            ),"
    "            if (_unreadCount > 0)"
    "              Positioned("
    "                top: 4,"
    "                right: 5,"
    "                child: Container("
    "                  padding: const EdgeInsets.symmetric("
    "                      horizontal: 4, vertical: 1),"
    "                  constraints:"
    "                      const BoxConstraints(minWidth: 15, minHeight: 15),"
    "                  decoration: BoxDecoration("
    "                    color: _C.pink,"
    "                    borderRadius: BorderRadius.circular(8),"
    "                    border: Border.all("
    "                      color: const Color(0xFF1E1B2E),"
    "                      width: 1.5,"
    "                    ),"
    "                  ),"
    "                  child: Text("
    "                    _unreadCount > 9 ? '9+' : '`$_unreadCount',"
    "                    textAlign: TextAlign.center,"
    "                    style: const TextStyle("
    "                      fontSize: 9,"
    "                      fontWeight: FontWeight.w800,"
    "                      color: Colors.white,"
    "                      height: 1.2,"
    "                    ),"
    "                  ),"
    "                ),"
    "              ),"
    "          ],"
    "        ),"
    "      ),"
    "    );"
    "  }"
    "}"
)

$lines.RemoveRange($start, $end - $start + 1)
$lines.InsertRange($start, [string[]]$yangi)

Set-Content -Path $f -Value $lines -Encoding UTF8

Write-Host ""
Write-Host "Tayyor. _NotificationBell Laravel API'ga o'tkazildi." -ForegroundColor Cyan
Write-Host "Qaytarish:  Move-Item '$bak' '$f' -Force" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Endi tekshiring:" -ForegroundColor Cyan
Write-Host "  flutter analyze --no-pub $f"
