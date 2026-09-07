import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/hostel_selection_screen.dart';
import 'modules/services/auth_service.dart';
import 'modules/girls/providers/girls_student_provider.dart';
import 'modules/girls/providers/girls_room_provider.dart';
import 'modules/girls/providers/girls_complaint_provider.dart';
import 'modules/girls/providers/girls_notification_provider.dart';
import 'modules/girls/providers/girls_payment_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
