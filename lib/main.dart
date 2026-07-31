import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  runApp(const VerticalApp());
}
