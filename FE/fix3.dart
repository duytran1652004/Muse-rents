import 'dart:io';
void main() {
  var f = File('e:/MUSE/Muse Rents/fe/lib/screens/admin/schedule_screen.dart');
  var t = f.readAsStringSync();
  t = t.replaceAll(RegExp(r'Bắt .*?ầu'), 'Bắt đầu');
  t = t.replaceAll(RegExp(r'Xóa b.*? lọc'), 'Xóa bộ lọc');
  t = t.replaceAll(RegExp(r'\}\s*\s*'''), "} đ'");
  t = t.replaceAll(RegExp(r'L.*? i đượcập đếnhật trạng thái'), 'Lỗi cập nhật trạng thái');
  t = t.replaceAll(RegExp(r'L.*? i kết đến.*? i server'), 'Lỗi kết nối server');
  t = t.replaceAll(RegExp(r'Bạn đượcó đượchắc đượchắn mu.*? n xóa l.*?9ch tập đếnày\?'), 'Bạn có chắc chắn muốn xóa lịch tập này?');
  t = t.replaceAll(RegExp(r'L.*? i xóa l.*?9ch tập'), 'Lỗi xóa lịch tập');
  t = t.replaceAll(RegExp(r'QUẢN LÝ L.*?CH TẬP'), 'QUẢN LÝ LỊCH TẬP');
  t = t.replaceAll(RegExp(r'Không tìm thấy l.*?9ch tập đếnào'), 'Không tìm thấy lịch tập nào');
  f.writeAsStringSync(t);
}
