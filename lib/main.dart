import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:minute_meeting/alleventpage.dart';
import 'package:minute_meeting/auth_screen.dart';
import 'package:minute_meeting/calendar.dart';
import 'package:minute_meeting/calendarpage.dart';
import 'package:minute_meeting/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:minute_meeting/homepage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:minute_meeting/manageuser.dart';
import 'package:minute_meeting/minutemeetinglist.dart';
import 'package:minute_meeting/profilepage.dart';
import 'package:minute_meeting/roompage.dart';
import 'package:minute_meeting/views/auth/login.dart';
import 'package:minute_meeting/views/auth/register.dart';
import 'package:minute_meeting/views/meeting/create.dart';
import 'package:minute_meeting/views/meeting/list.dart';
import 'package:minute_meeting/views/settings/settings_list.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async{

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,
  );
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // ✅ Register high importance channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // ID must match above
    'High Importance Notifications',
    description: 'Used for critical notifications',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFFCAC5C0), // Matches theme
        scaffoldBackgroundColor: Color(0xFFECEAEA), // Background color

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white, // Background for input fields

          // Default border style
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Color(0xFF7D5A40)),
          ),

          // Border when the field is clicked (focused)
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Color(0xFF7D5A40), width: 2.0),
          ),

          // Border when the field is enabled but not focused
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Color(0xFFCAC5C0)),
          ),

          // Set label color when the field is focused
          floatingLabelStyle: TextStyle(
            color: Color(0xFF7D5A40), // Custom theme color instead of blue
            fontWeight: FontWeight.bold,
          ),

          // Label style when not focused
          labelStyle: TextStyle(
            color: Colors.black,
          ),
        ),
      ),
      routes: {
        '/': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/meeting/create': (context) => CreateMeetingPage(),
        '/meeting/list': (context) => MeetingListPage(),
        '/minute': (context) => MinuteMeetingListPage(),
        '/calendar': (context) => DotCalendarPage(),
        '/reports': (context) => ProfilePage(),
        '/manageroom': (context) => RoomManagementPage(),
        '/manageuser': (context) => UserManagementPage(),
        '/managemeeting': (context) => EventManagementPage(),
        '/login': (context) => AuthPage(),
        '/settings': (context) => SettingsPage(),

      },

      title: 'Minute Meeting',
    );
  }
}
