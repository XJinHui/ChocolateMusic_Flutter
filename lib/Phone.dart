import 'package:flutter/material.dart';
import 'package:chocolate_music/pages/phone/MainView.dart';

class PhotoHomePage extends StatefulWidget {
  const PhotoHomePage({super.key});

  @override
  State<PhotoHomePage> createState() => _PhotoHomePageState();
}

class _PhotoHomePageState extends State<PhotoHomePage> {
  @override
  Widget build(BuildContext context) {
    return MainView();
  }
}
