dir=${PWD##*/}
if [ "$dir" = "CaffeineKit" -a -d "Sources" -a -f "logo.png" ]; then
    jazzy && echo 'section > section > p > img { margin-top: 3em; }' >> docs/css/jazzy.css && rm -r build
else 
    echo "Incorrect directory—must be run from project root"
    exit 1
fi
