# AXIO7 iOS Shell

Capacitor wrapper for the AXIO7 App Store MVP. The app loads the production web experience at `https://axio7.com/housing?native=ios` and relies on the Next.js app for navigation, auth, housing search, posting, and messaging.

## Local setup

```bash
npm install
npx cap add ios
npx cap sync ios
npx cap open ios
```

Final simulator testing, signing, archive, and TestFlight upload require macOS with Xcode.

## Manual Xcode items

- Set bundle ID to `com.axio7.app`.
- Select the Apple Developer signing team.
- Add camera/photo usage descriptions.
- Enable Sign in with Apple if using native capability.
- Enable Associated Domains when universal links are configured.
- Add app icons and launch screen assets before App Store submission.

## Default route

The shell opens `https://axio7.com/housing?native=ios`, which enables AXIO7's native-like bottom tab bar and iOS bridge behavior in the web app.
