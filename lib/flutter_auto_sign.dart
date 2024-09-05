library flutter_auto_sign;

/// A Flutter auto sign.
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:prompts/prompts.dart' as prompts;

class FlutterAutoSign {
  /// Configures the signing settings for the app.
  static Future<void> configure({
    String? keystorePath,
    String? keyAlias,
  }) async {
    keystorePath ??= getDefaultKeystorePath();
    keyAlias ??= 'upload-alias';

    if (!await File(keystorePath).exists()) {
      if (prompts.getBool('Keystore does not exist. Create a new one?', defaultsTo: true)) {
        await _createKeystore(keystorePath, keyAlias);
      } else {
        print('Cannot proceed without a valid keystore. Exiting.');
        return;
      }
    }

    await _createKeyProperties(
      keystorePath: keystorePath,
      keyAlias: keyAlias,
    );
    await _updateBuildGradle();

    print('FlutterAutoSign: Configuration completed successfully.');
  }

  static String getDefaultKeystorePath() {
    final homeDir = Platform.isWindows ? Platform.environment['USERPROFILE'] : Platform.environment['HOME'];
    return path.join(homeDir!, 'upload-keystore.jks');
  }

  static Future<void> _createKeystore(String keystorePath, String keyAlias) async {
    final isWindows = Platform.isWindows;

    print('You will be prompted to enter information for your keystore.');
    print('Please follow the prompts from the keytool command.');

    List<String> args;
    if (isWindows) {
      args = [
        '-genkey', '-v',
        '-keystore', keystorePath,
        '-storetype', 'JKS',
        '-keyalg', 'RSA',
        '-keysize', '2048',
        '-validity', '10000',
        '-alias', keyAlias,
      ];
    } else {
      args = [
        '-genkey', '-v',
        '-keystore', keystorePath,
        '-keyalg', 'RSA',
        '-keysize', '2048',
        '-validity', '10000',
        '-alias', keyAlias,
      ];
    }

    try {
      final process = await Process.start('keytool', args, mode: ProcessStartMode.inheritStdio);
      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        print('Error: keytool command failed with exit code $exitCode');
        exit(1);
      }

      print('Keystore created successfully at $keystorePath');
    } catch (e) {
      print('Error executing keytool command: $e');
      print('Please make sure you have Java installed and keytool is available in your PATH.');
      exit(1);
    }
  }

  static Future<void> _createKeyProperties({
    required String keystorePath,
    required String keyAlias,
  }) async {
    final content = '''
storePassword=
keyPassword=
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
      ..addOption('keystorePath', abbr: 'p', help: 'Path to the keystore file')
      ..addOption('keyAlias', abbr: 'a', help: 'Key alias');

    final results = parser.parse(arguments);

    await configure(
      keystorePath: results['keystorePath'],
      keyAlias: results['keyAlias'],
    );
  }
}

