import 'package:material_ui/material_ui.dart';
import '../data/ticket_store.dart';
import '../widgets/home/folder_preview_card.dart';
import 'folder_screen.dart';
import 'folder_workbench.dart';

class FolderListScreen extends StatelessWidget {
  const FolderListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = TicketStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 서류철'),
        actions: [
          IconButton(
            tooltip: '서류철 만들기',
            onPressed: () => openFolderWorkbench(
              context,
              store: store,
              fileNo: store.folders.length + 1,
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            mainAxisExtent: 155,
          ),
          itemCount: store.folders.length,
          itemBuilder: (context, i) {
            final f = store.folders[i];
            return FolderPreviewCard(
              folder: f,
              tickets: store.ticketsIn(f.id),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FolderScreen(folder: f),
                ),
              ),
              onLongPress: () => openFolderWorkbench(
                context,
                store: store,
                folder: f,
                fileNo: i + 1,
                preview: store.ticketsIn(f.id),
              ),
            );
          },
        ),
      ),
    );
  }
}
