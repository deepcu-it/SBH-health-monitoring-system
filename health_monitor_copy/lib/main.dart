import 'package:flutter/material.dart';
import 'package:health_monitor/home_page.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "AIzaSyDsf2zVZBtGmHu4h7H_bUu8-gGl8KHH7dM",
        authDomain: "health-4f948.firebaseapp.com",
        databaseURL: "https://health-4f948-default-rtdb.firebaseio.com",
        projectId: "health-4f948",
        storageBucket: "health-4f948.firebasestorage.app",
        messagingSenderId: "1027615118164",
        appId: "1:1027615118164:web:ae1a933561fc3420cdeec1",
        measurementId: "G-L3T8C5GSE9"),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Monitor',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}
