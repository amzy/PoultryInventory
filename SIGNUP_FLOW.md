# Account Signup Flow

The signup flow supports two account types:

- **Farm owner** → Firestore role `admin`.
- **Farm member** → Firestore role `member`.

Signup collects full name, mobile number, email, password, password confirmation, and an optional profile photo. The profile photo is selected from the device photo library and stored as a bounded compressed base64 value in the user's Firestore profile; no camera permission is requested.

Farm members do not receive flock access merely by choosing Member. Their email must be invited by a farm owner. After signup, pending invitations for that email are claimed automatically.

## Firestore rules

The signup profile-create rule intentionally permits a newly authenticated user to create their own `admin` or `member` profile exactly once. The role is selected during signup; runtime code does not contain a hard-coded administrator UID.

Deploy the updated rules before testing a new signup:

```bash
firebase deploy --only firestore:rules
```

## iOS photo privacy

The profile photo uses the system photo picker and does not request camera access. `ios/Runner/Info.plist` contains a clear `NSPhotoLibraryUsageDescription` explaining the optional profile-photo purpose.

The project currently offers Google sign-in as an existing social login. Before App Store submission, review Apple's current Login Services requirement and configure Sign in with Apple if the app continues to use Google sign-in on iOS. Also ensure the final iOS target has the required Apple capability and production Firebase provider configuration.
