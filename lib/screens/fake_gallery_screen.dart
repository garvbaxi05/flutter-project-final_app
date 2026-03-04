import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../providers/decoy_vault_provider.dart';
import '../providers/auth_provider.dart';
import '../models/vault_item.dart';

class FakeGalleryScreen extends StatefulWidget {
  const FakeGalleryScreen({super.key});

  @override
  State<FakeGalleryScreen> createState() => _FakeGalleryScreenState();
}

class _FakeGalleryScreenState extends State<FakeGalleryScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    Provider.of<DecoyVaultProvider>(context, listen: false)
        .loadGalleryItems();
  }

  Future<String> _storeImageSecurely(XFile image) async {
    final dir = await getApplicationDocumentsDirectory();
    final galleryDir =
    Directory(p.join(dir.path, 'fake_gallery'));

    if (!await galleryDir.exists()) {
      await galleryDir.create(recursive: true);
    }

    final newPath = p.join(
      galleryDir.path,
      '${DateTime.now().millisecondsSinceEpoch}_${image.name}',
    );

    final bytes = await image.readAsBytes();
    await File(newPath).writeAsBytes(bytes, flush: true);

    return newPath;
  }

  void _addImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Photo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from Gallery"),
              onTap: () =>
                  Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take Photo"),
              onTap: () =>
                  Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text("Add Dummy Entry"),
              onTap: () {
                Navigator.pop(ctx);
                _addDummyPhoto();
              },
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image =
      await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      final storedPath =
      await _storeImageSecurely(image);

      final imageBytes =
      await image.readAsBytes();
      final base64Content =
      base64Encode(imageBytes);

      final fileName =
          image.name.split('.').first;

      if (!mounted) return;

      Provider.of<DecoyVaultProvider>(
        context,
        listen: false,
      ).addGalleryItem(
        VaultItem(
          id: DateTime.now()
              .millisecondsSinceEpoch
              .toString(),
          name: fileName,
          type: 'image',
          path: storedPath,
          createdAt: DateTime.now(),
          size: imageBytes.length,
          content: base64Content,
        ),
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
            content:
            Text('Photo added successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
            content:
            Text('Error adding photo: $e')),
      );
    }
  }

  void _addDummyPhoto() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Dummy Photo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
              const InputDecoration(
                labelText: "Photo Name",
                hintText:
                "e.g., Vacation 2024",
                border:
                OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "This adds a fake photo entry to make the gallery look authentic.",
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx),
              child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              final name =
              nameCtrl.text.isEmpty
                  ? "Photo ${DateTime.now().millisecondsSinceEpoch}"
                  : nameCtrl.text;

              Provider.of<
                  DecoyVaultProvider>(
                context,
                listen: false,
              ).addGalleryItem(
                VaultItem(
                  id: DateTime.now()
                      .millisecondsSinceEpoch
                      .toString(),
                  name: name,
                  type: 'image',
                  createdAt:
                  DateTime.now(),
                  size: 0,
                  content:
                  "dummy_photo",
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

  void _showImagePreview(VaultItem item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            AppBar(
              title: Text(item.name),
              automaticallyImplyLeading:
              false,
              actions: [
                IconButton(
                  icon:
                  const Icon(Icons.close),
                  onPressed: () =>
                      Navigator.pop(ctx),
                ),
              ],
            ),
            Flexible(
              child:
              SingleChildScrollView(
                child: item.content ==
                    "dummy_photo"
                    ? Padding(
                  padding:
                  const EdgeInsets
                      .all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.image,
                          size: 100,
                          color: Colors
                              .grey[400]),
                      const SizedBox(
                          height: 16),
                      const Text(
                        "Dummy Photo Entry",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight
                                .w600),
                      ),
                    ],
                  ),
                )
                    : Image.memory(
                  base64Decode(
                      item.content!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
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
    Provider.of<DecoyVaultProvider>(
        context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult:
          (didPop, result) {
        if (!didPop) _logout();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // 🚫 removes left back arrow
          title: const Text("Gallery"),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _logout,
            ),
          ],
        ),

        body: decoyVault
            .galleryItems.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment
                .center,
            children: [
              Icon(
                  Icons
                      .photo_library_outlined,
                  size: 80,
                  color: Colors
                      .grey[400]),
              const SizedBox(
                  height: 16),
              Text(
                "No photos yet",
                style: TextStyle(
                    fontSize: 18,
                    color: Colors
                        .grey[600]),
              ),
              const SizedBox(
                  height: 8),
              Text(
                "Tap + to add photos",
                style: TextStyle(
                    fontSize: 14,
                    color: Colors
                        .grey[500]),
              ),
            ],
          ),
        )
            : GridView.builder(
          padding:
          const EdgeInsets
              .all(16),
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing:
            8,
            mainAxisSpacing: 8,
          ),
          itemCount:
          decoyVault
              .galleryItems
              .length,
          itemBuilder:
              (ctx, i) {
            final item =
            decoyVault
                .galleryItems[i];

            return GestureDetector(
              onTap: () =>
                  _showImagePreview(
                      item),
              onLongPress: () {
                showDialog(
                  context:
                  context,
                  builder:
                      (ctx) =>
                      AlertDialog(
                        title:
                        const Text(
                            "Delete Photo?"),
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
                            onPressed:
                                () async {
                              if (item.path !=
                                  null &&
                                  await File(
                                      item.path!)
                                      .exists()) {
                                await File(
                                    item.path!)
                                    .delete();
                              }

                              decoyVault
                                  .removeGalleryItem(
                                  item.id);

                              if (!mounted){}
                                return;


                            },
                            style: FilledButton
                                .styleFrom(
                                backgroundColor:
                                Colors
                                    .red),
                            child:
                            const Text(
                                "Delete"),
                          ),
                        ],
                      ),
                );
              },
              child: Container(
                decoration:
                BoxDecoration(
                  color:
                  Colors.grey[300],
                  borderRadius:
                  BorderRadius
                      .circular(8),
                ),
                child: Stack(
                  children: [
                    if (item.content ==
                        "dummy_photo")
                      Center(
                        child: Icon(
                            Icons.image,
                            size: 40,
                            color: Colors
                                .grey[
                            500]),
                      )
                    else
                      ClipRRect(
                        borderRadius:
                        BorderRadius
                            .circular(
                            8),
                        child: Image
                            .memory(
                          base64Decode(
                              item.content!),
                          fit:
                          BoxFit
                              .cover,
                          width: double
                              .infinity,
                          height: double
                              .infinity,
                          errorBuilder:
                              (context,
                              error,
                              stackTrace) {
                            return Center(
                              child: Icon(
                                  Icons
                                      .broken_image,
                                  size: 40,
                                  color: Colors
                                      .grey[
                                  500]),
                            );
                          },
                        ),
                      ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      right: 4,
                      child:
                      Container(
                        padding: const EdgeInsets
                            .symmetric(
                            horizontal:
                            4,
                            vertical:
                            2),
                        decoration:
                        BoxDecoration(
                          color: Colors
                              .black54,
                          borderRadius:
                          BorderRadius
                              .circular(
                              4),
                        ),
                        child: Text(
                          item.name,
                          style:
                          const TextStyle(
                              color: Colors
                                  .white,
                              fontSize:
                              10),
                          maxLines: 1,
                          overflow:
                          TextOverflow
                              .ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButton:
        FloatingActionButton.extended(
          onPressed: _addImage,
          icon: const Icon(
              Icons.add_photo_alternate),
          label:
          const Text("Add Photo"),
        ),
      ),
    );
  }
}
