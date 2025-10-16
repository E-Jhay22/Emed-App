# Emed App (ADET and IMSOFTENG Project)

Simple barangay clinic app made with Flutter + Supabase.

Features:
- Login/Register, Profile
- Admin (verify users, manage roles)
- Appointments (with small chat)
- Inventory and Announcements


## Quick Setup

1) Install packages
```bash
flutter pub get
```

2) Supabase config
- Get your `SUPABASE_URL` and `SUPABASE_ANON_KEY` from Supabase.
- Easiest is to pass them with --dart-define when running.

3) Database
- Open Supabase SQL editor and run:
  - `supabase_setup.sql`
  - `verification_schema.sql`

## Run the app
```bash
flutter run --dart-define SUPABASE_URL=your_url --dart-define SUPABASE_ANON_KEY=your_key
```

## Build APK (Android)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

## Notes
- If password reset email is used, the app shows a reset screen after opening the link.

Made by COZEN
Zapata, Elmer Jhay 
Pagcu, Carl Gaebriel
Reyes, Justine Kevin
Manusig, Charles Jansen
