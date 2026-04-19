# Anonymous Upgrade QA Checklist

Run these on-device before shipping:

1. Fresh install → Skip auth (anonymous) → Complete onboarding → Add 2 custom exercises → Complete 1 training session.
2. Open Settings → Sign up with email + password.
3. Verify: Firebase UID in Firestore console hasn't changed. Player profile, exercises, and session are all still visible in the app.
4. Sign out → Sign back in with same email on a second simulator. Verify same data restores.
5. Repeat 1–4 with Google Sign-In and Apple Sign-In.
6. Negative case: start anon → try to sign in with a pre-existing email. Expect fallback: new UID, warning logged, old anon data orphaned (this is the documented least-bad outcome).
