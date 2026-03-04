import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/decoy_vault_provider.dart';
import '../providers/auth_provider.dart';
import '../models/vault_item.dart';

class FakeNotesScreen extends StatefulWidget {
  const FakeNotesScreen({super.key});

  @override
  State<FakeNotesScreen> createState() => _FakeNotesScreenState();
}

class _FakeNotesScreenState extends State<FakeNotesScreen> {

  @override
  void initState() {
    super.initState();
    Provider.of<DecoyVaultProvider>(context, listen: false)
        .loadNotesItems();
  }

  void _addDummyNote() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Dummy Note"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: "Note Title",
                hintText: "e.g., Shopping List",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Note Content",
                hintText: "e.g., Milk, Eggs, Bread...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              final title = titleCtrl.text.isEmpty
                  ? "Note ${DateTime.now().millisecondsSinceEpoch}"
                  : titleCtrl.text;

              final content = contentCtrl.text.isEmpty
                  ? "Sample note content"
                  : contentCtrl.text;

              Provider.of<DecoyVaultProvider>(
                context,
                listen: false,
              ).addNotesItem(
                VaultItem(
                  id: DateTime.now()
                      .millisecondsSinceEpoch
                      .toString(),
                  name: title,
                  type: 'note',
                  content: content,
                  createdAt: DateTime.now(),
                  size: content.length,
                ),
              );

              Navigator.pop(ctx);
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  void _logout() {
    Provider.of<AuthProvider>(
      context,
      listen: false,
    ).logout();

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final decoyVault =
    Provider.of<DecoyVaultProvider>(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult:
          (didPop, result) {
        if (!didPop) _logout();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // 🚫 removes LEFT back arrow
          title: const Text("Notes"),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _logout,
            ),
          ],
        ),

        body: decoyVault.notesItems.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(Icons.note_outlined,
                  size: 80,
                  color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                "No notes yet",
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                "Tap + to add dummy notes",
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500]),
              ),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount:
          decoyVault.notesItems.length,
          itemBuilder: (ctx, i) {
            final item =
            decoyVault.notesItems[i];

            return Card(
              margin: const EdgeInsets.only(
                  bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                  Colors.amber[100],
                  child: const Icon(
                      Icons.note,
                      color: Colors.amber),
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(
                      fontWeight:
                      FontWeight.w600),
                ),
                subtitle: Text(
                  item.content ?? "",
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(
                      Icons.delete_outline),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) =>
                          AlertDialog(
                            title: const Text(
                                "Delete Note?"),
                            content: Text(
                                "Remove '${item.name}'?"),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(
                                        ctx),
                                child:
                                const Text(
                                    "Cancel"),
                              ),
                              FilledButton(
                                onPressed: () {
                                  decoyVault
                                      .removeNotesItem(
                                      item.id);
                                  Navigator.pop(
                                      ctx);
                                },
                                style: FilledButton
                                    .styleFrom(
                                    backgroundColor:
                                    Colors.red),
                                child:
                                const Text(
                                    "Delete"),
                              ),
                            ],
                          ),
                    );
                  },
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) =>
                        AlertDialog(
                          title: Text(
                              item.name),
                          content:
                          SingleChildScrollView(
                            child: Text(
                                item.content ??
                                    ""),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(
                                      ctx),
                              child:
                              const Text(
                                  "Close"),
                            ),
                          ],
                        ),
                  );
                },
              ),
            );
          },
        ),
        floatingActionButton:
        FloatingActionButton.extended(
          onPressed: _addDummyNote,
          icon: const Icon(Icons.add),
          label: const Text("Add Note"),
        ),
      ),
    );
  }
}
