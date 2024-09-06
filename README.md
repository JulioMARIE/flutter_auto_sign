# ✨ ¶ flutter_auto_sign

```Create release jks file, key.properties and add what you need in app/build.gradle. Great to automate release app configuration```

# To install
`dart pub global activate flutter_auto_sign`

# Before run
```Ensure you have "keytool" and it's work on path```

# Run at project
 ```
 `flutter_auto_sign`
 ```
 Without option, The default alias is "upload-alias", the jks file is created at HOME DIRECTORY PATH and named upload-keystore.jks. We will see the path in console after 
 success.
 ```
 Then go to android/key.properties to put your passwords, passwords you previously enter to create jks file.
 Check app/build.gradle. Remove eventually in app/build.gradle:
  ```
  buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }.
 ```

``` 
# With options
`flutter_auto_sign -p /path/to/keystore.jks -a keyAlias`
or
`flutter_auto_sign --keystorePath path/to/keystore.jks --keyAlias myAlias`

```
Follow instructions and everyting its done
```
Then go to android/key.properties to put your passwords, passwords you previously enter to create jks file.
```
 Check app/build.gradle. Remove eventually in app/build.gradle:
 ```
  buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig signingConfigs.debug
        }
    }
```
 
# Ensure everything is ok in app/build.gradle

# That's it :) !!! Enjoy!!! ✨ 


 
