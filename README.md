#   f l u t t e r _ a u t o _ s i g n 
  Create key.properties and add what you need in app/build.gradle
# Please, check it app/build.gradle to ensure everything is ok

# To install
dart pub global activate flutter_auto_sign

# Run
 flutter_auto_sign
 
# With options
flutter_auto_sign --keystorePath path/to/keystore.jks --keyAlias myAlias --keyPassword myPassword
or
flutter_auto_sign -k /path/to/keystore.jks -p keystorePassword -a keyAlias -w keyPassword


 
