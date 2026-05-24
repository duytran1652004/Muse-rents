import 'dart:io';
void main() {
  var file = File('e:/MUSE/Muse Rents/fe/lib/screens/admin/schedule_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceFirst(
    \"_buildActionButton('Xác nh?n', RentsColors.primaryBlue, Colors.white\",
    \"_buildActionButton('Xác nh?n', RentsColors.accentGreen, Colors.white\"
  );
  content = content.replaceFirst(
    \"_buildActionButton('Hoàn thành', RentsColors.accentGreen, Colors.white\",
    \"_buildActionButton('Hoàn thành', RentsColors.primaryBlue, Colors.white\"
  );
  file.writeAsStringSync(content);
}
