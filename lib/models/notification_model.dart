import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  loanRequest,
  loanApproved,
  loanRejected,
  salaryAdvanceRequest,
  salaryAdvanceApproved,
  salaryAdvanceRejected,
  expenseRequest,
  expenseApproved,
  expenseRejected,
  attendance,
  general,
  contract,
  probation,
}

class AppNotification {
  final String id;
  final String userId; // Who receives this notification
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data; // Extra data (loanId, employeeId, etc)

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'data': data,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.general,
      ),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      isRead: json['isRead'] ?? false,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }
}
