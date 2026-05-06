import 'package:intl/intl.dart';

class AppFormatters {
  const AppFormatters._();

  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    symbol: 'MKD ',
    decimalDigits: 2,
  );
  static final DateFormat _dateTimeFormatter = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _shortDateFormatter = DateFormat('MMM d');

  static String asCurrency(num? value) {
    if (value == null) {
      return '-';
    }
    return _currencyFormatter.format(value);
  }

  static String asRelativeDateTime(DateTime dateTime) {
    return _dateTimeFormatter.format(dateTime.toLocal());
  }

  static String asShortDate(DateTime dateTime) {
    return _shortDateFormatter.format(dateTime.toLocal());
  }
}
