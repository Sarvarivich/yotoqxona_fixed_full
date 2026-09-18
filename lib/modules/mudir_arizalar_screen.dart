import 'package:yotoqxona/roles/room_assignment_screen.dart';
import 'models/room_model.dart';
import 'package:flutter/material.dart';

import '../modules/models/user_model.dart';
import 'services/api_service.dart';

/// Mudir uchun faqat yotoqxona ARIZA yuborgan talabalarni boshqarish ekrani.
/// Dizayn foydalanuvchi yuborgan "Umumiy ro'yxat" skrinshotidagi yengil,
/// kartochkali ko'rinishga moslangan.
class MudirArizalarScreen extends StatefulWidget {
  final UserModel user;

  const MudirArizalarScreen({super.key, required this.user});

  @override
  State<MudirArizalarScreen> createState() => _MudirArizalarScreenState();
}

class _MudirArizalarScreenState extends State<MudirArizalarScreen> {
  final _api = ApiService();

  // Arizalar Laravel API'dan bir marta yuklanadi.
  //
  // MUHIM: Future initState'da yaratiladi. build() ichida yaratilsa,
  // har bir qidiruv harfida yangi so'rov ketardi.
  late Future<List<Map<String, dynamic>>> _arizalar;


  /// Ariza yuborgan talabalarni yuklaydi.
  ///
  /// Ilgari `foydalanuvchilar` kolleksiyasidan applicationStep >= 2
  /// bo'lganlar olinardi. Laravel'da arizalar alohida jadvalda
  /// (`applications`), va backend mudirni o'z binosi bilan o'zi
  /// cheklaydi.
  ///
  /// Ekrandagi filtrlar talaba shaklidagi map kutadi, shuning uchun
  /// ariza va talaba ma'lumotini bitta mapga birlashtiramiz.
  Future<List<Map<String, dynamic>>> _yukla() async {
    final natija = <Map<String, dynamic>>[];

    int sahifa = 1;
    int oxirgi = 1;

    do {
      final javob = await _api.get('applications?per_page=100&page=$sahifa');

      final royxat = javob['data'];
      // Backend paginate() qaytaradi: data ichida yana data bo'lishi
      // mumkin.
      final elementlar = royxat is Map ? royxat['data'] : royxat;

      if (elementlar is List) {
        for (final e in elementlar) {
          if (e is! Map) continue;
          final ariza = Map<String, dynamic>.from(e);

          final talaba = ariza['user'] ?? ariza['student'];
          if (talaba is! Map) continue;

          final birlashgan = Map<String, dynamic>.from(talaba);

          // Ekran eski (Firestore) nomlarni o'qiydi - moslashtiramiz.
          birlashgan['fullName'] =
              talaba['full_name'] ?? talaba['fullName'] ?? '';
          birlashgan['phoneNumber'] =
              talaba['phone'] ?? talaba['phoneNumber'] ?? '';
          birlashgan['studentId'] =
              talaba['group_name'] ?? talaba['studentId'] ?? '';

          // Ariza maydonlari
          birlashgan['applicationId'] = ariza['id'];
          birlashgan['applicationStep'] =
              (ariza['step'] as num?)?.toInt() ?? 2;
          birlashgan['applicationStatus'] =
              (ariza['status'] ?? 'submitted').toString();
          birlashgan['hasSocialBenefit'] =
              ariza['has_social_benefit'] == true;
          birlashgan['benefitType'] = ariza['benefit_type'];
          birlashgan['hostelAssignmentType'] = ariza['assignment_type'];
          birlashgan['assignmentMessage'] = ariza['assignment_message'];

          // Bino: talabaning hostel maydoni
          birlashgan['hostel'] =
              (talaba['hostel'] ?? 'boys').toString().toLowerCase();
          birlashgan['role'] = 'talaba';

          natija.add(birlashgan);
        }
      }

      final meta = javob['meta'] ?? (royxat is Map ? royxat : null);
      oxirgi = meta is Map
          ? ((meta['last_page'] as num?)?.toInt() ?? sahifa)
          : sahifa;
      sahifa++;
    } while (sahifa <= oxirgi && sahifa <= 100);

    return natija;
  }

  Future<void> _qaytaYukla() async {
    if (!mounted) return;
    setState(() {
      _arizalar = _yukla();
    });
    await _arizalar;
  }
  final _search = TextEditingController();

  String _category = 'all'; // all | social | ordinary
  String _query = '';

  @override
  void initState() {
    super.initState();
    _arizalar = _yukla();
    _search.addListener(() {
      if (mounted) setState(() => _query = _search.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Map<String, dynamic> d) {
    if ((d['role'] ?? '').toString() != 'talaba') return false;

    final appStep = (d['applicationStep'] as num?)?.toInt() ?? 2;
    if (appStep < 2) return false;

    // Mudirning o'g'il/qizlar yo'nalishi saqlanadi. Eski yozuvlarda hostel
    // bo'lmasa, ularni boys deb qabul qilamiz.
    final selectedHostel = (d['hostel'] ?? 'boys').toString();
    final myHostel = widget.user.hostel ?? 'boys';
    if (selectedHostel != myHostel) return false;

    final social = d['hasSocialBenefit'] == true;
    if (_category == 'social' && !social) return false;
    if (_category == 'ordinary' && social) return false;

    if (_query.isEmpty) return true;

    final haystack = [
      d['fullName'],
      d['phoneNumber'],
      d['jshshir'],
      d['studentId'],
      d['faculty'],
    ].where((e) => e != null).join(' ').toLowerCase();

    return haystack.contains(_query);
  }

  String _studentGenderHostel(Map<String, dynamic> data) {
    final raw =
        (data['hostel'] ?? data['genderHostel'] ?? data['jins'] ?? 'boys')
            .toString()
            .trim()
            .toLowerCase();
    switch (raw) {
      case 'girls':
      case 'girl':
      case 'female':
      case 'qiz':
      case 'qizlar':
        return 'girls';
      default:
        return 'boys';
    }
  }

  Future<void> _openAssignment(
      Map<String, dynamic> data, String studentId) async {
    final user = UserModel.fromJson({...data, 'id': studentId});
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AssignmentDialog(
        student: user,
        genderHostel: _studentGenderHostel(data),
        applicationId: (data['applicationId'] ?? '').toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _arizalar,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Arizalarni yuklashda xatolik:\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _C.muted),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _qaytaYukla,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Qayta urinish'),
                  ),
                ],
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final hammasi = snap.data ?? const <Map<String, dynamic>>[];

          final docs = hammasi.where((d) => _matches(d)).toList();
          final socialCount =
              hammasi.where((x) => _matchesWithCategory(x, 'social')).length;
          final ordinaryCount =
              hammasi.where((x) => _matchesWithCategory(x, 'ordinary')).length;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: _header(docs.length, socialCount, ordinaryCount)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: docs.isEmpty
                    ? const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            "Ariza yuborgan talabalar topilmadi",
                            style: TextStyle(
                              color: _C.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final count = width >= 1100
                              ? 3
                              : width >= 650
                                  ? 2
                                  : 1;
                          const gap = 14.0;

                          // Fixed balandlik ishlatilmaydi. Har bir karta oРІР‚Вz
                          // kontentining tabiiy balandligini oladi. Shu sababli
                          // oynani istalgan oРІР‚Вlchamga oРІР‚Вzgartirganda ham
                          // BOTTOM/RIGHT OVERFLOW yuz bermaydi va desktopda
                          // karta ostida ortiqcha boРІР‚Вsh joy qolmaydi.
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: docs.map((doc) {
                                  final cardWidth = count == 1
                                      ? width
                                      : (width - gap * (count - 1)) / count;
                                  return SizedBox(
                                    width: cardWidth,
                                    child: _ApplicantCard(
                                      data: doc,
                                      onAssign: () => _openAssignment(
                                        doc,
                                        (doc['id'] ?? '').toString(),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesWithCategory(Map<String, dynamic> d, String category) {
    if ((d['role'] ?? '').toString() != 'talaba') return false;
    final appStep = (d['applicationStep'] as num?)?.toInt() ?? 2;
    if (appStep < 2) return false;
    final selectedHostel = (d['hostel'] ?? 'boys').toString();
    if (selectedHostel != (widget.user.hostel ?? 'boys')) return false;
    final social = d['hasSocialBenefit'] == true;
    return category == 'social' ? social : !social;
  }

  Widget _header(int total, int social, int ordinary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 820;
        final veryNarrow = constraints.maxWidth < 600;

        final titleBlock = Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _C.purple.withOpacity(.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.assignment_rounded,
                color: _C.purple,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ariza yuborgan talabalar',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _C.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "Barcha yotoqxona arizalari bo'yicha talabalar",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _C.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        );

        final countBlock = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CountPill(
                label: 'Jami', value: total.toString(), color: _C.purple),
            const SizedBox(width: 7),
            _CountPill(
                label: "Ijtimoiy", value: social.toString(), color: _C.teal),
            const SizedBox(width: 7),
            _CountPill(
                label: 'Oddiy', value: ordinary.toString(), color: _C.pink),
          ],
        );

        final searchField = TextField(
          controller: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, color: _C.muted),
            hintText: "Qidirish: FIO, telefon, JSHSHIR...",
            hintStyle: const TextStyle(color: _C.muted, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _C.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _C.border),
            ),
          ),
        );

        final filterField = DropdownButtonFormField<String>(
          initialValue: _category,
          isExpanded: true,
          decoration: _dropdownDecoration(),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Barchasi')),
            DropdownMenuItem(
              value: 'social',
              child: Text('Ijtimoiy holatdagi'),
            ),
            DropdownMenuItem(
              value: 'ordinary',
              child: Text('Oddiy holatdagi'),
            ),
          ],
          onChanged: (v) => setState(() => _category = v ?? 'all'),
        );

        return Container(
          color: _C.bg,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!narrow)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 14),
                    countBlock,
                  ],
                )
              else ...[
                titleBlock,
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: countBlock,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (veryNarrow)
                Column(
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: filterField,
                    ),
                  ],
                )
              else if (narrow)
                Column(
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: filterField,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: filterField),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _dropdownDecoration() => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        prefixIcon: const Icon(Icons.filter_alt_outlined, color: _C.purple),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.border),
        ),
      );
}

class _ApplicantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onAssign;

  const _ApplicantCard({required this.data, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    final name = (data['fullName'] ?? 'NomaРљСlum talaba').toString();
    final social = data['hasSocialBenefit'] == true;
    final assigned = (data['roomId'] ?? '').toString().isNotEmpty ||
        (data['hostelAssignmentType'] ?? '').toString().isNotEmpty;
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'T';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _C.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: social
                        ? _C.teal.withOpacity(.12)
                        : _C.pink.withOpacity(.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: social ? _C.tealDark : _C.pinkDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _Tag(
                        text: social ? "Ijtimoiy holat" : "Oddiy holat",
                        color: social ? _C.teal : _C.pink,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: assigned
                      ? "Biriktirishni o'zgartirish"
                      : "Xonaga biriktirish",
                  onPressed: onAssign,
                  icon: Icon(
                    assigned
                        ? Icons.home_work_rounded
                        : Icons.apartment_rounded,
                    color: _C.purple,
                  ),
                ),
              ],
            ),
            const Divider(height: 18, color: _C.border),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _Meta(Icons.phone_outlined,
                    (data['phoneNumber'] ?? 'РІР‚вЂќ').toString()),
                _Meta(
                    Icons.badge_outlined, (data['jshshir'] ?? 'РІР‚вЂќ').toString()),
                _Meta(
                  Icons.school_outlined,
                  "${data['faculty'] ?? 'Fakultet'} / ${data['course'] ?? 'РІР‚вЂќ'}-kurs",
                ),
                _Meta(Icons.map_outlined, (data['region'] ?? 'РІР‚вЂќ').toString()),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(
                  assigned
                      ? Icons.check_circle_rounded
                      : Icons.pending_actions_rounded,
                  size: 15,
                  color: assigned ? _C.tealDark : _C.coral,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    assigned
                        ? ((data['hostelAssignmentType'] ?? '').toString() ==
                                'rental'
                            ? 'Ijara boРІР‚Вyicha ajratilgan'
                            : 'Yotoqxonaga biriktirilgan')
                        : 'Biriktirilmagan',
                    style: TextStyle(
                      color: assigned ? _C.tealDark : _C.coral,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAssign,
                  icon:
                      const Icon(Icons.assignment_turned_in_outlined, size: 16),
                  label: Text(assigned ? 'KoРІР‚Вrish' : 'Biriktirish'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentDialog extends StatefulWidget {
  final UserModel student;
  final String genderHostel;

  /// Talabaning arizasi ID'si. Xona biriktirilgach ariza holati shu
  /// ID bo'yicha yangilanadi (PUT /api/applications/{id}).
  final String applicationId;

  const _AssignmentDialog({
    required this.student,
    required this.genderHostel,
    required this.applicationId,
  });

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  final _api = ApiService();


  static const types = [
    ('university', 'Universitet yotoqxonasi', Icons.account_balance_rounded),
    ('avto_yol', 'Avto yoРІР‚Вl yotoqxonasi', Icons.directions_car_rounded),
    ('medical', 'Med kollej yotoqxonasi', Icons.local_hospital_rounded),
    (
      'navoi_object',
      'Navoiydagi obyekt yotoqxonasi',
      Icons.location_city_rounded
    ),
    ('rental', 'Ijara uchun ajratilgan', Icons.home_work_rounded),
  ];

  String? _selectedType;
  bool _loading = false;
  List<Map<String, dynamic>> _rooms = [];
  String? _error;

  Future<void> _selectType(String type) async {
    setState(() {
      _selectedType = type;
      _error = null;
      _rooms = [];
    });

    if (type == 'rental') return;

    setState(() => _loading = true);
    try {
      // Xonalar Laravel API'dan olinadi.
      //
      // Bino turi xonaning `hostel_type` ustunida saqlanadi. Tanlangan
      // turga tegishli BARCHA xonalar ko'rsatiladi - bo'sh, qisman
      // band va to'lganlari ham. Jins bo'yicha filtr qilinmaydi:
      // mudir umumiy holatni ko'rishi kerak.
      final xom = await _api.getRooms();

      final filtered = <Map<String, dynamic>>[];
      for (final x in xom) {
        if (x is! Map) continue;
        final d = Map<String, dynamic>.from(x);

        final raw = (d['hostel_type'] ?? d['hostelType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final roomType = _normalizeRoomType(raw);
        if (roomType != type) continue;

        filtered.add(d);
      }

      int bandlik(Map<String, dynamic> d) =>
          int.tryParse(
            (d['current_occupants'] ?? d['currentOccupants'] ?? 0).toString(),
          ) ??
          0;

      filtered.sort((a, b) => bandlik(a).compareTo(bandlik(b)));

      if (mounted) setState(() => _rooms = filtered);
    } catch (e) {
      if (mounted) setState(() => _error = 'Xonalarni olishda xatolik: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _hostelTypeAliases(String type) {
    switch (type) {
      case 'medical':
        return const ['medical', 'med_college', 'med_kollej'];
      case 'avto_yol':
        return const ['avto_yol', 'avtoyol', 'avto'];
      case 'navoi_object':
        return const ['navoi_object', 'navoiy_object', 'navoi'];
      case 'rental':
        return const ['rental', 'ijara'];
      case 'university':
      default:
        return const ['university'];
    }
  }

  String _normalizeGenderHostel(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'girls':
      case 'girl':
      case 'female':
      case 'qiz':
      case 'qizlar':
        return 'girls';
      default:
        return 'boys';
    }
  }

  String _normalizeRoomType(String raw) {
    switch (raw) {
      case 'medical':
      case 'med_college':
      case 'med_kollej':
        return 'medical';
      case 'avto_yol':
      case 'avtoyol':
      case 'avto':
        return 'avto_yol';
      case 'navoi_object':
      case 'navoiy_object':
      case 'navoi':
        return 'navoi_object';
      case 'rental':
      case 'ijara':
        return 'rental';
      default:
        return 'university';
    }
  }

  String _roomStatusText(int occupants, int capacity) {
    if (capacity <= 0) return 'SigРІР‚Вim belgilanmagan';
    if (occupants >= capacity) return 'ToРІР‚Вliq band';
    if (occupants <= 0) return 'BoРІР‚Вsh';
    return 'Qisman band';
  }

  Future<void> _openRoomDetails(Map<String, dynamic> roomDoc) async {
    final data = Map<String, dynamic>.from(roomDoc);

    final room = RoomModel.fromJson(data);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomDetailsScreen(
          roomDocId: (roomDoc['id'] ?? '').toString(),
          room: room,
          hostel: room.hostel,
        ),
      ),
    );

    if (mounted && _selectedType != null && _selectedType != 'rental') {
      await _selectType(_selectedType!);
    }
  }

  String _typeName(String type) => types.firstWhere((e) => e.$1 == type).$2;

  Future<void> _assignToRoom(Map<String, dynamic> roomDoc) async {
    setState(() => _loading = true);
    try {
      final roomId = (roomDoc['id'] ?? '').toString();
      if (roomId.isEmpty) {
        throw StateError('Xona ID topilmadi.');
      }

      // Biriktirish Laravel tomonida bitta tranzaksiyada bajariladi:
      // eski biriktirish yopiladi, yangisi ochiladi, xona bandligi
      // yangilanadi. Sig'im tekshiruvi ham o'sha yerda - ikki mudir
      // bir vaqtda oxirgi joyni band qilsa, ikkinchisi xato oladi.
      await _api.assignStudentToRoom(
        studentId: widget.student.id,
        roomId: roomId,
      );

      // Ariza holatini 3-bosqichga ("xona ajratildi") o'tkazamiz.
      final arizaId = widget.applicationId;
      if (arizaId.isNotEmpty) {
        final assignment = _typeName(_selectedType!);
        try {
          await _api.put('applications/$arizaId', body: {
            'status': 'assigned',
            'step': 3,
            'room_id': roomId,
            'assignment_type':
                _selectedType == 'medical' ? 'med_college' : _selectedType,
            'assignment_message': '${assignment}ga biriktirildingiz.',
          });
        } catch (e) {
          // Xona biriktirildi, faqat ariza holati yangilanmadi.
          debugPrint('Ariza holatini yangilashda xatolik: $e');
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Talaba xona bilan muvaffaqiyatli biriktirildi.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showRentalStudentDetails(
      Map<String, dynamic> data, String docId) async {
    if (!mounted) return;

    final name =
        (data['fullName'] ?? data['name'] ?? 'NomaРІР‚в„ўlum talaba').toString();
    final phone = (data['phoneNumber'] ?? data['phone'] ?? '-').toString();
    final studentId = (data['studentId'] ?? data['jshshir'] ?? '-').toString();
    final faculty = (data['faculty'] ?? '-').toString();
    final course = (data['course'] ?? '-').toString();
    final region = (data['region'] ?? '-').toString();
    final message = (data['assignmentMessage'] ?? '').toString();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ijara uchun biriktirilgan talaba',
                style: TextStyle(
                  color: _C.tealDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _detailRow(Icons.phone_outlined, 'Telefon', phone),
              _detailRow(
                  Icons.badge_outlined, 'Student ID / JSHSHIR', studentId),
              _detailRow(Icons.school_outlined, 'Fakultet', faculty),
              _detailRow(Icons.menu_book_outlined, 'Kurs', course),
              _detailRow(Icons.map_outlined, 'Viloyat', region),
              if (message.trim().isNotEmpty)
                _detailRow(Icons.info_outline, 'MaРІР‚в„ўlumot', message),
              _detailRow(
                  Icons.home_work_outlined, 'Turi', 'Ijara uchun ajratilgan'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _C.purple),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: _C.ink, fontSize: 12),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ijara varianti tanlangan talabalarni yuklaydi.
  ///
  /// Laravel'da bu arizalar jadvalidagi assignment_type = 'rental'
  /// yozuvlar. Ekran talaba shaklidagi map kutadi, shuning uchun
  /// ariza va talaba ma'lumotini birlashtiramiz.
  Future<List<Map<String, dynamic>>> _ijaradagilar() async {
    final natija = <Map<String, dynamic>>[];

    try {
      final javob = await _api.get('applications?per_page=100');
      final royxat = javob['data'];
      final elementlar = royxat is Map ? royxat['data'] : royxat;

      if (elementlar is List) {
        for (final e in elementlar) {
          if (e is! Map) continue;
          final ariza = Map<String, dynamic>.from(e);

          if ((ariza['assignment_type'] ?? '').toString() != 'rental') {
            continue;
          }

          final holat = (ariza['status'] ?? '').toString();
          if (holat.isNotEmpty &&
              holat != 'assigned' &&
              holat != 'completed') {
            continue;
          }

          final talaba = ariza['user'] ?? ariza['student'];
          if (talaba is! Map) continue;

          final birlashgan = Map<String, dynamic>.from(talaba);
          birlashgan['fullName'] =
              talaba['full_name'] ?? talaba['fullName'] ?? '';
          birlashgan['phoneNumber'] =
              talaba['phone'] ?? talaba['phoneNumber'] ?? '';
          birlashgan['studentId'] =
              talaba['group_name'] ?? talaba['studentId'] ?? '';
          birlashgan['assignmentMessage'] = ariza['assignment_message'];
          birlashgan['applicationStatus'] = holat;

          natija.add(birlashgan);
        }
      }
    } catch (e) {
      debugPrint('Ijaradagilarni yuklashda xatolik: $e');
    }

    return natija;
  }

  Future<void> _assignRental() async {
    setState(() => _loading = true);
    try {
      // Ijara - xona biriktirilmaydi, faqat ariza holati o'zgaradi.
      final arizaId = widget.applicationId;
      if (arizaId.isEmpty) {
        throw StateError('Ariza topilmadi.');
      }

      await _api.put('applications/$arizaId', body: {
        'status': 'assigned',
        'step': 3,
        'assignment_type': 'rental',
        'assignment_message':
            "To'liq ma'lumot olish uchun Yoshlar bilan ishlash "
            "departamentiga murojaat qiling.",
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Talabaga ijara boРІР‚Вyicha yotoqxona ajratildi.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Saqlashda xatolik: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createNewRoom() async {
    final numberCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '4');
    final priceCtrl = TextEditingController(text: '500000');

    final values = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yangi xona qoРІР‚Вshish'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Xona raqami'),
            ),
            TextField(
              controller: capacityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'SigРІР‚Вimi'),
            ),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Oylik toРІР‚Вlov'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor qilish')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(numberCtrl.text);
              final c = int.tryParse(capacityCtrl.text);
              final p = int.tryParse(priceCtrl.text);
              if (n != null && c != null && c > 0 && p != null) {
                Navigator.pop(ctx, [n, c, p]);
              }
            },
            child: const Text('QoРІР‚Вshish'),
          ),
        ],
      ),
    );

    numberCtrl.dispose();
    capacityCtrl.dispose();
    priceCtrl.dispose();

    if (values == null || !mounted) return;

    setState(() => _loading = true);
    try {
      // Xona Laravel'da yaratiladi, keyin talaba unga biriktiriladi.
      // Ikki alohida so'rov, lekin har biri server tomonda
      // tranzaksiyada bajariladi.
      final javob = await _api.createRoom({
        'room_number': values[0].toString(),
        'floor': 1,
        'capacity': values[1],
        'hostel': widget.genderHostel,
        'hostel_type': _selectedType,
        'price_per_month': values[2].toDouble(),
        'status': 'empty',
        'amenities': <String>[],
        'notes': "Ariza bo'yicha yangi yaratilgan xona",
      });

      final yangiXona = javob['data'];
      final roomId = yangiXona is Map ? (yangiXona['id'] ?? '').toString() : '';
      if (roomId.isEmpty) {
        throw StateError('Yangi xona ID si olinmadi.');
      }

      await _api.assignStudentToRoom(
        studentId: widget.student.id,
        roomId: roomId,
      );

      final arizaId = widget.applicationId;
      if (arizaId.isNotEmpty) {
        try {
          await _api.put('applications/$arizaId', body: {
            'status': 'assigned',
            'step': 3,
            'room_id': roomId,
            'assignment_type':
                _selectedType == 'medical' ? 'med_college' : _selectedType,
            'assignment_message':
                '${_typeName(_selectedType!)}ga biriktirildingiz.',
          });
        } catch (e) {
          debugPrint('Ariza holatini yangilashda xatolik: $e');
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('РІвЂћвЂ“${values[0]} xona yaratildi va talaba biriktirildi.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Xona yaratishda xatolik: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assigned =
        widget.student.hasRoom || widget.student.assignmentType != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _C.purple.withOpacity(.12),
                    child: Text(
                      widget.student.fullName.isNotEmpty
                          ? widget.student.fullName
                              .substring(0, 1)
                              .toUpperCase()
                          : 'T',
                      style: const TextStyle(
                          color: _C.purple, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.student.fullName,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                        Text(
                          assigned
                              ? 'Biriktirishni koРІР‚Вrish/oРІР‚Вzgartirish'
                              : 'Yotoqxona turini tanlang',
                          style: const TextStyle(color: _C.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Yotoqxona turi',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: _C.ink),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: types.map((e) {
                  final active = _selectedType == e.$1;
                  return ChoiceChip(
                    selected: active,
                    avatar: Icon(e.$3,
                        size: 17, color: active ? Colors.white : _C.purple),
                    label: Text(e.$2),
                    selectedColor: _C.purple,
                    labelStyle: TextStyle(
                      color: active ? Colors.white : _C.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => _selectType(e.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              if (_selectedType == 'rental')
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    // Ijara varianti tanlangan talabalar.
                    //
                    // Laravel'da bu ariza jadvalidagi
                    // assignment_type = 'rental' yozuvlar.
                    future: _ijaradagilar(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            "Ijara bo'yicha talabalarni olishda xatolik: "
                            "${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final students = snapshot.data ?? const [];

                      if (students.isEmpty) {
                        return Center(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F5FD),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.home_work_outlined,
                                    size: 42, color: _C.muted),
                                SizedBox(height: 10),
                                Text(
                                  'Ijara uchun biriktirilgan talabalar yoРІР‚Вq',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _C.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Ijara varianti tanlangan talabalar shu yerda koРІР‚Вrinadi.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _C.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final d = students[index];
                          final name =
                              (d['fullName'] ?? d['name'] ?? 'NomaРІР‚в„ўlum talaba')
                                  .toString();
                          final phone = (d['phoneNumber'] ??
                                  d['phone'] ??
                                  'Telefon koРІР‚Вrsatilmagan')
                              .toString();
                          final faculty =
                              (d['faculty'] ?? 'Fakultet koРІР‚Вrsatilmagan')
                                  .toString();
                          final region =
                              (d['region'] ?? 'Viloyat koРІР‚Вrsatilmagan')
                                  .toString();
                          final social = (d['socialStatus'] ??
                                  d['socialCategory'] ??
                                  d['additionalData']?['socialStatus'])
                              ?.toString();

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showRentalStudentDetails(
                              d,
                              (d['id'] ?? '').toString(),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F5FD),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _C.teal.withOpacity(.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _C.teal.withOpacity(.12),
                                    child: Text(
                                      name.isNotEmpty
                                          ? name.characters.first.toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: _C.tealDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _C.ink,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          phone,
                                          style: const TextStyle(
                                            color: _C.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$faculty РІР‚Сћ $region',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _C.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                        if (social != null &&
                                            social.trim().isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              social,
                                              style: const TextStyle(
                                                color: _C.tealDark,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: _C.purple,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
              else if (_selectedType != null)
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _rooms.isEmpty
                          ? _EmptyRooms(onCreate: _createNewRoom)
                          : ListView.separated(
                              itemCount: _rooms.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final d = _rooms[i];
                                final roomNo = d['roomNumber'] ?? '-';
                                final occ =
                                    (d['currentOccupants'] as num?)?.toInt() ??
                                        0;
                                final cap =
                                    (d['capacity'] as num?)?.toInt() ?? 4;
                                final full = cap > 0 && occ >= cap;
                                final empty = occ <= 0;
                                final status = _roomStatusText(occ, cap);

                                return InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _openRoomDetails(_rooms[i]),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 10, 10, 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F5FD),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: full
                                            ? _C.coral.withOpacity(.35)
                                            : _C.purple.withOpacity(.12),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: (full
                                                  ? _C.coral
                                                  : empty
                                                      ? _C.teal
                                                      : _C.purple)
                                              .withOpacity(.12),
                                          child: Icon(
                                            full
                                                ? Icons.lock_rounded
                                                : Icons.meeting_room_rounded,
                                            color: full
                                                ? _C.coral
                                                : empty
                                                    ? _C.teal
                                                    : _C.purple,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'РІвЂћвЂ“$roomNo-xona',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: _C.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '$occ/$cap kishi РІР‚Сћ $status',
                                                style: TextStyle(
                                                  color: full
                                                      ? _C.coral
                                                      : empty
                                                          ? _C.teal
                                                          : _C.purple,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                'Xonani bosib yashovchi talabalarni koРІР‚Вring',
                                                style: const TextStyle(
                                                  color: _C.muted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (full)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Text(
                                              'ToРІР‚Вliq',
                                              style: TextStyle(
                                                color: _C.coral,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          )
                                        else
                                          FilledButton.icon(
                                            onPressed: () =>
                                                _assignToRoom(_rooms[i]),
                                            icon: const Icon(
                                              Icons.link_rounded,
                                              size: 15,
                                            ),
                                            label: const Text('Biriktirish'),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                )
              else
                const Expanded(
                  child: Center(
                    child: Text(
                      'Talabani biriktirish uchun yuqoridan yotoqxona turini tanlang.',
                      style: TextStyle(color: _C.muted),
                    ),
                  ),
                ),
              if (_selectedType == 'rental') ...[
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _assignRental,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Ijara yotoqxonasini ajratish'),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyRooms({required this.onCreate});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F5FD),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.meeting_room_outlined,
                  size: 40, color: _C.muted),
              const SizedBox(height: 10),
              const Text(
                'BoРІР‚Вsh xona topilmadi',
                style: TextStyle(fontWeight: FontWeight.w800, color: _C.ink),
              ),
              const SizedBox(height: 5),
              const Text(
                'Barcha xonalar toРІР‚Вla. Yangi xona qoРІР‚Вshib, talabani shu xonaga biriktirishingiz mumkin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _C.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_home_work_rounded),
                label: const Text('Yangi xona qoРІР‚Вshish'),
              ),
            ],
          ),
        ),
      );
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
      );
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _C.muted),
            const SizedBox(width: 5),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.ink, fontSize: 11)),
            ),
          ],
        ),
      );
}

class _CountPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CountPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            Text(label, style: TextStyle(color: color, fontSize: 9)),
          ],
        ),
      );
}

class _C {
  static const bg = Color(0xFFF3F1FB);
  static const border = Color(0xFFE7E2F5);
  static const purple = Color(0xFF6C5CE7);
  static const teal = Color(0xFF00CEC9);
  static const tealDark = Color(0xFF12A181);
  static const pink = Color(0xFFFD79A8);
  static const pinkDark = Color(0xFFD94F86);
  static const coral = Color(0xFFE17055);
  static const ink = Color(0xFF2D2A4A);
  static const muted = Color(0xFF8B86A8);
}
