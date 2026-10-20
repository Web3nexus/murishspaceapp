# Android release signing

Release builds are signed with an upload keystore. The keystore and its
passwords are secrets: they stay out of git.

Run every command from the `mobile/` folder unless noted.

## 1. Create the keystore (once)

```sh
keytool -genkey -v -keystore ../keys/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Choose a store password and a key password. Write both down now.
- Use an alias such as `upload`. You will need it in step 2.
- Create the `keys/` folder outside the repo if it does not exist (`mkdir -p ../keys`).

## 2. Fill in key.properties

```sh
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties`:

- `storePassword`: the store password from step 1
- `keyPassword`: the key password from step 1
- `keyAlias`: the alias from step 1
- `storeFile`: the path to the `.jks` file, relative to `android/` (for example `../keys/upload-keystore.jks`)

`android/key.properties` is git-ignored. Do not commit it.

## 3. Build the release bundle

```sh
flutter build appbundle --release
```

The bundle is written to `build/app/outputs/bundle/release/app-release.aab`.

If `android/key.properties` is missing or incomplete, the release build stops
with a message that names the missing setting. It does not fall back to the
debug key. Debug builds (`flutter run`, `flutter build apk --debug`) do not
need this file.

## 4. Back up the keystore

- Keep at least two copies of the `.jks` file in separate places, such as an
  encrypted external drive and a password manager's file attachment.
- Store the store and key passwords in a password manager, next to the alias.
- Never put the keystore or passwords in the repo, in chat, in tickets, or in
  screenshots.
- If the keystore is lost, you can only ship updates after the Play Console
  resets the upload key. Enrol in Play App Signing so Google holds the app
  signing key.
