# Starts the Laravel API and the Flutter web app for local development.
# Port 5000 must match ALLOWED_ORIGINS in server/.env (and the "Authorized
# JavaScript origins" of the Google OAuth client).

# Only the public Google client ID is passed to Flutter, never other .env values.
$googleClientId = '833431410255-vj774m6mm39nv53hmafh8ajltol2gqgi.apps.googleusercontent.com'
$line = Select-String -Path "$PSScriptRoot\server\.env" -Pattern '^GOOGLE_CLIENT_ID=(.*)$' | Select-Object -First 1
if ($line) {
  $envClientId = $line.Matches[0].Groups[1].Value.Trim().Trim('"')
  if ($envClientId) { $googleClientId = $envClientId }
}

Start-Process powershell -ArgumentList '-NoExit','-Command',"cd '$PSScriptRoot\server'; php artisan serve --port=8000"
flutter run -d chrome --web-port 5000 `
  --dart-define=API_URL=http://localhost:8000/api/ `
  --dart-define=GOOGLE_CLIENT_ID=$googleClientId
