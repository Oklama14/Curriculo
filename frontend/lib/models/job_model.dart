import 'dart:convert';

class ScrapedJob {
  final String url;
  final String title;
  final String company;
  final String description;
  final DateTime extractedAt;

  ScrapedJob({
    required this.url,
    required this.title,
    required this.company,
    required this.description,
    required this.extractedAt,
  });

  factory ScrapedJob.fromJson(Map<String, dynamic> json) {
    return ScrapedJob(
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      company: json['company'] ?? '',
      description: json['description'] ?? '',
      extractedAt: json['extracted_at'] != null 
          ? DateTime.parse(json['extracted_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'company': company,
      'description': description,
      'extracted_at': extractedAt.toIso8601String(),
    };
  }

  static List<ScrapedJob> fromJsonList(String jsonString) {
    final List<dynamic> data = json.decode(jsonString);
    return data.map((item) => ScrapedJob.fromJson(item)).toList();
  }
}
