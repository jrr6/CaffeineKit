dir=${PWD##*/}
if [ "$dir" = "CaffeineKit" -a -d "Sources" -a -f "README.md" ]; then
    carthage build --archive --platform macOS
    rm -r Carthage/
else
    echo "Incorrect directory—must be run from project root"
    exit 1
fi
