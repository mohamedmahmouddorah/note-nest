import 'package:floor/floor.dart';

@Entity(tableName: 'Notes')
class Note {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final String content;
  final double? latitude;
  final double? longitude;
  final String? address;

  final int createdAt;
  final int updatedAt;

  const Note({
    this.id,
    required this.content,
    this.latitude,
    this.longitude,
    this.address,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  bool get isEdited => updatedAt > createdAt;

  Note copyWith({
    int? id,
    String? content,
    double? latitude,
    double? longitude,
    String? address,
    int? createdAt,
    int? updatedAt,
    bool clearLocation = false,
  }) {
    return Note(
      id: id ?? this.id,
      content: content ?? this.content,
      latitude: clearLocation ? null : latitude ?? this.latitude,
      longitude: clearLocation ? null : longitude ?? this.longitude,
      address: clearLocation ? null : address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
