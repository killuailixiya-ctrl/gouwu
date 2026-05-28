import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../models/reminder.dart';
import '../database/dao/reminder_dao.dart';

class ReminderService {
  final ReminderDao _reminderDao = ReminderDao();
  final Uuid _uuid = const Uuid();

  static const defaultOffsets = ['-7d', '-3d', '-1d', '0d', '+1d'];

  Future<void> generateReminders(Order order) async {
    await _reminderDao.deleteByOrderId(order.id);

    if (order.isPresell && order.balanceDeadline != null) {
      for (final offset in defaultOffsets) {
        final remindTime = _calculateRemindTime(order.balanceDeadline!, offset);
        if (remindTime.isBefore(DateTime.now())) continue;

        final reminder = Reminder(
          id: _uuid.v4(),
          orderId: order.id,
          type: 'balance',
          remindAt: remindTime,
          remindBefore: offset,
          message: _generateBalanceMessage(order, offset),
        );
        await _reminderDao.insert(reminder);
      }
    }

    if (order.status == 'paid') {
      final remindTime = order.orderTime.add(const Duration(days: 7));
      if (remindTime.isAfter(DateTime.now())) {
        final reminder = Reminder(
          id: _uuid.v4(),
          orderId: order.id,
          type: 'shipping',
          remindAt: remindTime,
          remindBefore: '+7d',
          message: '订单已付款7天，请关注是否已发货',
        );
        await _reminderDao.insert(reminder);
      }
    }
  }

  DateTime _calculateRemindTime(DateTime deadline, String offset) {
    final match = RegExp(r'([+-])(\d+)(d|h|m)').firstMatch(offset);
    if (match == null) return deadline;

    final sign = match.group(1)!;
    final num = int.parse(match.group(2)!);
    final unit = match.group(3)!;

    int seconds;
    switch (unit) {
      case 'd':
        seconds = num * 86400;
        break;
      case 'h':
        seconds = num * 3600;
        break;
      case 'm':
        seconds = num * 60;
        break;
      default:
        seconds = 0;
    }

    return sign == '-'
        ? deadline.subtract(Duration(seconds: seconds))
        : deadline.add(Duration(seconds: seconds));
  }

  String _generateBalanceMessage(Order order, String offset) {
    final match = RegExp(r'([+-])(\d+)(d|h|m)').firstMatch(offset);
    if (match == null) return '尾款即将到期';

    final sign = match.group(1)!;
    final num = int.parse(match.group(2)!);
    final unit = match.group(3)!;
    final unitLabel = unit == 'd' ? '天' : (unit == 'h' ? '小时' : '分钟');

    if (sign == '-') {
      return '尾款将在$num$unitLabel后到期，请及时支付';
    } else if (sign == '+' && num > 0) {
      return '尾款已逾期$num$unitLabel，定金可能损失';
    } else {
      return '尾款今天截止！请立即支付！';
    }
  }

  Future<List<Reminder>> getActiveReminders() async {
    return await _reminderDao.getActive();
  }

  Future<List<Reminder>> getUpcomingReminders({int days = 7}) async {
    return await _reminderDao.getUpcoming(days: days);
  }

  Future<void> dismissReminder(String id) async {
    await _reminderDao.dismiss(id);
  }

  Future<void> markReminderRead(String id) async {
    await _reminderDao.markRead(id);
  }
}