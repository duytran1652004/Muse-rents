import 'dart:io';
void main() {
  var f = File('e:/MUSE/Muse Rents/fe/lib/screens/admin/schedule_screen.dart');
  var t = f.readAsStringSync();
  t = t.replaceAll(RegExp(r'[^\x00-\x7FđĐáàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴ\s]'), '');
  f.writeAsStringSync(t);
}
