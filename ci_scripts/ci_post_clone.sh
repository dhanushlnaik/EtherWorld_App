#!/usr/bin/env bash
set -e

echo "🚀 Running ci_post_clone.sh..."

# 1. Recreate Config.xcconfig from Environment Variables
echo "📝 Recreating Config.xcconfig..."
cat <<EOF > ../Config.xcconfig
GHOST_API_KEY = $GHOST_API_KEY
GHOST_BASE_URL = $GHOST_BASE_URL
SUPABASE_URL = $SUPABASE_URL
SUPABASE_ANON_KEY = $SUPABASE_ANON_KEY
EOF
echo "✓ Config.xcconfig recreated."

# 2. Recreate GoogleService-Info.plist from base64 Environment Variable
echo "🔑 Recreating GoogleService-Info.plist..."
if [ -n "$GOOGLE_SERVICE_INFO_PLIST_BASE64" ]; then
    echo "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > ../IOS_App/GoogleService-Info.plist
    echo "✓ GoogleService-Info.plist restored."
else
    echo "⚠️ WARNING: GOOGLE_SERVICE_INFO_PLIST_BASE64 is not set."
fi

echo "✨ ci_post_clone.sh finished."
