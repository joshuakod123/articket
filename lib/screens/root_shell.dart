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
///
/// ## 탭바에 키를 하나 물렸습니다
///
/// 첫 안내(코치 마크)가 **실제 탭바의 좌표를 읽어** 그 자리만 도려냅니다.
/// 안내용으로 탭바를 한 벌 더 그리면, 진짜 탭바가 바뀔 때 안내만 옛날
/// 모습으로 남습니다. 키를 만드는 자리는 탭바를 실제로 소유한 여기입니다.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  /// 코치 마크가 도려낼 하단 탭바. [ArchiveScreen]으로 내려보냅니다.
  final _navBarKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          // `IndexedStack`은 세 화면을 **동시에 살려둡니다.** 그래서 서랍
          // 화면은 자기가 지금 보이는지 스스로 알 수 없습니다. 첫 안내를
          // 안 보이는 탭 뒤에서 띄우면 안 되므로 여기서 알려줍니다.
          ArchiveScreen(navBarKey: _navBarKey, active: _index == 0),
          const CalendarScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: KeyedSubtree(
        key: _navBarKey,
        child: ArticketNavBar(
          index: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}