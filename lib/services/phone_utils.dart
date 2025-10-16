/// Phone utilities specific to Philippine numbers.
///
/// Contract:
/// - Input: any string, possibly containing spaces/dashes/parentheses.
/// - Output: normalized E.164 for PH if valid; otherwise null.
/// - Accepted formats:
///   - +639XXXXXXXXX (11 digits after +63)
///   - 09XXXXXXXXX (leading 0 + 10 digits) -> normalized to +639XXXXXXXXX
/// - All other formats return null.
String? normalizePhPhone(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
  if (RegExp(r'^\+639\d{9}$').hasMatch(digits)) {
    return digits;
  }
  if (RegExp(r'^09\d{9}$').hasMatch(digits)) {
    return '+63${digits.substring(1)}';
  }
  return null;
}
