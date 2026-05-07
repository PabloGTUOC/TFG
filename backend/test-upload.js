async function run() {
  const boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW';
  const data = `--${boundary}\r\nContent-Disposition: form-data; name="avatar"; filename="test.jpg"\r\nContent-Type: image/jpeg\r\n\r\nfakeimagecontent\r\n--${boundary}--`;
  
  const res = await fetch('http://localhost:3000/api/me/avatar', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer test-token',
      'Content-Type': `multipart/form-data; boundary=${boundary}`
    },
    body: data
  });
  console.log('Status:', res.status);
  console.log('Body:', await res.text());
  process.exit(0);
}
run();
