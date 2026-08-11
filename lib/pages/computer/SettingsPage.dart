import 'package:flutter/material.dart';
import 'package:chocolate_music/Management.dart';

class SettingsPage extends StatefulWidget {
  final Management management = Management();

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Settings Page'));
  }
}
