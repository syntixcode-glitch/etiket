import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const EtiketApp());
}

class EtiketApp extends StatelessWidget {
  const EtiketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ETİKET',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.white,
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      ),
      home: const HomePage(),
    );
  }
}
