# About
This is the camera software for the VULCAM system.

# Setting up the project

1. Install Homebrew with the following command

        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
2. Install CocoaPods

        # Xcode 7 + 8
        $ sudo gem install cocoapods --pre

        # Xcode 7
        sudo gem install activesupport -v 4.2.6
        sudo gem install cocoapods
3. Install dependencies using CocoaPods with the command

        pod install
Some of the pods used require adding an SSH key to Github. You can add one [here](https://github.com/settings/keys). This is due to the pods having been forked.

4. Open the project using the VULCAM eye.xcworkspace file.

# Uploading the app to TestFlight and AppStore

1. From XCode choose Product > Archive
2. Select the latest build from the list of builds and choose Validate
- If the validation gives a warning about the size being too large, you can ignore it.
The app is validated by Apple and they will send you an email if the validation fails.
3. After validation choose Upload to AppStore and go through the dialogs
4. Open iTunes Connect in a browser.
5. Go to My Apps > App name

##### TestFlight
1. Go to TestFlight tab
2. Click the Select Version to Test link
3. Choose the build you want to test (You may have to wait for the app to be processed)


# Exporting a .ipa file

1. From XCode choose Product > Archive
2. Select the build you want to export and click Export
3. Choose Save for Ad-hoc deployment
4. Go through the dialogs and you are done.
