import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _num2 = NumberFormat('#,##0.00');

  // 输入单位为 B（字节），格式化为 GB 或 TB（保留两位小数）
  static String dataFromBytes(num bytes) {
    final double gb = bytes / (1024 * 1024 * 1024); // B -> GB
    if (gb >= 1024) {
      final tb = gb / 1024; // GB -> TB
      return '${_num2.format(tb)} TB';
    }
    return '${_num2.format(gb)} GB';
  }

  // 新增：输入单位为 B/s（字节每秒），格式化为 KB/s、MB/s 或 GB/s
  static String speedFromBytesPerSec(num bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toInt()} B/s';
    final kb = bytesPerSec / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB/s';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB/s';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB/s';
  }

  static String shareRate(num rate) => _num2.format(rate);
  static String bonus(num bonus) => _num2.format(bonus);
}
