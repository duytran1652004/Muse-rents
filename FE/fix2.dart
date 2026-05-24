import 'dart:io';
void main() {
  var f = File('e:/MUSE/Muse Rents/fe/lib/screens/admin/schedule_screen.dart');
  var t = f.readAsStringSync();
  t = t.replaceAll('Tất đượcả', 'Tất cả');
  t = t.replaceAll('Đã xác đếnhận', 'Đã xác nhận');
  t = t.replaceAll('Lọc theo đếngày', 'Lọc theo ngày');
  t = t.replaceAll('Chọn đếngày', 'Chọn ngày');
  t = t.replaceAll('Bắt  ầu', 'Bắt đầu');
  t = t.replaceAll('Xóa b\" lọc', 'Xóa bộ lọc');
  t = t.replaceAll('Xác đếnhận', 'Xác nhận');
  t = t.replaceAll('Chưa đượcó ảnh phòng', 'Chưa có ảnh phòng');
  t = t.replaceAll('L i đượcập đếnhật trạng thái', 'Lỗi cập nhật trạng thái');
  t = t.replaceAll('L i kết đến i server', 'Lỗi kết nối server');
  t = t.replaceAll('Xác đếnhận xóa', 'Xác nhận xóa');
  t = t.replaceAll('Bạn đượcó đượchắc đượchắn mu n xóa l9ch tập đếnày?', 'Bạn có chắc chắn muốn xóa lịch tập này?');
  t = t.replaceAll('L i xóa l9ch tập', 'Lỗi xóa lịch tập');
  t = t.replaceAll('QUẢN LÝ LCH TẬP', 'QUẢN LÝ LỊCH TẬP');
  t = t.replaceAll('Không tìm thấy l9ch tập đếnào', 'Không tìm thấy lịch tập nào');
  t = t.replaceAll('Chờ xác đếnhận', 'Chờ xác nhận');
  t = t.replaceAll('}  ''', '} đ''');
  f.writeAsStringSync(t);
}
