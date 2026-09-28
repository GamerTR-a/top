class JobListingModel {
  final int id;
  final String title;
  final String description;
  final DateTime publishedAt;

  const JobListingModel({
    required this.id,
    required this.title,
    required this.description,
    required this.publishedAt,
  });

  factory JobListingModel.fromApiJson(Map<String, dynamic> json) =>
      JobListingModel(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        publishedAt: json['published_at'] != null
            ? DateTime.parse(json['published_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toInsertJson() => {
        'title': title,
        'description': description,
        'published_at': publishedAt.toIso8601String(),
      };
}
