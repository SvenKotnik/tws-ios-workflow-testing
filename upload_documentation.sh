
SCHEME=$1
WORKSPACE=$2
DESTINATION=$3
DERIVED_DATA_PATH=$4
HOSTING_BASE_PATH=$5
STATIC_WEB_PATH=$6

#Generate documentation
xcodebuild docbuild -scheme "$SCHEME" -destination "$DESTINATION" -workspace "$WORKSPACE" -derivedDataPath "$DERIVED_DATA_PATH"
echo "Moving to the folder with the DocC archive"
#Move to the folder with .doccarchive
cd "$DERIVED_DATA_PATH"/Build/Products/Debug-iphoneos
echo "Contents of the folder:"
ls

#Convert the archive into a static web page
echo "Starting DocC Archive conversion to a static web app"
$(xcrun --find docc) process-archive \
transform-for-static-hosting "$SCHEME".doccarchive \
    --output-path "$STATIC_WEB_PATH" \
    --hosting-base-path "$HOSTING_BASE_PATH"

echo "Conversion completed"

#Move to the submodule that hosts the documentation and remove the current one
cd ../../../../tws-ios-docs
git checkout main
pwd
echo "Moved to Docs repository and checked out main branch"
echo "Removing all the current documentatino content"
ls
rm -rf *
echo "Content removed"

#Copy and commit the updated documentation
cp -R ../"$DERIVED_DATA_PATH"/Build/Products/Debug-iphoneos/"$STATIC_WEB_PATH"
git add .
git commit -m "Updated documentation"
git push origin main