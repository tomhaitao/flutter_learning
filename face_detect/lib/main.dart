import 'package:flutter/material.dart';
import 'package:face_detect/face_contour_detection.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Face Contour Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FaceContourDetectionScreen(),
    );
  }
}