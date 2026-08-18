import 'package:flutter/material.dart';

import '../widgets/bottom_nav_bar.dart';
import 'archive_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';

/// 세 화면을 물고 있는 껍데기.
///
/// 예전에는 탭을 누를 때마다 달력·내 기록을 **새 화면으로 밀어 올렸습니다.**
/// 그래서 (1) 그 화면에서는 탭바가 사라지고, (2) 뒤로 나오면 스크롤 위치와
/// 보던 달이 매번 초기화됐습니다.
///
/// [IndexedStack]으로 세 화면을 나란히 살려두면 탭바가 항상 아래에 남고,
/// 달력에서 7월을 보다 서랍에 갔다 와도 7월 그대로입니다.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          ArchiveScreen(),
          CalendarScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: ArticketNavBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}