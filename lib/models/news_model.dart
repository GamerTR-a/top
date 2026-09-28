class NewsModel {
  final int id;
  final String title;
  final String summary;
  final String content;
  final String? imageUrl;
  final DateTime publishedAt;

  const NewsModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    this.imageUrl,
    required this.publishedAt,
  });

  factory NewsModel.fromApiJson(Map<String, dynamic> json) => NewsModel(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        content: json['content'] as String? ?? '',
        imageUrl: json['image_url'] as String?,
        publishedAt: json['published_at'] != null
            ? DateTime.parse(json['published_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toInsertJson() => {
        'title': title,
        'summary': summary,
        'content': content,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
        'published_at': publishedAt.toIso8601String(),
      };
}
