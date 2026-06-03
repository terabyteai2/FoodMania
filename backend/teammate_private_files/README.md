# Private Setup Files

These files were collected from local/ignored project files so another developer can run or build the projects. They contain secrets and signing material, so send them through a private channel only.

## Restore Map

Copy each file back to the matching path after cloning the repo:

| Bundle file | Restore to |
| --- | --- |
| `backend.env` | `backend/.env` |
| `backend.env.mvp` | `backend/.env.mvp` |
| `backend.env.example` | `backend/.env.example` |
| `platform_admin.env` | `platform_admin/.env` |
| `platform_admin.env.production` | `platform_admin/.env.production` |
| `admin_app_android.key.properties` | `admin_app/android/key.properties` |
| `admin_app_android_app.upload-keystore.jks` | `admin_app/android/app/upload-keystore.jks` |
| `deploy.deploy-secrets` | `deploy/.deploy-secrets` |
| `admin_app_android.local.properties.from-this-machine` | `admin_app/android/local.properties` |

## Notes

- `admin_app/android/local.properties` is machine-specific. It contains local SDK paths, so your teammate should usually regenerate it by running `flutter pub get` or opening the Flutter project in Android Studio. Use the included copy only as a reference.
- `admin_app_android.key.properties` and `admin_app_android_app.upload-keystore.jks` are required for signed Android release builds.
- `deploy.deploy-secrets` is for the VPS deploy scripts. It is not needed for normal local development.
- `backend.env` is the main backend runtime config. The Flutter admin app docs also reference backend values such as `POS_CLOUD_API_URL`, `POS_NGROK_DOMAIN`, `NGROK_AUTHTOKEN`, and `NGROK_STATIC_DOMAIN`.
