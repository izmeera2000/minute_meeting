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
import 'package:minute_meeting/views/minute/top.dart';
import 'package:minute_meeting/views/settings/seed.dart';
import 'package:minute_meeting/views/settings/seedmanagepage.dart';
import 'package:minute_meeting/views/settings/settings_list.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ensure FirebaseMessaging background handling is set
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // You can handle background notifications here
  print("Handling background message: ${message.messageId}");
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    initNotifications();

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification clicked: ${message}');
      _handleMessageNavigation(message.data);
    });

// Also handle if app is launched from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessageNavigation(message.data);
      }
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        print('App launched from terminated with: ${message.data}');
        _handleMessageNavigation(message.data);
      }
    });
  }

  void showGeneralNotification(RemoteNotification notification,
      {String? route}) {
    const androidDetails = AndroidNotificationDetails(
      'general_channel',
      'General Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: route ?? '', // pass route here as payload
    );
  }

  void initNotifications() async {
    // Android init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Optional: handle tap when notification is clicked
    const initSettings = InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        print('Notification clicked: $payload');

        if (payload != null && payload.isNotEmpty) {
          // Use your navigator key to navigate to the route
          navigatorKey.currentState?.pushNamed(payload);
        }
      },
    );

    // Ask for permissions
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      // For iOS: show alert even when app is in foreground
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final android = message.notification?.android;
        final route = message.data['route']; // get route from data payload

        debugPrint('FCM onMessage received');
        debugPrint('Notification title: ${notification?.title}');
        debugPrint('Notification body: ${notification?.body}');
        debugPrint('Android notification? ${android != null}');
        debugPrint('Route from data payload: $route');

        if (notification != null && android != null) {
          showGeneralNotification(notification, route: route);
        } else {
          debugPrint('No valid notification or android data found.');
        }
      });
    } else {
      print('User declined or has not accepted permission');
    }
  }

  void _handleMessageNavigation(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (data.containsKey('route')) {
      final route = data['route'];
      Navigator.pushNamed(context, route);
    } else if (data['screen'] == 'details') {
      Navigator.pushNamed(
        context,
        '/details',
        arguments: {'id': data['itemId']},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Minute Meeting',
      theme: ThemeData(
        primaryColor: const Color(0xFFCAC5C0),
        scaffoldBackgroundColor: const Color(0xFFECEAEA),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFF7D5A40)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFF7D5A40), width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFCAC5C0)),
          ),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFF7D5A40),
            fontWeight: FontWeight.bold,
          ),
          labelStyle: const TextStyle(color: Colors.black),
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
        '/managegroup': (context) =>  ManageSeed(),
        '/manageroom': (context) => RoomManagementPage(),
        '/manageuser': (context) => UserManagementPage(),
        '/managemeeting': (context) => EventManagementPage(),
        '/minutemeeting': (context) => TwoTabsPage(),
        '/login': (context) => LoginPage(),
        '/settings': (context) => SettingsPage(),
      },
    );
  }
}
