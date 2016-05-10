
### Creating an Explicit App ID

In order to support Push Notifications, each application should have it's own Explicit App ID. As a standard, the applications is represented by reversed address (ex. com.example.MyApp).

*Can I use my existing App ID?* If you have already configured an App ID for your app, double check that it was set up as an Explicit App ID. Wildcard App IDs cannot support push notifications and they are easy to identify: the last character in the bundle identifier is an asterisk (*). Wildcard App IDs cannot be converted to Explicit App IDs, but setting up a new App ID for your app is quite straightforward.

If you already have an Explicit App ID for this app, proceed with Step 1.2. The following instructions cover the creation of a new Explicit App ID.

1. Navigate to the [Apple Developer Member Center](https://developer.apple.com/membercenter/index.action) website, and click on [Certificates, IDs & Profiles](https://developer.apple.com/account/ios/certificate).

2. Select <a href="https://developer.apple.com/account/ios/identifier/bundle">App IDs</a> under the Identifier section.

3. You will see a list of your App IDs. Select the + button to register a new App Id.

  <center><img src="Images/AddNewAppID.png?raw=true" alt="Create new iOS App ID"/></center>

4. Enter a name for your new App ID under App ID Description.

5. Choose an App ID Prefix. The default selection should be correct in most cases.

6. Under App ID Suffix, select Explicit App ID. Enter your iOS app's Bundle ID. This string should match the Bundle Identifier in your Xcode project configuration or Info.plist file.

  <center><img src="Images/RegisteringAppId.png?raw=true" alt="Explicit App ID"/></center>

7. Enable Push Notifications under App Services. You may also enable any other services that your app will need at this point.

  <center><img src="Images/RegisteringAppIdServices.png?raw=true" alt="Enable Push Notifications under App Services"/></center>

8. Select "Continue" and make sure that all the values were entered correctly. Push Notifications should be enabled, and the Identifier field should match your app's Bundle Identifier (plus App ID Prefix). Select "Submit" to finalize the registration of your new App ID.

### Configuring your App ID for Push Notifications

Now that you've created a new App ID (or chosen an existing Explicit App ID), it's time to configure the App ID for Push Notifications.

1. Select your newly created App ID from the list of App IDs, then select "Edit".

  <center><img src="Images/EditingAppId.png?raw=true" alt="Select new App ID"/></center>

2. Scroll down to the Push Notifications section. Here you will be able to create both a Development SSL Certificate, as well as a Production SSL Certificate. Start by selecting "Create Certificate" under "Development SSL Certificate".

  <center><img src="Images/EditingAppIdDevCert.png?raw=true" alt="Create Certificate"/></center>

3. Follow the instructions in the next screen to create a Certificate Signing Request (CSR) using the Keychain Access utility on your Mac. This will be used to authenticate the creation of the SSL certificate.

  <center><img src="Images/KeychainRequest.png?raw=true" alt="Certificate Signing Request"/></center>

4. Locate the CSR and upload it to Apple's servers, then click on "Generate". Once the certificate is ready, download the generated SSL certificate to your computer.

5. Double click on the downloaded SSL certificate to add it to your **login** keychain.

  <center><img src="Images/AddCertificatesToKeychain.png?raw=true" alt="Add Certificate to Keychain"/></center>

6. Open the Keychain Access utility, and locate the certificate you just added under "My Certificates". It should be called "Apple Development <platform> Push Services: <YourBundleIdentifier>" if it is a development certificate, or "Apple Push Services: <YourBundleIdentifier>" if it is a production certificate.

7. Right-click on it, select "Export", and save it as a .p12 file. You will be prompted to enter a password which will be used to protect the exported certificate. *Do not enter an export password when prompted!* Leave both fields blank and click OK. You will then be asked to enter your OS X account password to allow Keychain Access to export the certificate from your keychain on the next screen. Enter your OS X password and click on Allow.

  <center><img src="Images/KeychainExporting.png?raw=true" alt="Export P12 Certificate"/></center>

If the Personal Information Exchange (.p12) option is grayed out in the export sheet, make sure "My Certificates" is selected in Keychain Access. If that does not help, double check that your certificate appears under the **login** keychain. You can drag and drop it into **login** if needed.

You have just enabled Push Notification for your app in development mode. Prior to releasing your application on the App Store, you will need to repeat steps 1 through 7 of this section, but select "Production Push SSL Certificate" in step 2 instead. You may reuse the CSR from step 3.

### Creating the Development Provisioning Profile

A Provisioning Profile authenticates your device to run the app you are developing. Whether you have created a new App ID or modified an existing one, you will need to regenerate your provisioning profile and install it. If you have trouble using an existing profile, try removing the App ID and setting it back. For purposes of this tutorial, we'll create a new profile.

Note that prior to submitting your app to the App Store, you will need to test push notifications in production. This will be covered in Section 7.

1. Navigate to the [Apple Developer Member Center](https://developer.apple.com/membercenter/index.action) website, and select [Certificates, IDs & Profiles](https://developer.apple.com/account/ios/certificate/).

2. Select [All](https://developer.apple.com/account/ios/profile/) under Provisioning Porfiles.

3. Select the + button to create a new Provisioning Profile.

4. Choose "iOS App Development" (or "Mac App Development") as your provisioning profile type then select "Continue". We will create Ad Hoc and App Store profiles later.

5. Choose the Explicit App ID you created in Section 1 from the drop down then select "Continue".

6. Make sure to select your Development certificate in the next screen, then select "Continue". If you do not have one, this is a good time to create a new "iOS App Development" (or "Mac App Development") certificate.

7. You will be asked to select which devices will be included in the provisioning profile. Select "Continue" after selecting the devices you will be using to test push notifications during development.

8. Choose a name for this provisioning profile, such as "My App Development Profile", then select "Generate".

9. Download the generated provisioning profile from the next screen by selecting the "Download" button.

10. Add the profile to Xcode by double-clicking on the downloaded file.