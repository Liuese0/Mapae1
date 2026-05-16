import 'package:flutter/material.dart';

/// 앱 전역에서 공유하는 ScaffoldMessenger 키.
///
/// bottom sheet / dialog / 다른 modal route 가 닫혀 로컬 messenger 가 dispose
/// 되어도 살아있는 root scaffold 의 messenger 를 통해 스낵바를 띄울 수 있다.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();