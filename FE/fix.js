const fs = require('fs');
let text = fs.readFileSync('e:/MUSE/Muse Rents/fe/lib/screens/admin/schedule_screen.dart', 'utf8');

const regex = /\}[^\n]*_formatCurrency\([\s\S]*?\}[^\n]*_updateBookingStatus\(/g;
const replacement = '}\n\n  String _formatCurrency(double value) {\n    return `${value.round().toString().replaceAllMapped(RegExp(r\'(\\\\d{1,3})(?=(\\\\d{3})+(?!\\\\d))\'), (Match m) => \'${m[1]},\')} đ`.replace(/`/g, \'\\'\');\n  }\n\n  Future<void> _updateBookingStatus(';

text = text.replace(regex, replacement);

fs.writeFileSync('e:/MUSE/Muse Rents/fe/lib/screens/admin/schedule_screen.dart', text, 'utf8');
console.log('Fixed formatCurrency');
