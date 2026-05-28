import 'dart:convert';

class HistoryItem {
  final String id;
  final String timestamp;
  final String jobDescription;
  final String diff;
  final String? pdfUrl;
  final String? texUrl;

  HistoryItem({
    required this.id,
    required this.timestamp,
    required this.jobDescription,
    required this.diff,
    this.pdfUrl,
    this.texUrl,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] ?? '',
      timestamp: json['timestamp'] ?? '',
      jobDescription: json['job_description'] ?? '',
      diff: json['diff'] ?? '',
      pdfUrl: json['pdf_url'],
      texUrl: json['tex_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'job_description': jobDescription,
      'diff': diff,
      'pdf_url': pdfUrl,
      'tex_url': texUrl,
    };
  }

  static List<HistoryItem> fromJsonList(String jsonString) {
    final List<dynamic> data = json.decode(jsonString);
    return data.map((item) => HistoryItem.fromJson(item)).toList();
  }
}
