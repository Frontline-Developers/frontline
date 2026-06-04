import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/my_report.dart';

class MyReportModel {
  final String id;
  final String title;
  final String body;
  final String category;
  final String location;
  final List<String> photos;
  final String status;
  final int confirms;
  final int flags;
  final int views;
  final String token;
  final DateTime submittedAt;
  final int commentCount;

  const MyReportModel({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.location,
    required this.photos,
    required this.status,
    required this.confirms,
    required this.flags,
    required this.views,
    required this.token,
    required this.submittedAt,
    required this.commentCount,
  });

  factory MyReportModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
    String localToken,
  ) {
    final ts = data['createdAt'] as Timestamp? ?? Timestamp.now();
    final desc = (data['description'] as String?) ?? '';
    final rawUrls = data['mediaUrls'];
    final photos = (rawUrls is List)
        ? rawUrls.map((e) => e.toString()).toList()
        : <String>[];
    // Use the first line of the description as the headline title so the
    // detail screen doesn't render the full text twice.
    final firstLine = desc.split('\n').first.trim();

    return MyReportModel(
      id: id,
      title: firstLine.isNotEmpty ? firstLine : desc,
      body: desc,
      category: (data['category'] as String?) ?? '',
      location: (data['locationLabel'] as String?) ?? '',
      photos: photos,
      status: (data['status'] as String?) ?? 'pending',
      confirms: (data['confirmCount'] as num?)?.toInt() ?? 0,
      flags: (data['disputeCount'] as num?)?.toInt() ?? 0,
      views: (data['viewCount'] as num?)?.toInt() ?? 0,
      token: localToken,
      submittedAt: ts.toDate(),
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  MyReport toEntity() => MyReport(
    id: id,
    title: title,
    body: body,
    category: category,
    location: location,
    photos: photos,
    status: status,
    confirms: confirms,
    flags: flags,
    views: views,
    token: token,
    submittedAt: submittedAt,
    commentCount: commentCount,
  );
}
