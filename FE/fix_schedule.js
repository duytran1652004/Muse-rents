const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, 'lib', 'screens', 'admin', 'schedule_screen.dart');
let content = fs.readFileSync(file, 'utf8');

// 1. Vietnamese character replacement fixes
content = content.replace(/được/g, 'c');
content = content.replace(/đến/g, 'n');
content = content.replace(/\} đ'/g, '}');

// 2. The weird space-đ-quote replacements
content = content.replace(/ đ'/g, '');

// 3. Status string replacements that lost their 'd' and closing quote
content = content.replace(/'confirme([,:])/g, "'confirmed'$1");
content = content.replace(/'complete([,:])/g, "'completed'$1");
content = content.replace(/'cancelle([,:])/g, "'cancelled'$1");

// 4. Missing 'd' in $id and id indexes
content = content.replace(/booking\['i\]/g, "booking['id']");
content = content.replace(/\/bookings\/\$i([,;)])/g, "/bookings/$id$1");

// 5. Fix RegExp
content = content.replace(/RegExp\(r'\(d\{1,3\}\)\(\?=\(d\{3\}\)\+\(\?!d\)\)'\)/g, "RegExp(r'(\\\\d{1,3})(?=(\\\\d{3})+(?!\\\\d))')");

// 6. Fix Match m => ,
content = content.replace(/\(Match m\) => ,/g, "(Match m) => '${m[1]},'");

fs.writeFileSync(file, content, 'utf8');
console.log('Fixed file.');
