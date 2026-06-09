import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/rents_colors.dart';

DateTime? parseBookingDate(dynamic value) {
  if (value == null) return null;

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (match != null) {
    final year = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final day = int.tryParse(match.group(3) ?? '');
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}

String formatBookingDate(dynamic value) {
  final parsed = parseBookingDate(value);
  if (parsed == null) return '';
  return '${parsed.day}/${parsed.month}/${parsed.year}';
}

String formatBookingDateShort(dynamic value) {
  final parsed = parseBookingDate(value);
  if (parsed == null) return '';
  return '${parsed.day}/${parsed.month}';
}

String formatTimeStr(String? t) {
  if (t == null || t.trim().isEmpty) return '';
  final parts = t.trim().split(':');
  if (parts.length >= 2) {
    int? hour = int.tryParse(parts[0]);
    if (hour != null) {
      return '$hour:${parts[1]}';
    }
  }
  return t.trim();
}

Future<TimeOfDay?> showScrollTimePicker(BuildContext context, {required TimeOfDay initialTime}) async {
  TimeOfDay? pickedTime = initialTime;
  final res = await showDialog<bool>(
    context: context,
    builder: (BuildContext builder) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Container(
          height: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'CHỌN GIỜ',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w800, 
                  color: RentsColors.primaryBlue
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 32, // Phóng to số
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime(2020, 1, 1, initialTime.hour, initialTime.minute),
                    onDateTimeChanged: (DateTime newDateTime) {
                      pickedTime = TimeOfDay.fromDateTime(newDateTime);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Hủy', style: TextStyle(color: RentsColors.grayDark, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: RentsColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Xong', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  if (res == true) return pickedTime;
  return null;
}
