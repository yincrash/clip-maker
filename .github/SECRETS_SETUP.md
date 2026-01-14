# GitHub Secrets Setup for CI/CD

This document explains how to set up the required GitHub repository secrets for the release workflow.

## Required Secrets

| Secret Name | Description |
|-------------|-------------|
| `DEVELOPMENT_TEAM` | Your Apple Developer Team ID (e.g., `6K3U28K9L6`) |
| `DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64` | Base64-encoded .p12 certificate |
| `DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD` | Password for the .p12 certificate |
| `KEYCHAIN_PASSWORD` | Any secure password (used for temporary keychain) |
| `APPLE_ID` | Your Apple ID email for notarization |
| `APPLE_ID_PASSWORD` | App-specific password for notarization |

## Setup Instructions

### 1. Export Your Developer ID Certificate

1. Open **Keychain Access** on your Mac
2. Find your "Developer ID Application" certificate
3. Right-click → Export
4. Save as `.p12` format with a password
5. Convert to base64:
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```
6. Paste into the `DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64` secret

### 2. Create App-Specific Password

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in → Security → App-Specific Passwords
3. Click "Generate an app-specific password"
4. Name it "GitHub Actions" or similar
5. Copy the generated password to `APPLE_ID_PASSWORD` secret

### 3. Find Your Team ID

Your Team ID is visible in:
- Apple Developer Portal → Membership
- Xcode → Signing & Capabilities → Team dropdown

### 4. Add Secrets to GitHub

1. Go to your repository on GitHub
2. Settings → Secrets and variables → Actions
3. Click "New repository secret" for each secret

## Testing the Release

### Manual Release
1. Go to Actions → Release workflow
2. Click "Run workflow"
3. Enter version number (e.g., `1.0.0`)

### Tag-based Release
```bash
git tag v1.0.0
git push origin v1.0.0
```

This will create a draft release with the signed and notarized DMG.
