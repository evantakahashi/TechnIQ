# API Setup Instructions

## YouTube API Configuration

To use the YouTube integration features, you need to set up a YouTube Data API v3 key:

### 1. Get YouTube API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the YouTube Data API v3
4. Create credentials (API Key)
5. Restrict the API key to YouTube Data API v3 for security

### 2. Configure the App

Replace `YOUR_YOUTUBE_API_KEY_HERE` in `TechnIQ/Info.plist` with your actual API key:

```xml
<key>YOUTUBE_API_KEY</key>
<string>YOUR_ACTUAL_API_KEY_HERE</string>
```

### 3. Security Notes

- **NEVER** commit your actual API key to git
- The `Info.plist` file contains a placeholder that should be replaced locally
- Consider using environment variables for production deployments
- Monitor your API usage in Google Cloud Console

### 4. API Usage

The app uses YouTube Data API v3 for:
- Searching soccer training videos
- Retrieving video metadata and thumbnails
- Automatic content categorization

Rate limits and quotas apply as per Google's YouTube API terms.