class Reminder {
  final String id;
  final String orderId;
  final String? orderItemId;
  final String type;
  final DateTime remindAt;
  final String? remindBefore;
  final String? message;
  final bool isRead;
  final bool isDismissed;
  final DateTime createdAt;

  Reminder({
    required this.id,
    required this.orderId,
    this.orderItemId,
    required this.type,
    required this.remindAt,
    this.remindBefore,
    this.message,
    this.isRead = false,
    this.isDismissed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_id': orderId,
        'order_item_id': orderItemId,
        'type': type,
        'remind_at': remindAt.toIso8601String(),
        'remind_before': remindBefore,
        'message': message,
        'is_read': isRead ? 1 : 0,
        'is_dismissed': isDismissed ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Reminder.fromMap(Map<String, dynamic> map) => Reminder(
        id: map['id'] as String,
        orderId: map['order_id'] as String,
        orderItemId: map['order_item_id'] as String?,
        type: map['type'] as String,
        remindAt: DateTime.parse(map['remind_at'] as String),
        remindBefore: map['remind_before'] as String?,
        message: map['message'] as String?,
        isRead: (map['is_read'] as int?) == 1,
        isDismissed: (map['is_dismissed'] as int?) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Reminder copyWith({
    String? id,
    String? orderId,
    String? orderItemId,
    String? type,
    DateTime? remindAt,
    String? remindBefore,
    String? message,
    bool? isRead,
    bool? isDismissed,
  }) =>
      Reminder(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        orderItemId: orderItemId ?? this.orderItemId,
        type: type ?? this.type,
        remindAt: remindAt ?? this.remindAt,
        remindBefore: remindBefore ?? this.remindBefore,
        message: message ?? this.message,
        isRead: isRead ?? this.isRead,
        isDismissed: isDismissed ?? this.isDismissed,
        createdAt: createdAt,
      );

  static const typeLabels = {
    'balance': '尾款提醒',
    'shipping': '发货提醒',
    'arrival': '到货提醒',
    'duplicate_check': '重复购买提醒',
  };

  String get typeLabel => typeLabels[type] ?? type;

  int get urgencyLevel {
    final diff = remindAt.difference(DateTime.now());
    if (diff.inDays <= 0) return 4;
    if (diff.inDays <= 1) return 3;
    if (diff.inDays <= 3) return 2;
    return 1;
  }
}