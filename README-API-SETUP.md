# API Setup Instructions

## YouTube API Configuration

The YouTube integration uses your existing Google API key from Firebase/Google Services configuration.

### 1. API Key Source

The app automatically uses the `API_KEY` from your `GoogleService-Info.plist` file for YouTube Data API v3 access. This is the same key used for Firebase and other Google services.

### 2. Enable YouTube Data API v3

To enable YouTube functionality:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your existing project (the one from GoogleService-Info.plist)
3. Navigate to "APIs & Services" > "Library"
4. Search for "YouTube Data API v3"
5. Click "Enable"

### 3. API Key Restrictions (Recommended)

For security, restrict your API key:

1. Go to "APIs & Services" > "Credentials"
2. Click on your API key
3. Under "API restrictions", select "Restrict key"
4. Enable these APIs:
   - YouTube Data API v3
   - Firebase services you're using
   - Any other Google services your app needs

### 4. No Additional Configuration Required

Since the app uses your existing Google Services configuration:
- ✅ No need to add API keys to Info.plist
- ✅ No need to manage separate YouTube API keys
- ✅ Uses the same security model as your Firebase setup

### 5. API Usage

The app uses YouTube Data API v3 for:
- Searching soccer training videos
- Retrieving video metadata and thumbnails
- Automatic content categorization

Rate limits and quotas apply as per Google's YouTube API terms. Monitor usage in Google Cloud Console.