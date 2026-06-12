const fs = require('fs');
const path = require('path');
const dir = './controllers';
const files = fs.readdirSync(dir).filter(f => f.endsWith('.js'));
files.forEach(f => {
  let content = fs.readFileSync(path.join(dir, f), 'utf8');
  let modified = false;
  
  const keywords = ['active', 'inactive', 'suspended', 'confirmed', 'dropped', 'pending', 'in_progress', 'completed', 'booking', 'payment', 'class', 'alert', 'closed'];
  
  keywords.forEach(kw => {
    // Look for string literals containing double quotes around keywords.
    // Replace "keyword" with \\'keyword\\'
    const regex = new RegExp(`"${kw}"`, 'g');
    if (regex.test(content)) {
      modified = true;
      content = content.replace(regex, `\\'${kw}\\'`);
    }
  });

  if (modified) {
    fs.writeFileSync(path.join(dir, f), content);
    console.log('Fixed', f);
  }
});
