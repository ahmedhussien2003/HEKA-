import 'package:flutter/material.dart';
import 'package:heka/views/pages/login_page.dart';
import 'package:heka/data/notifiers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: selectedLanguageNotifier,
      builder: (context, language, _) {
        return MaterialApp(
          title: 'Heka',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            fontFamily: getAppFontFamily(),
            fontFamilyFallback: const ['JosefinSans', 'ReemKufi'],
          ),
          home: const LoginPage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

