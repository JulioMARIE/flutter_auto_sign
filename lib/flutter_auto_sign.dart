library flutter_auto_sign;

/// A Flutter auto sign.

import 'dart:io';
import 'package:args/args.dart';
import 'package:prompts/prompts.dart' as prompts;

class FlutterAutoSign {
  static Future<void> configure({
    String? keystorePath,
    String? keystorePassword,
    String? keyAlias,
    String? keyPassword,
  }) async {
    keystorePath ??= prompts.get('Enter keystore path:');

    if (!await File(keystorePath).exists()) {
      print('Cannot proceed without a valid keystore. Exiting.');
      return;
      // if (prompts.getBool('Keystore does not exist. Create a new one?', defaultsTo: true)) {
      //   await _createKeystore(keystorePath);
      // } else {
      //   print('Cannot proceed without a valid keystore. Exiting.');
      //   return;
      // }
    }

    // Demander le mot de passe de manière sécurisée
    String promptPassword(String promptText) {
      stdout.write(promptText);
      stdin.echoMode = false;
      String password = stdin.readLineSync() ?? '';
      stdin.echoMode = true;
      stdout.writeln();
      return password;
    }

    keystorePassword ??= promptPassword('Enter keystore password: ');
    keyAlias ??= prompts.get('Enter key alias:');
    keyPassword ??= promptPassword('Enter key password: ');

    // 1. Verify permissions
    await _verifyFilePermissions(keystorePath);

    // 2. Create key.properties file
    await _createKeyProperties(
      keystorePath: keystorePath,
      keystorePassword: keystorePassword,
      keyAlias: keyAlias,
      keyPassword: keyPassword,
    );

    // 3. Update build.gradle
    await _updateBuildGradle();

    print('FlutterAutoSign: Configuration completed successfully.');
  }

  // static Future<void> _createKeystore(String keystorePath) async {
  //   final dname = prompts.get('Enter distinguished name for the key (e.g., "CN=Your Name, OU=Your Organizational Unit, O=Your Organization, L=Your City, S=Your State, C=Your Country Code"):');
  //   final validity = prompts.get('Enter validity in days:', defaultsTo: '10000');
  //   final keyAlg = prompts.get('Enter key algorithm:', defaultsTo: 'RSA');
  //   final keySize = prompts.get('Enter key size:', defaultsTo: '2048');
  //   final keystorePassword = prompts.get('Enter keystore password: ');
  //   final keyPassword = prompts.get('Enter key password: ');
  //
  //   final result = await Process.start(
  //       'keytool',
  //       [
  //         '-genkey',
  //         '-v',
  //         '-keystore', keystorePath,
  //         '-alias', 'key',
  //         '-keyalg', keyAlg,
  //         '-keysize', keySize,
  //         '-validity', validity,
  //         '-dname', dname,
  //         '-storepass', keystorePassword,
  //         '-keypass', keyPassword
  //       ],
  //       mode: ProcessStartMode.inheritStdio
  //   );
  //
  //   final exitCode = await result.exitCode;
  //
  //   if (exitCode != 0) {
  //     print('Error creating keystore. Exiting.');
  //     exit(1);
  //   }
  //
  //   print('Keystore created successfully at $keystorePath');
  // }

  static Future<void> _verifyFilePermissions(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File does not exist', filePath);
    }

    try {
      await file.open(mode: FileMode.read);
      await file.open(mode: FileMode.write);
    } catch (e) {
      throw FileSystemException('Insufficient permissions for file', filePath);
    }
  }

  static Future<void> _createKeyProperties({
    required String keystorePath,
    required String keystorePassword,
    required String keyAlias,
    required String keyPassword,
  }) async {
    final content = '''
storePassword=$keystorePassword
keyPassword=$keyPassword
keyAlias=$keyAlias
storeFile=$keystorePath
''';

    final file = File('android/key.properties');
    await file.writeAsString(content);
    print('FlutterAutoSign: Created key.properties file.');
  }

  static Future<void> _updateBuildGradle() async {
    final buildGradlePath = 'android/app/build.gradle';
    final buildGradleFile = File(buildGradlePath);
    var content = await buildGradleFile.readAsString();

    // Code pour charger les propriétés du keystore
    final keyPropertiesLoader = '''
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
''';

    // Vérifiez si le code de chargement des propriétés existe déjà
    if (!content.contains('def keystoreProperties')) {
      // Insérez le code juste avant le bloc android
      final androidBlockRegex = RegExp(r'android\s*\{[\s\S]*?\}', multiLine: true);
      final androidBlockMatch = androidBlockRegex.firstMatch(content);

      if (androidBlockMatch != null) {
        final startIndex = androidBlockMatch.start;
        content = content.substring(0, startIndex) + keyPropertiesLoader + content.substring(startIndex);
      } else {
        print('Could not find the android block in build.gradle. Inserting at the end.');
        content += '\n' + keyPropertiesLoader;
      }
    }

    // Bloc android avec les configurations de signature
    final androidBlockRegex = RegExp(r'android\s*\{[\s\S]*?\}', multiLine: true);
    final androidBlockMatch = androidBlockRegex.firstMatch(content);

    if (androidBlockMatch != null) {
      final startIndex = androidBlockMatch.start;
      final endIndex = androidBlockMatch.end;
      final beforeAndroidBlock = content.substring(0, startIndex);
      final androidBlock = content.substring(startIndex, endIndex);
      final afterAndroidBlock = content.substring(endIndex); // Conservez le code après le bloc android

      // Suppression de la section `signingConfig` sous `buildTypes`
      final updatedAndroidBlock = androidBlock.replaceAll(
        RegExp(r'buildTypes\s*\{[\s\S]*?release\s*\{[\s\S]*?signingConfig\s*=\s*signingConfigs\.debug\s*\}[\s\S]*?\}', multiLine: true),
        'buildTypes { release { signingConfig = signingConfigs.release } }',
      );

      // Insertion de la configuration `signingConfigs` après `defaultConfig`
      final updatedContent = beforeAndroidBlock + '''
    ${updatedAndroidBlock}

    signingConfigs {
        release {
            keyAlias = keystoreProperties['keyAlias']
            keyPassword = keystoreProperties['keyPassword']
            storeFile = keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword = keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.release
        }
    }
''' + afterAndroidBlock; // Ajoutez le code conservé après le bloc android

      await buildGradleFile.writeAsString(updatedContent);
      print('FlutterAutoSign: Updated build.gradle file.');
    } else {
      print('Could not find the android block in build.gradle. No changes made.');
    }
  }


  static void main(List<String> arguments) async {
    final parser = ArgParser()
      ..addOption('keystorePath', abbr: 'k', help: 'Path to the keystore file')
      ..addOption('keystorePassword', abbr: 'p', help: 'Keystore password')
      ..addOption('keyAlias', abbr: 'a', help: 'Key alias')
      ..addOption('keyPassword', abbr: 'w', help: 'Key password');

    final results = parser.parse(arguments);

    await configure(
      keystorePath: results['keystorePath'],
      keystorePassword: results['keystorePassword'],
      keyAlias: results['keyAlias'],
      keyPassword: results['keyPassword'],
    );
  }
}

