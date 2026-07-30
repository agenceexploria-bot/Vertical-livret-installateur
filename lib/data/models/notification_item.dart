class NotificationItem {
  final String id;
  final String type;
  final String message;
  final bool lue;
  final DateTime createdAt;
  final String chantierReference;

  NotificationItem({
    required this.id,
    required this.type,
    required this.message,
    required this.lue,
    required this.createdAt,
    required this.chantierReference,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: json['id'] as String,
        type: json['type'] as String,
        message: json['message'] as String,
        lue: json['lue'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        chantierReference: json['chantierReference'] as String,
      );
}
