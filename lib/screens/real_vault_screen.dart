
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:secure_vault/providers/vault_provider.dart';
import 'package:secure_vault/providers/auth_provider.dart';
import 'package:secure_vault/models/vault_item.dart';
import 'package:secure_vault/services/encryption_service.dart';
import 'package:secure_vault/widgets/pdf_preview.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class RealVaultScreen extends StatefulWidget {
  const RealVaultScreen({super.key});

  @override
  State<RealVaultScreen> createState() => _RealVaultScreenState();
}

class _RealVaultScreenState extends State<RealVaultScreen>
    with WidgetsBindingObserver {
  bool _isAddingFile = false;

  // ── File type sets ────────────────────────────────────────────────────────────
  static const _imageExts = {
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'
  };
  static const _videoExts = {'.mp4', '.mov', '.avi', '.mkv'};
  static const _audioExts = {
    '.mp3', '.aac', '.wav', '.flac', '.ogg', '.m4a'
  };

  bool _isMediaFile(String name) {
    final lower = name.toLowerCase();
    return _imageExts.any(lower.endsWith) ||
        _videoExts.any(lower.endsWith) ||
        _audioExts.any(lower.endsWith);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Provider.of<VaultProvider>(context, listen: false).loadVaultItems();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_isAddingFile) {
      _logout();
    }
    if (state == AppLifecycleState.resumed) {
      _isAddingFile = false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Future<Directory> _vaultDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(dir.path, 'secure_vault'));
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
    return vaultDir;
  }

  Future<String> _encryptedVaultPath(String fileName) async {
    final vaultDir = await _vaultDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(vaultDir.path, '${stamp}_$fileName.enc');
  }

  void _logout() {
    if (mounted) {
      Provider.of<VaultProvider>(context, listen: false).clearItems();
      Provider.of<AuthProvider>(context, listen: false).logout();
      Navigator.of(context).pop();
    }
  }

  // ── Decrypt .enc file ─────────────────────────────────────────────────────────
  // Always reads from disk — never from item.content — to avoid double-encryption.
  Future<String?> _decryptEncFile(VaultItem item) async {
    if (item.path == null || !await File(item.path!).exists()) {
      print('❌ .enc file not found: ${item.path}');
      return null;
    }
    final encService = EncryptionService();
    final encryptedContent = await File(item.path!).readAsString();
    final plainBase64 = await encService.decryptData(encryptedContent);
    if (encService.isEncrypted(plainBase64)) {
      print('❌ Decryption returned still-encrypted data');
      return null;
    }
    print('✅ .enc file decrypted successfully');
    return plainBase64;
  }

  // ── Delete original file ──────────────────────────────────────────────────────
  // Media  → photo_manager gallery deletion.
  // Others → delete the FilePicker cache copy only (OS restriction for documents).
  Future<void> _deleteOriginalFile(String fileName, String cachePath) async {
    if (_isMediaFile(fileName)) {
      final permission = await PhotoManager.requestPermissionExtend();
      if (permission.isAuth || permission.hasAccess) {
        final albums = await PhotoManager.getAssetPathList(
          type: RequestType.all,
          filterOption: FilterOptionGroup(
            imageOption: const FilterOption(
                needTitle: true,
                sizeConstraint: SizeConstraint(ignoreSize: true)),
            videoOption: const FilterOption(
                needTitle: true,
                sizeConstraint: SizeConstraint(ignoreSize: true)),
            audioOption: const FilterOption(
                needTitle: true,
                sizeConstraint: SizeConstraint(ignoreSize: true)),
          ),
        );
        for (final album in albums) {
          final count = await album.assetCountAsync;
          if (count == 0) continue;
          final assets =
          await album.getAssetListRange(start: 0, end: count);
          for (final asset in assets) {
            final title = await asset.titleAsync;
            if (title == fileName) {
              await PhotoManager.editor.deleteWithIds([asset.id]);
              print('🗑️ Media original deleted from gallery: $fileName');
              return;
            }
          }
        }
        print('⚠️ Media not found in gallery: $fileName');
      } else {
        print('⚠️ Gallery permission denied');
      }
    }
    // Always clean up the FilePicker cache copy.
    final cacheFile = File(cachePath);
    if (await cacheFile.exists()) {
      await cacheFile.delete();
      print('🗑️ Cache copy deleted: $cachePath');
    }
  }

  // ── Add File ──────────────────────────────────────────────────────────────────

  void _addFile() async {
    _isAddingFile = true;
    final result = await FilePicker.platform.pickFiles(
      withData: false,
      withReadStream: false,
    );
    _isAddingFile = false;

    if (result == null || result.files.first.path == null) return;

    final file = result.files.first;
    final cachePath = file.path!;

    if (!mounted) return;

    // ── Confirm dialog ─────────────────────────────────────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.lock_outline, color: Colors.blue),
          SizedBox(width: 12),
          Text('Encrypt & Move to Vault?'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(file.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${(file.size / 1024).toStringAsFixed(2)} KB',
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.red.withValues(alpha: 0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The original file will be permanently deleted '
                          'and an encrypted copy saved to the vault.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Encrypt & Move')),
        ],
      ),
    );

    if (confirmed != true) return;

    // ── Loading overlay ────────────────────────────────────────────────────────
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Encrypting & removing original…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 1. Read bytes → base64 → encrypt → write .enc.
      final fileBytes = await File(cachePath).readAsBytes();
      final base64Content = base64Encode(fileBytes);
      final encService = EncryptionService();
      final encryptedContent =
      await encService.encryptData(base64Content);
      final vaultFilePath = await _encryptedVaultPath(file.name);
      await File(vaultFilePath).writeAsString(encryptedContent);
      print('✅ .enc written: $vaultFilePath');

      // 2. Delete original.
      await _deleteOriginalFile(file.name, cachePath);

      // 3. Register in vault. content is null — decryption uses .enc file.
      final itemId = DateTime.now().millisecondsSinceEpoch.toString();
      if (!mounted) return;
      Provider.of<VaultProvider>(context, listen: false).addItem(
        VaultItem(
          id: itemId,
          name: file.name,
          type: 'file',
          path: vaultFilePath,
          originalPath: null,
          createdAt: DateTime.now(),
          size: file.size,
          content: null,
        ),
      );

      // 4. Close loading.
      if (!mounted) return;
      Navigator.pop(context);

      // 5. Feedback.
      if (_isMediaFile(file.name)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
          Text('🔒 ${file.name} encrypted. Original deleted.'),
          duration: const Duration(seconds: 4),
        ));
      } else {
        // Documents: original cannot be auto-deleted → show polished notice.
        await _showDocumentImportNotice(file.name);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Error: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ── Document import notice ────────────────────────────────────────────────────

  Future<void> _showDocumentImportNotice(String fileName) async {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock,
                    size: 32, color: colorScheme.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                'File Encrypted Successfully',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                fileName,
                style:
                TextStyle(fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                      width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Manual step required',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.amber[800],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    const Text(
                      'Your file is safely encrypted inside the vault.',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Due to Android/iOS security restrictions, documents '
                          'cannot be deleted automatically. Please manually '
                          'delete the original from your Downloads folder or '
                          'wherever it was stored.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Got it',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Restore file ──────────────────────────────────────────────────────────────

  Future<void> _restoreFile(VaultItem item) async {
    // No PIN — authenticated by being inside the vault.

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Decrypting…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 1. Decrypt from .enc file.
      final plainBase64 = await _decryptEncFile(item);
      if (plainBase64 == null) {
        throw Exception(
            'Decryption failed. The vault file may be missing or corrupted.');
      }

      // 2. Decode bytes.
      final fileBytes = base64Decode(plainBase64);
      final nameLower = item.name.toLowerCase();

      // Close loading before showing any picker / gallery UI.
      if (!mounted) return;
      Navigator.pop(context);

      if (_isMediaFile(item.name)) {
        // ── Media → save back to gallery via photo_manager ───────────────────
        final permission =
        await PhotoManager.requestPermissionExtend();
        if (!permission.isAuth && !permission.hasAccess) {
          throw Exception('Gallery permission denied.');
        }

        final tempDir = await getTemporaryDirectory();
        final tempFile = File(p.join(tempDir.path, item.name));
        await tempFile.writeAsBytes(fileBytes);

        AssetEntity? saved;
        if (_imageExts.any(nameLower.endsWith)) {
          saved = await PhotoManager.editor
              .saveImageWithPath(tempFile.path, title: item.name);
          print('✅ Image restored to gallery');
        } else if (_videoExts.any(nameLower.endsWith)) {
          saved = await PhotoManager.editor
              .saveVideo(tempFile, title: item.name);
          print('✅ Video restored to gallery');
        } else if (_audioExts.any(nameLower.endsWith)) {
          // photo_manager doesn't support audio saving on all platforms —
          // fall through to the document save-picker path below.
          await _saveDocumentWithPicker(
              fileName: item.name, fileBytes: fileBytes);
          if (await tempFile.exists()) await tempFile.delete();
          await _cleanupAfterRestore(item);
          return;
        }

        if (await tempFile.exists()) await tempFile.delete();

        if (saved == null) {
          throw Exception('Could not save file to gallery.');
        }
      } else {
        // ── Documents (PDF, CSV, XLSX, etc.) → native save picker ───────────
        // FilePicker.saveFile() opens the OS "Save to…" dialog so the user
        // picks exactly where to put the file. This is the only reliable way
        // to write to a user-visible folder on both Android and iOS.
        await _saveDocumentWithPicker(
            fileName: item.name, fileBytes: fileBytes);
      }

      await _cleanupAfterRestore(item);
    } catch (e) {
      // Close loading if still open.
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Restore failed: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  // ── Save document using native file-save picker ───────────────────────────────
  // Opens the OS "Save to…" sheet so the user chooses the destination folder.
  Future<void> _saveDocumentWithPicker({
    required String fileName,
    required List<int> fileBytes,
  }) async {
    // Write bytes to a temp file first — FilePicker.saveFile needs a bytes list.
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(p.join(tempDir.path, fileName));
    await tempFile.writeAsBytes(fileBytes);

    // Derive MIME type from extension for better OS handling.
    final ext = p.extension(fileName).toLowerCase().replaceFirst('.', '');
    final mimeType = _mimeForExt(ext);

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ${fileName} to…',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [ext.isNotEmpty ? ext : '*'],
      bytes: Uint8List.fromList(fileBytes),
    );

    // Clean up temp file.
    if (await tempFile.exists()) await tempFile.delete();

    if (savedPath == null) {
      // User cancelled the picker — treat as a cancellation, not an error.
      throw _RestoreCancelledException();
    }

    print('✅ Document saved to: $savedPath');
  }

  String _mimeForExt(String ext) {
    const map = {
      'pdf': 'application/pdf',
      'csv': 'text/csv',
      'xlsx':
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'xls': 'application/vnd.ms-excel',
      'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'doc': 'application/msword',
      'txt': 'text/plain',
      'zip': 'application/zip',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  // ── Cleanup after successful restore ─────────────────────────────────────────

  Future<void> _cleanupAfterRestore(VaultItem item) async {
    // Delete .enc file.
    if (item.path != null && await File(item.path!).exists()) {
      await File(item.path!).delete();
      print('🗑️ .enc file deleted');
    }
    // Remove from vault registry.
    if (!mounted) return;
    Provider.of<VaultProvider>(context, listen: false)
        .removeItem(item.id);

    final destination =
    _isMediaFile(item.name) ? 'gallery' : 'chosen folder';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ ${item.name} restored to $destination'),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Delete permanently ────────────────────────────────────────────────────────

  void _deleteFile(VaultItem item) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.delete_forever, color: Colors.red),
          SizedBox(width: 12),
          Text('Remove from Vault'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${item.name}',
                style:
                const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (item.type == 'file')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"Restore & Remove" decrypts the file and lets '
                            'you save it anywhere on your device. '
                            '"Delete" wipes it permanently from the vault.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel')),
          if (item.type == 'file')
            OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'restore'),
                child: const Text('Restore & Remove')),
          FilledButton(
            style:
            FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (result == 'restore') {
      await _restoreFile(item);
    } else if (result == 'delete') {
      if (item.path != null && await File(item.path!).exists()) {
        await File(item.path!).delete();
      }
      if (!mounted) return;
      Provider.of<VaultProvider>(context, listen: false)
          .removeItem(item.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
        Text('🗑️ ${item.name} permanently deleted from vault'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ── Add Note ──────────────────────────────────────────────────────────────────

  void _addNote() {
    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Note Name',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Note Content',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Provider.of<VaultProvider>(context, listen: false)
                  .addItem(VaultItem(
                id: DateTime.now()
                    .millisecondsSinceEpoch
                    .toString(),
                name: nameCtrl.text.isEmpty
                    ? 'Note ${DateTime.now().millisecondsSinceEpoch}'
                    : nameCtrl.text,
                type: 'note',
                content: contentCtrl.text,
                createdAt: DateTime.now(),
                size: contentCtrl.text.length,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addSecureNote() {

  final title = TextEditingController();
  final note = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Secure Note"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: "Title"),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: note,
            maxLines: 4,
            decoration: const InputDecoration(labelText: "Note"),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel")),
        FilledButton(
          onPressed: () {

            Provider.of<VaultProvider>(context, listen: false)
                .addItem(
              VaultItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: title.text,
                type: 'secure_note',
                content: note.text,
                createdAt: DateTime.now(),
                size: note.text.length,
              ),
            );

            Navigator.pop(ctx);
          },
          child: const Text("Save"),
        )
      ],
    ),
  );
}

void _addCard() {

  final name = TextEditingController();
  final number = TextEditingController();
  final expiry = TextEditingController();
  final cvv = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Debit / Credit Card"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: "Card Name"),
          ),

          TextField(
            controller: number,
            decoration: const InputDecoration(labelText: "Card Number"),
            keyboardType: TextInputType.number,
          ),

          TextField(
            controller: expiry,
            decoration: const InputDecoration(labelText: "Expiry"),
          ),

          TextField(
            controller: cvv,
            obscureText: true,
            decoration: const InputDecoration(labelText: "CVV"),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel")),
        FilledButton(
          onPressed: () {

            final data = jsonEncode({
              "number": number.text,
              "expiry": expiry.text,
              "cvv": cvv.text
            });

            Provider.of<VaultProvider>(context, listen: false)
                .addItem(
              VaultItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name.text,
                type: 'card',
                content: data,
                createdAt: DateTime.now(),
                size: data.length,
              ),
            );

            Navigator.pop(ctx);
          },
          child: const Text("Save"),
        )
      ],
    ),
  );
}

void _addWebsite() {

  final site = TextEditingController();
  final url = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Website Login"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          TextField(
            controller: site,
            decoration: const InputDecoration(labelText: "Website Name"),
          ),

          TextField(
            controller: url,
            decoration: const InputDecoration(labelText: "URL"),
          ),

          TextField(
            controller: username,
            decoration: const InputDecoration(labelText: "Username"),
          ),

          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Password"),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel")),
        FilledButton(
          onPressed: () {

            final data = jsonEncode({
              "url": url.text,
              "username": username.text,
              "password": password.text
            });

            Provider.of<VaultProvider>(context, listen: false)
                .addItem(
              VaultItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: site.text,
                type: 'password',
                content: data,
                createdAt: DateTime.now(),
                size: data.length,
              ),
            );

            Navigator.pop(ctx);
          },
          child: const Text("Save"),
        )
      ],
    ),
  );
}
  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vault = Provider.of<VaultProvider>(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          Provider.of<VaultProvider>(context, listen: false)
              .clearItems();
          Provider.of<AuthProvider>(context, listen: false).logout();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Secure Vault'),
          centerTitle: true,
          actions: [
            IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: _logout),
          ],
        ),
        body: vault.items.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline,
                  size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Your vault is empty',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text('Tap + to add files or notes',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500])),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vault.items.length,
          itemBuilder: (ctx, i) {
            final item = vault.items[i];
            final isFile = item.type == 'file';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: isFile
                      ? Icon(Icons.insert_drive_file,
                      color: Theme.of(context)
                          .colorScheme
                          .primary)
                      : const Icon(Icons.note,
                      color: Colors.blue),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                    ),
                    if (isFile)
                      const Tooltip(
                        message: 'AES-256-GCM Encrypted',
                        child: Icon(Icons.lock,
                            size: 14,
                            color: Colors.green),
                      ),
                  ],
                ),
                subtitle: Text(
                  isFile
                      ? 'Tap to preview'
                      : (item.content ?? ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'restore') {
                      _restoreFile(item);
                    } else if (value == 'delete') {
                      _deleteFile(item);
                    }
                  },
                  itemBuilder: (_) => [
                    if (isFile)
                      const PopupMenuItem(
                        value: 'restore',
                        child: Row(children: [
                          Icon(Icons.restore,
                              size: 18,
                              color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Restore & Remove'),
                        ]),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete,
                            size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Permanently'),
                      ]),
                    ),
                  ],
                ),
                // Tap → decrypt and preview. No PIN required.
                onTap: () async {
                  if (isFile) {
                    if (!context.mounted) return;

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text('Decrypting…'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    final plainBase64 =
                    await _decryptEncFile(item);

                    if (!context.mounted) return;
                    Navigator.pop(context);

                    if (plainBase64 == null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                        content: Text(
                            '❌ Could not decrypt file. The vault file may be missing.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ));
                      return;
                    }

                    if (!context.mounted) return;
                    _showFilePreview(
                        context, item, plainBase64);
                  } else {
                    _showFilePreview(
                        context, item, item.content ?? '');
                  }
                },
              ),
            );
          },
        ),
        floatingActionButton: SpeedDial(
          icon: Icons.add,
          activeIcon: Icons.close,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          spacing: 12,
          spaceBetweenChildren: 12,
          overlayOpacity: 0.2,
          children: [

            SpeedDialChild(
              child: const Icon(Icons.note_alt),
              label: 'Secure Note',
              onTap: _addSecureNote,
            ),

            SpeedDialChild(
              child: const Icon(Icons.credit_card),
              label: 'Debit / Credit Card',
              onTap: _addCard,
            ),

            SpeedDialChild(
              child: const Icon(Icons.language),
              label: 'Website Login',
              onTap: _addWebsite,
            ),

            SpeedDialChild(
              child: const Icon(Icons.lock_outline),
              label: 'Encrypt File',
              onTap: _addFile,
            ),

          ],
        ),
      ),
    );
  }

void _showFilePreview(
    BuildContext context, VaultItem item, String content) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.type == 'file')
                    const Tooltip(
                      message: 'AES-256-GCM Encrypted',
                      child: Icon(Icons.lock, size: 18, color: Colors.green),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Preview Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _buildFilePreviewContent(item, content),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildFilePreviewContent(VaultItem item, String content) {
  final name = item.name.toLowerCase();

  // ── Image Preview ──
  if (_imageExts.any(name.endsWith)) {
    try {
      return Center(
        child: Image.memory(
          base64Decode(content),
          fit: BoxFit.contain,
          height: MediaQuery.of(context).size.height * 0.65,
        ),
      );
    } catch (e) {
      return Text('Could not decode image: $e');
    }
  }

  // ── PDF Preview ──
  if (name.endsWith('.pdf')) {
    try {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: PdfPreview(
          pdfBytes: base64Decode(content),
          fileName: item.name,
        ),
      );
    } catch (e) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.picture_as_pdf, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(item.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Error loading PDF: $e',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      );
    }
  }
  if (item.type == 'password' ||
    item.type == 'card' ||
    item.type == 'secure_note') {

  final data = jsonDecode(content);

  return StatefulBuilder(
    builder: (context, setState) {

      Map<String,bool> hidden = {
        "password": true,
        "cvv": true,
      };

      Widget row(String key,String value){

        bool secret = key=="password" || key=="cvv";

        return Padding(
          padding: const EdgeInsets.symmetric(vertical:6),
          child: Row(
            children: [

              SizedBox(
                width:90,
                child: Text(
                  "$key:",
                  style: const TextStyle(fontWeight:FontWeight.bold),
                ),
              ),

              Expanded(
                child: Text(
                  secret && hidden[key]==true
                      ? "••••••"
                      : value,
                ),
              ),

              if(secret)
                IconButton(
                  icon: Icon(
                    hidden[key]==true
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed:(){
                    setState(() {
                      hidden[key] = !(hidden[key] ?? true);
                    });
                  },
                ),

              IconButton(
                icon: const Icon(Icons.copy),
                onPressed:(){
                  Clipboard.setData(ClipboardData(text:value));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                      const SnackBar(content:Text("Copied")));
                },
              )
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:data.entries
            .map<Widget>((e)=>row(e.key,e.value.toString()))
            .toList(),
      );
    },
  );
}
  // ── Generic File Preview ──
  if (item.type == 'file') {
    final ext = item.name.contains('.')
        ? item.name.split('.').last.toUpperCase()
        : 'FILE';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.insert_drive_file, size: 80, color: Colors.blue[300]),
        const SizedBox(height: 16),
        Text(
          item.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'File type: $ext',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        Text(
          'Size: ${(item.size / 1024).toStringAsFixed(2)} KB',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 15, color: Colors.orange),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Use "Restore & Remove" from the ⋮ menu to save this file.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Note Preview ──
  final display = content.length > 5000
      ? '${content.substring(0, 5000)}\n\n… (truncated)'
      : content;

  return Text(display, style: const TextStyle(fontSize: 14));
  }
}
// ── Internal exception for user-cancelled save picker ────────────────────────
class _RestoreCancelledException implements Exception {
  @override
  String toString() => 'Restore cancelled by user.';
}
