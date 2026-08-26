abstract final class MinorMoney {
  static String usd(int minorUnits) {
    final absolute = minorUnits.abs();
    final whole = absolute ~/ 100;
    final cents = (absolute % 100).toString().padLeft(2, '0');
    final digits = whole.toString();
    final grouped = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
      grouped.write(digits[index]);
    }
    return '${minorUnits < 0 ? '-' : ''}\$$grouped.$cents';
  }
}
