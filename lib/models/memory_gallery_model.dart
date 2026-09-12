/// Represents a memory album in the local gallery
class MemoryAlbum {
  final String id;
  final String name;
  final String? coverPhotoPath; // First photo or null
  final List<String> photoPaths; // Local file paths
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryAlbum({
    required this.id,
    required this.name,
    this.coverPhotoPath,
    required this.photoPaths,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemoryAlbum.fromJson(Map<String, dynamic> json) {
    return MemoryAlbum(
      id: json['id'] as String,
      name: json['name'] as String,
      coverPhotoPath: json['cover_photo_path'] as String?,
      photoPaths: (json['photo_paths'] as List?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cover_photo_path': coverPhotoPath,
        'photo_paths': photoPaths,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  MemoryAlbum copyWith({
    String? id,
    String? name,
    String? coverPhotoPath,
    List<String>? photoPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoryAlbum(
      id: id ?? this.id,
      name: name ?? this.name,
      coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
      photoPaths: photoPaths ?? this.photoPaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Add a new photo to the album
  MemoryAlbum addPhoto(String photoPath) {
    final newPhotos = List<String>.from(photoPaths)..insert(0, photoPath);
    return copyWith(
      photoPaths: newPhotos,
      coverPhotoPath: coverPhotoPath ?? photoPath,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove a photo from the album
  MemoryAlbum removePhoto(String photoPath) {
    final newPhotos = photoPaths.where((p) => p != photoPath).toList();
    return copyWith(
      photoPaths: newPhotos,
      coverPhotoPath: newPhotos.isNotEmpty ? newPhotos.first : null,
      updatedAt: DateTime.now(),
    );
  }

  /// Get photo count
  int get photoCount => photoPaths.length;

  /// Check if album is empty
  bool get isEmpty => photoPaths.isEmpty;
}

/// Represents a single photo in an album
class MemoryPhoto {
  final String id;
  final String albumId;
  final String localPath;
  final DateTime takenAt;
  final String? caption;

  const MemoryPhoto({
    required this.id,
    required this.albumId,
    required this.localPath,
    required this.takenAt,
    this.caption,
  });

  factory MemoryPhoto.fromJson(Map<String, dynamic> json) {
    return MemoryPhoto(
      id: json['id'] as String,
      albumId: json['album_id'] as String,
      localPath: json['local_path'] as String,
      takenAt: DateTime.parse(json['taken_at'] as String),
      caption: json['caption'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'album_id': albumId,
        'local_path': localPath,
        'taken_at': takenAt.toIso8601String(),
        'caption': caption,
      };
}