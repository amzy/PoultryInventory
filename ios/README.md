# iOS platform

This project is built on the M2 Mac self-hosted runner. If the Flutter iOS platform has not yet been generated, the mobile workflow runs:

    flutter create --platforms=ios .

After the first successful run, commit the generated `ios/` directory back to this repository if you want to retain/customize the Xcode project (bundle ID, icons, signing, etc.).
