import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'auth/hostel_selection_screen.dart';
import 'modules/services/auth_service.dart';
import 'modules/girls/providers/girls_student_provider.dart';
import 'modules/girls/providers/girls_room_provider.dart';
import 'modules/girls/providers/girls_complaint_provider.dart';
import 'modules/girls/providers/girls_notification_provider.dart';
import 'modules/girls/providers/girls_payment_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://nnifqzpfxccbwnvtmgqm.supabase.co',
    anonKey: 'sb_publishable_RfKTilPwzBHbOt_N-aCJBw_cG2bZAGO',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        // ─── Qizlar yotoqxonasi ('girls') moduli uchun providerlar.
        // Bu providerlar butun ilova bo'ylab mavjud bo'ladi, lekin
        // ma'lumotlari boys tizimidan mustaqil 'girls_*' Firestore
        // to'plamlaridan olinadi.
        ChangeNotifierProvider<GirlsStudentProvider>(
          create: (_) => GirlsStudentProvider(),
        ),
        ChangeNotifierProvider<GirlsRoomProvider>(
          create: (_) => GirlsRoomProvider(),
        ),
        ChangeNotifierProvider<GirlsComplaintProvider>(
          create: (_) => GirlsComplaintProvider(),
        ),
        ChangeNotifierProvider<GirlsNotificationProvider>(
          create: (_) => GirlsNotificationProvider(),
        ),
        ChangeNotifierProvider<GirlsPaymentProvider>(
          create: (_) => GirlsPaymentProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'KU Hostel | Kokand University',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const HostelSelectionScreen(),
        },
      ),
    );
  }
}
