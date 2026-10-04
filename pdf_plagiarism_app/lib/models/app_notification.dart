enum NotificationType {
  reuploadRequested,
  reuploadCompleted,
  generalInfo,
}

/// Represents an in-app alert/notification sent between instructors and students.
class AppNotification {
  final String id;
  final String recipientUserId;
  final String senderUserId;
  final String senderName;
  final String title;
  final String message;
  final String? documentId;
  final String? documentName;
  final String? assignmentTag;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.senderUserId,
    this.senderName = 'Instructor',
    required this.title,
    required this.message,
    this.documentId,
    this.documentName,
    this.assignmentTag,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'recipientUserId': recipientUserId,
        'senderUserId': senderUserId,
        'senderName': senderName,
        'title': title,
        'message': message,
        'documentId': documentId,
        'documentName': documentName,
        'assignmentTag': assignmentTag,
        'type': type.name,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] as String,
        recipientUserId: map['recipientUserId'] as String,
        senderUserId: map['senderUserId'] as String,
        senderName: map['senderName'] as String? ?? 'Instructor',
        title: map['title'] as String,
        message: map['message'] as String,
        documentId: map['documentId'] as String?,
        documentName: map['documentName'] as String?,
        assignmentTag: map['assignmentTag'] as String?,
        type: NotificationType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => NotificationType.generalInfo,
        ),
        isRead: map['isRead'] as bool? ?? false,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  AppNotification copyWith({
    bool? isRead,
    String? message,
    String? documentName,
  }) =>
      AppNotification(
        id: id,
        recipientUserId: recipientUserId,
        senderUserId: senderUserId,
        senderName: senderName,
        title: title,
        message: message ?? this.message,
        documentId: documentId,
        documentName: documentName ?? this.documentName,
        assignmentTag: assignmentTag,
        type: type,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
