import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/room_model.dart';
import '../../providers/girls_room_provider.dart';
import 'add_girls_room_screen.dart';
import 'girls_room_details_screen.dart';

// ─── Creative "Blossom" palette — qizlar bo'limi uchun mayin, ammo
// zamonaviy dizayn tili: lavanda fon, gullab-yashnayotgan gradientlar.
class _LC {
  static const bg = Color(0xFFF6F1FB);
  static const card = Colors.white;
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFA29BFE);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFFD79A8);
  static const rose = Color(0xFFE84393);
  static const orange = Color(0xFFFDCB6E);
  static const coral = Color(0xFFE17055);
  static const ink = Color(0xFF2D2A4A);
  static const muted = Color(0xFF8B86A8);
  static const faint = Color(0xFFEDE8FA);
}

// ─── GirlsRoomsScreen: Qizlar yotoqxonasi xonalari — qavatlar bo'yicha
// guruhlangan, "gul" temasidagi kreativ ko'rinish. Provider va navigatsiya
// mantiqi o'zgarmagan — faqat vizual qatlam butunlay qayta ishlangan.
class GirlsRoomsScreen extends StatefulWidget {
  final bool isAdmin;
  const GirlsRoomsScreen({super.key, this.isAdmin = true});

  @override
  State<GirlsRoomsScreen> createState() => _GirlsRoomsScreenState();
}

class _GirlsRoomsScreenState extends State<GirlsRoomsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  RoomStatus? _filter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(RoomModel room) {
    if (_searchQuery.trim().isEmpty) return true;
    final q = _searchQuery.trim().toLowerCase();
    return room.roomNumber.toString().contains(q) ||
        room.floor.toString().contains(q) ||
        room.status.displayName.toLowerCase().contains(q);
  }

  Color _statusColor(RoomStatus status) {
    switch (status) {
      case RoomStatus.empty:
        return _LC.teal;
      case RoomStatus.occupied:
        return _LC.pink;
      case RoomStatus.renovation:
        return _LC.coral;
      case RoomStatus.paymentPending:
        return _LC.orange;
    }
  }

  List<Color> _statusGradient(RoomStatus status) {
    switch (status) {
      case RoomStatus.empty:
        return [_LC.teal, const Color(0xFF00A39E)];
      case RoomStatus.occupied:
        return [_LC.pink, _LC.rose];
      case RoomStatus.renovation:
        return [_LC.coral, const Color(0xFFC0392B)];
      case RoomStatus.paymentPending:
        return [_LC.orange, const Color(0xFFE2A93B)];
    }
  }

  void _confirmDelete(
      BuildContext context, GirlsRoomProvider provider, RoomModel room) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Xonani o'chirish"),
        content: Text(
            "${room.roomNumber}-xonani butunlay o'chirmoqchimisiz? Bu amalni ortga qaytarib bo'lmaydi."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Bekor qilish", style: TextStyle(color: _LC.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _LC.coral,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await provider.delete(room.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          "${room.roomNumber}-xona muvaffaqiyatli o'chirildi!")),
                );
              }
            },
            child:
                const Text("O'chirish", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showStatusMenu(
      BuildContext context, GirlsRoomProvider provider, RoomModel room) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _LC.faint, borderRadius: BorderRadius.circular(4)),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("${room.roomNumber}-xona holati",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _LC.ink)),
              ),
              const Divider(height: 1),
              ...RoomStatus.values.map((status) {
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.13),
                        shape: BoxShape.circle),
                    child: Icon(
                      status == RoomStatus.empty
                          ? Icons.check_circle
                          : status == RoomStatus.occupied
                              ? Icons.people_alt_rounded
                              : status == RoomStatus.renovation
                                  ? Icons.build_rounded
                                  : Icons.payments_rounded,
                      color: _statusColor(status),
                      size: 20,
                    ),
                  ),
                  title: Text(status.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: room.status == status
                      ? const Icon(Icons.check_rounded, color: _LC.purple)
                      : null,
                  onTap: () async {
                    await provider.update(room.copyWith(status: status));
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _LC.coral.withOpacity(0.13),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.delete_forever_rounded,
                      color: _LC.coral, size: 20),
                ),
                title: const Text("Xonani o'chirish",
                    style: TextStyle(
                        color: _LC.coral, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, provider, room);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GirlsRoomProvider>();

    return Scaffold(
      backgroundColor: _LC.bg,
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: _LC.rose,
              elevation: 4,
              icon:
                  const Icon(Icons.add_home_work_rounded, color: Colors.white),
              label: const Text('Xona qoshish',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddGirlsRoomScreen()),
              ),
            )
          : null,
      body: StreamBuilder<List<RoomModel>>(
        stream: provider.rooms,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _LC.purple));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Xatolik yuz berdi: ${snapshot.error}"));
          }

          final allRooms = snapshot.data ?? [];
          var rooms = allRooms;
          if (_filter != null) {
            rooms = rooms.where((r) => r.status == _filter).toList();
          }
          final filteredRooms = rooms.where(_matchesSearch).toList();

          final total = allRooms.length;
          final empty =
              allRooms.where((r) => r.status == RoomStatus.empty).length;
          final occupied =
              allRooms.where((r) => r.status == RoomStatus.occupied).length;
          final totalCapacity =
              allRooms.fold<int>(0, (sum, r) => sum + r.capacity);
          final totalOccupants = allRooms.fold<int>(
              0,
              (sum, r) =>
                  sum +
                  (r.studentIds.isNotEmpty
                      ? r.studentIds.length
                      : r.currentOccupants));
          final occupancyRate =
              totalCapacity > 0 ? totalOccupants / totalCapacity : 0.0;

          // Qavatlar bo'yicha guruhlash
          final Map<int, List<RoomModel>> byFloor = {};
          for (final r in filteredRooms) {
            byFloor.putIfAbsent(r.floor, () => []).add(r);
          }
          final floors = byFloor.keys.toList()..sort();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroHeader(
                  total: total,
                  empty: empty,
                  occupied: occupied,
                  occupancyRate: occupancyRate,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _SearchFilterCard(
                    controller: _searchController,
                    query: _searchQuery,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    filter: _filter,
                    onFilterChanged: (f) => setState(() => _filter = f),
                  ),
                ),
              ),
              if (allRooms.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.apartment_rounded,
                    title: "Xonalar mavjud emas",
                    subtitle: "Qizlar yotoqxonasida hozircha xona yo'q.",
                  ),
                )
              else if (filteredRooms.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.search_off_rounded,
                    title: "Hech narsa topilmadi",
                    subtitle: "Qidiruvga mos xona topilmadi.",
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      for (final floor in floors) ...[
                        _FloorHeader(
                          floor: floor,
                          count: byFloor[floor]!.length,
                        ),
                        const SizedBox(height: 12),
                        _RoomGrid(
                          rooms: byFloor[floor]!,
                          isAdmin: widget.isAdmin,
                          statusColor: _statusColor,
                          statusGradient: _statusGradient,
                          onTap: (room) => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    GirlsRoomDetailsScreen(room: room)),
                          ),
                          onLongPress: widget.isAdmin
                              ? (room) =>
                                  _showStatusMenu(context, provider, room)
                              : null,
                          onDelete: widget.isAdmin
                              ? (room) =>
                                  _confirmDelete(context, provider, room)
                              : null,
                        ),
                        const SizedBox(height: 22),
                      ],
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Hero header: gullar/naqshli gradient fon + statistik chiplar +
// umumiy bandlik doiraviy indikatori.
class _HeroHeader extends StatelessWidget {
  final int total;
  final int empty;
  final int occupied;
  final double occupancyRate;
  const _HeroHeader({
    required this.total,
    required this.empty,
    required this.occupied,
    required this.occupancyRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_LC.rose, _LC.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Transform.rotate(
              angle: -0.3,
              child: Icon(Icons.spa_rounded,
                  size: 130, color: Colors.white.withOpacity(0.08)),
            ),
          ),
          Positioned(
            bottom: -25,
            left: -15,
            child: Icon(Icons.favorite_rounded,
                size: 90, color: Colors.white.withOpacity(0.07)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.meeting_room_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Qizlar xonalari",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$total ta xona • $occupied band • $empty bo'sh",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12.5),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                              icon: Icons.check_circle_rounded,
                              label: "Bo'sh",
                              value: '$empty'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStat(
                              icon: Icons.people_alt_rounded,
                              label: 'Band',
                              value: '$occupied'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _OccupancyRing(rate: occupancyRate),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 11)),
        ],
      ),
    );
  }
}

class _OccupancyRing extends StatelessWidget {
  final double rate;
  const _OccupancyRing({required this.rate});

  @override
  Widget build(BuildContext context) {
    final pct = (rate.clamp(0, 1) * 100).round();
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: CircularProgressIndicator(
              value: rate.clamp(0, 1),
              strokeWidth: 7,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$pct%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              Text('band',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 9.5)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Qidiruv + filtr — hero ustidan "suzib turuvchi" karta ko'rinishida.
class _SearchFilterCard extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final RoomStatus? filter;
  final ValueChanged<RoomStatus?> onFilterChanged;

  const _SearchFilterCard({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _LC.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _LC.purple.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _LC.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: "Xona raqami, qavat yoki holat...",
                hintStyle: const TextStyle(color: _LC.muted, fontSize: 13.5),
                prefixIcon: const Icon(Icons.search_rounded, color: _LC.purple),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: _LC.muted, size: 20),
                        onPressed: onClear,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'Barchasi',
                  selected: filter == null,
                  onTap: () => onFilterChanged(null),
                ),
                for (final s in RoomStatus.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _FilterChip(
                      label: s.displayName,
                      selected: filter == s,
                      onTap: () => onFilterChanged(s),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloorHeader extends StatelessWidget {
  final int floor;
  final int count;
  const _FloorHeader({required this.floor, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_LC.violet, _LC.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text('$floor',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
        ),
        const SizedBox(width: 10),
        Text('$floor-qavat',
            style: const TextStyle(
                color: _LC.ink, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: _LC.faint),
        ),
        const SizedBox(width: 8),
        Text('$count xona',
            style: const TextStyle(
                color: _LC.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Responsiv xonalar to'ri — bitta qavat uchun.
class _RoomGrid extends StatelessWidget {
  final List<RoomModel> rooms;
  final bool isAdmin;
  final Color Function(RoomStatus) statusColor;
  final List<Color> Function(RoomStatus) statusGradient;
  final ValueChanged<RoomModel> onTap;
  final ValueChanged<RoomModel>? onLongPress;
  final ValueChanged<RoomModel>? onDelete;

  const _RoomGrid({
    required this.rooms,
    required this.isAdmin,
    required this.statusColor,
    required this.statusGradient,
    required this.onTap,
    this.onLongPress,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      int crossAxisCount;
      double aspectRatio;
      if (width >= 1100) {
        crossAxisCount = 4;
        aspectRatio = 0.82;
      } else if (width >= 800) {
        crossAxisCount = 3;
        aspectRatio = 0.8;
      } else if (width >= 520) {
        crossAxisCount = 2;
        aspectRatio = 0.78;
      } else {
        crossAxisCount = 2;
        aspectRatio = 0.72;
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: aspectRatio,
        ),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return _RoomCard(
            room: room,
            isAdmin: isAdmin,
            statusColor: statusColor(room.status),
            statusGradient: statusGradient(room.status),
            onTap: () => onTap(room),
            onLongPress: onLongPress != null ? () => onLongPress!(room) : null,
            onDelete: onDelete != null ? () => onDelete!(room) : null,
          );
        },
      );
    });
  }
}

// ─── Bitta xona kartasi — "eshik" shaklidagi kreativ dizayn, karavot
// belgilari orqali bandlikni vizual ko'rsatadi.
class _RoomCard extends StatelessWidget {
  final RoomModel room;
  final bool isAdmin;
  final Color statusColor;
  final List<Color> statusGradient;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  const _RoomCard({
    required this.room,
    required this.isAdmin,
    required this.statusColor,
    required this.statusGradient,
    required this.onTap,
    this.onLongPress,
    this.onDelete,
  });

  String _formatMoney(num value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final int occupants = room.studentIds.isNotEmpty
        ? room.studentIds.length
        : room.currentOccupants;
    final int capacity = math.max(room.capacity, 1);
    final bool isFull = occupants >= capacity && room.capacity > 0;
    final gradient =
        isFull ? [_LC.coral, const Color(0xFFC0392B)] : statusGradient;
    final color = isFull ? _LC.coral : statusColor;

    return Stack(
      children: [
        Positioned.fill(
          child: Material(
            color: _LC.card,
            borderRadius: BorderRadius.circular(22),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              onLongPress: onLongPress,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _LC.faint),
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  children: [
                    // "Eshik peshtoqi" — gradientli tepa qism
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22)),
                      ),
                      child: Center(
                        child: Text(
                          "${room.roomNumber}",
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Karavotlar qatori — sig'im vs band bo'yicha
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 3,
                              runSpacing: 3,
                              children: List.generate(capacity, (i) {
                                final filled = i < occupants;
                                return Icon(
                                  Icons.bed_rounded,
                                  size: 15,
                                  color: filled
                                      ? color
                                      : _LC.faint.withOpacity(0.9),
                                );
                              }),
                            ),
                            Text("$occupants/${room.capacity} kishi",
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _LC.muted)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                  color: color.withOpacity(0.13),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                isFull ? "To'lgan" : room.status.displayName,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: color),
                              ),
                            ),
                            Text("${_formatMoney(room.pricePerMonth)} so'm",
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _LC.purple)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isAdmin && onDelete != null)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 14, color: _LC.coral),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration:
                  BoxDecoration(color: _LC.faint, shape: BoxShape.circle),
              child: Icon(icon, size: 46, color: _LC.violet),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: _LC.ink, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _LC.muted, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_LC.rose, _LC.purple])
              : null,
          color: selected ? null : _LC.bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : _LC.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
