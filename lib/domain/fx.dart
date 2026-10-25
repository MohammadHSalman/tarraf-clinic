import 'money.dart';

/// Millionths of SYP per USD; ledger amounts never change with display settings.
class Fx {
  final String ledger, base;
  final int digits, rateMicros;
  const Fx(this.ledger, this.digits, this.base, this.rateMicros);
  int get inputDigits => base == 'USD' ? 2 : 0;
  int convert(
    int amount,
    String from,
    int fromDigits,
    String to,
    int toDigits,
  ) {
    if (!['USD', 'SYP'].contains(from) || !['USD', 'SYP'].contains(to)) {
      throw ArgumentError('عملة غير مدعومة للتحويل');
    }
    var n = BigInt.from(amount) * BigInt.from(10).pow(toDigits),
        d = BigInt.from(10).pow(fromDigits);
    if (from != to) {
      if (rateMicros <= 0) throw StateError('حدد سعر الصرف من الإعدادات');
      if (from == 'USD') {
        n *= BigInt.from(rateMicros);
        d *= BigInt.from(1000000);
      } else {
        n *= BigInt.from(1000000);
        d *= BigInt.from(rateMicros);
      }
    }
    final value = (n.abs() + d ~/ BigInt.two) ~/ d;
    if (value > BigInt.parse('9000000000000000000')) {
      throw RangeError('المبلغ كبير');
    }
    return (n.isNegative ? -value : value).toInt();
  }

  int parseInput(String text) => convert(
    Money.parse(text, inputDigits),
    base,
    inputDigits,
    ledger,
    digits,
  );
  String input(int value) => Money.format(
    convert(value, ledger, digits, base, inputDigits),
    inputDigits,
  );
  String dual(int value) {
    if (!['USD', 'SYP'].contains(ledger) || rateMicros <= 0) {
      return '${Money.format(value, digits)} $ledger · حدد سعر الصرف';
    }
    final usd =
            '${Money.format(convert(value, ledger, digits, 'USD', 2), 2)} USD',
        syp =
            '${Money.format(convert(value, ledger, digits, 'SYP', 0), 0)} SYP';
    return base == 'USD' ? '$usd  ≈  $syp' : '$syp  ≈  $usd';
  }
}
