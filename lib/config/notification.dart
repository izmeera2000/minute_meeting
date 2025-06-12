import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Config {
  // ignore: constant_identifier_names
  static const base_url = 'https://kaunselingadtectaiping.com.my/';
  // static const base_url = 'http://192.168.0.106/ADTEC-EKaunsel/';
}

Future<void> sendNotificationTopic(
    String topic, String title, String body, String sitename) async {
  final url = Uri.parse('${Config.base_url}get_chat_list'); // Your PHP endpoint

  final response = await http.post(
    url,
    body: {
      'push_notification_topic': "push_notification_topic",
      'topic': topic,
      'title': title,
      'body': body,
      'siteName': sitename,
    },
  );
  debugPrint('Response body: ${response.body}');

  if (response.statusCode == 200) {
    debugPrint('Notification request sent successfully.');
  } else {
    debugPrint('Failed to send notification. Status: ${response.statusCode}');
  }
}

Future<void> sendNotificationToFCM(
  String fcm,
  String title,
  String body,
  String sitename, {
  String? route,
}) async {
  final url = Uri.parse('${Config.base_url}get_chat_list');

  final Map<String, String> bodyData = {
    'push_notification_personal': "push_notification_personal",
    'fcm': fcm,
    'title': title,
    'body': body,
    'siteName': sitename,
  };

  if (route != null) {
    bodyData['route'] = route;
  }

  final response = await http.post(
    url,
    body: bodyData,
  );

  debugPrint('Response body: ${response.body}');

  if (response.statusCode == 200) {
    debugPrint('✅ Notification sent successfully.');
  } else {
    debugPrint('❌ Failed to send notification. Status: ${response.statusCode}');
  }
}


Future<void> subscribeToTopic(String topic) async {
  try {
    await FirebaseMessaging.instance.subscribeToTopic(topic);
    print('✅ Subscribed to topic: $topic');

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final List<String> topics = prefs.getStringList('subscribed_topics') ?? [];

    if (!topics.contains(topic)) {
      topics.add(topic);
      await prefs.setStringList('subscribed_topics', topics);
    }
  } catch (e) {
    print('❌ Failed to subscribe to topic: $e');
  }
}

Future<void> unsubscribeFromAllTopics() async {
  final prefs = await SharedPreferences.getInstance();
  final topics = prefs.getStringList('subscribed_topics') ?? [];

  for (final topic in topics) {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Failed to unsubscribe from $topic: $e');
    }
  }

  // Optionally clear the list
  await prefs.remove('subscribed_topics');
}



Future<void> sendTelegramGroupMessage(String botToken, String groupChatId, String message 
  ) async {
    final url = 'https://api.telegram.org/bot$botToken/sendMessage';

    final response = await http.post(
      Uri.parse(url),
      body: {
        'chat_id': groupChatId,
        'text': message,
      },
    );

    if (response.statusCode == 200) {
      print("Message sent to group successfully");
    } else {
      print("Failed to send message: ${response.body}");
    }
  }