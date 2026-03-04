class VaultItem {
  final String id;
  final String name;
  final String type;
  final String? path;
  final String? originalPath; // source path before it was moved into the vault
  final DateTime createdAt;
  final int size;
  String? content;

  VaultItem({
    required this.id,
    required this.name,
    required this.type,
    this.path,
    this.originalPath,
    required this.createdAt,
    required this.size,
    this.content,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'path': path,
    'originalPath': originalPath,
    'createdAt': createdAt.toIso8601String(),
    'size': size,
    'content': content,
  };

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
    id: json['id'],
    name: json['name'],
    type: json['type'],
    path: json['path'],
    originalPath: json['originalPath'],
    createdAt: DateTime.parse(json['createdAt']),
    size: json['size'],
    content: json['content'],
  );
}