<!doctype html>
<html lang="en">
<body style="margin:0;padding:24px;background:#f7eef0;font-family:Arial,Helvetica,sans-serif;color:#2b0a12;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
    <tr><td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:12px;padding:32px;">
        <tr><td>
          <p style="margin:0 0 4px;font-size:20px;font-weight:bold;color:#9b0e2a;">eBarangay Mo</p>
          <p style="margin:0 0 24px;font-size:14px;color:#6b4a52;">Barangay services, one tap away.</p>
          <p style="margin:0 0 16px;font-size:16px;">Hi {{ $name }},</p>
          <p style="margin:0 0 16px;font-size:16px;">Enter this code in the app to verify your email:</p>
          <p style="margin:0 0 16px;font-size:36px;font-weight:bold;letter-spacing:8px;text-align:center;color:#9b0e2a;">{{ $code }}</p>
          <p style="margin:0 0 16px;font-size:14px;color:#6b4a52;">It expires in {{ $minutes }} minutes. Don't share it with anyone. Barangay staff will never ask for it.</p>
          <p style="margin:0;font-size:14px;color:#6b4a52;">If you didn't create an eBarangay Mo account, you can ignore this email.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
