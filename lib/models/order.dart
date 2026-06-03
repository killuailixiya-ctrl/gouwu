class Order {
  final String id;
  final String platformId;
  final String? orderNo;
  final double totalAmount;
  final String status;
  final bool isPresell;
  final double? depositAmount;
  final DateTime? depositTime;
  final DateTime? balanceDeadline;
  final DateTime orderTime;
  final String? rawSource;
  final String? rawText;
  final String? notes;
  final String? screenshotPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.platformId,
    this.orderNo,
    this.totalAmount = 0,
    required this.status,
    this.isPresell = false,
    this.depositAmount,
    this.depositTime,
    this.balanceDeadline,
    DateTime? orderTime,
    this.rawSource,
    this.rawText,
    this.notes,
    this.screenshotPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : orderTime = orderTime ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'platform_id': platformId,
        'order_no': orderNo,
        'total_amount': totalAmount,
        'status': status,
        'is_presell': isPresell ? 1 : 0,
        'deposit_amount': depositAmount,
        'deposit_time': depositTime?.toIso8601String(),
        'balance_deadline': balanceDeadline?.toIso8601String(),
        'order_time': orderTime.toIso8601String(),
        'raw_source': rawSource,
        'raw_text': rawText,
        'notes': notes,
        'screenshot_path': screenshotPath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Order.fromMap(Map<String, dynamic> map) => Order(
        id: map['id'] as String,
        platformId: map['platform_id'] as String,
        orderNo: map['order_no'] as String?,
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
        status: map['status'] as String,
        isPresell: (map['is_presell'] as int?) == 1,
        depositAmount: (map['deposit_amount'] as num?)?.toDouble(),
        depositTime: map['deposit_time'] != null
            ? DateTime.parse(map['deposit_time'] as String)
            : null,
        balanceDeadline: map['balance_deadline'] != null
            ? DateTime.parse(map['balance_deadline'] as String)
            : null,
        orderTime: DateTime.parse(map['order_time'] as String),
        rawSource: map['raw_source'] as String?,
        rawText: map['raw_text'] as String?,
        notes: map['notes'] as String?,
        screenshotPath: map['screenshot_path'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Order copyWith({
    String? id,
    String? platformId,
    String? orderNo,
    double? totalAmount,
    String? status,
    bool? isPresell,
    double? depositAmount,
    DateTime? depositTime,
    DateTime? balanceDeadline,
    DateTime? orderTime,
    String? rawSource,
    String? rawText,
    String? notes,
    String? screenshotPath,
  }) =>
      Order(
        id: id ?? this.id,
        platformId: platformId ?? this.platformId,
        orderNo: orderNo ?? this.orderNo,
        totalAmount: totalAmount ?? this.totalAmount,
        status: status ?? this.status,
        isPresell: isPresell ?? this.isPresell,
        depositAmount: depositAmount ?? this.depositAmount,
        depositTime: depositTime ?? this.depositTime,
        balanceDeadline: balanceDeadline ?? this.balanceDeadline,
        orderTime: orderTime ?? this.orderTime,
        rawSource: rawSource ?? this.rawSource,
        rawText: rawText ?? this.rawText,
        notes: notes ?? this.notes,
        screenshotPath: screenshotPath ?? this.screenshotPath,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  static const statusLabels = {
    'pending': '待付款',
    'paid': '已付款',
    'shipped': '已发货',
    'received': '已收货',
    'completed': '已完成',
    'cancelled': '已取消',
  };

  String get statusLabel => statusLabels[status] ?? status;

  int get daysUntilBalanceDeadline {
    if (balanceDeadline == null) return 999;
    return balanceDeadline!.difference(DateTime.now()).inDays;
  }

  bool get isBalanceOverdue =>
      balanceDeadline != null && balanceDeadline!.isBefore(DateTime.now());
}