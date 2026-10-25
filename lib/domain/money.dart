/// Exact base-10 conversion; never routes money through binary floating point.
class Money {
  static const maxMinor =
      900000000000000; // Keeps quantity*price within signed int64.
  static int parse(String input, int digits) {
    if (digits < 0 || digits > 6) throw FormatException('Invalid precision');
    final normalized = input
        .trim()
        .replaceAllMapped(
          RegExp('[٠-٩]'),
          (m) => '٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!).toString(),
        )
        .replaceAll('٫', '.');
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) {
      throw FormatException('أدخل رقماً موجباً دون فواصل آلاف');
    }
    final parts = normalized.split('.');
    var decimals = parts.length == 2 ? parts[1] : '';
    while (decimals.length > digits && decimals.endsWith('0')) {
      decimals = decimals.substring(0, decimals.length - 1);
    }
    if (decimals.length > digits) {
      throw FormatException('الدقة تتجاوز $digits منازل');
    }
    final result =
        BigInt.parse(parts[0]) * BigInt.from(pow10(digits)) +
        (decimals.isEmpty
            ? BigInt.zero
            : BigInt.parse(decimals.padRight(digits, '0')));
    if (result > BigInt.from(maxMinor)) {
      throw const FormatException('القيمة كبيرة جداً');
    }
    return result.toInt();
  }

  static int pow10(int n) {
    var result = 1;
    for (var i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }

  static String format(int value, int digits) {
    final sign = value < 0 ? '-' : '';
    final s = value.abs().toString().padLeft(digits + 1, '0');
    return digits == 0
        ? '$sign$s'
        : '$sign${s.substring(0, s.length - digits)}.${s.substring(s.length - digits)}';
  }

  /// Quantities are milli-units / milli-CC. One rounding per session-material line.
  static int consumption(int milliQuantity, int unitCostMinor) {
    if (milliQuantity < 0 ||
        milliQuantity > 1000000000 ||
        unitCostMinor < 0 ||
        unitCostMinor > maxMinor ||
        BigInt.from(milliQuantity) * BigInt.from(unitCostMinor) >
            BigInt.parse('9000000000000000000')) {
      throw RangeError('Consumption outside supported range');
    }
    return ((BigInt.from(milliQuantity) * BigInt.from(unitCostMinor) +
                BigInt.from(500)) ~/
            BigInt.from(1000))
        .toInt();
  }
}
