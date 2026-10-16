import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _targetFlutterVersion = '3.44.9';
const _expectedApplicationId = 'io.linkfive.example';
const _androidSdkPath = '/Users/thomasmeike/Library/Android/sdk';
const _javaHome =
    '/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home';
const _cocoaPodsBin = '/opt/homebrew/bin';
const _xcodeDeveloperDirectory = '/Applications/Xcode.app/Contents/Developer';
const _nativeBuildTimeout = Duration(minutes: 25);
const _utilityTimeout = Duration(minutes: 2);
const _processCleanupTimeout = Duration(seconds: 15);

void main() {
  test(
    'MMB0012_android_debug_example_build',
    () async {
      final context = _NativeBuildContext.load();
      final build = await _runCommand(
        context.flutterExecutable.path,
        const <String>[
          'build',
          'apk',
          '--debug',
          '--no-pub',
          '--target',
          'lib/main.dart',
        ],
        environment: context.environment,
        workingDirectory: context.exampleDirectory.path,
        timeout: _nativeBuildTimeout,
      );
      _expectSuccessful(build, 'Flutter Android Example build');

      final apk = _file(
        context.exampleDirectory,
        'build/app/outputs/flutter-apk/app-debug.apk',
      );
      _requireNonEmptyFile(apk, 'Android debug APK');

      final aapt = File('$_androidSdkPath/build-tools/36.0.0/aapt');
      _requireExecutable(aapt, 'Android SDK aapt');
      final badgingResult = await _runCommand(
        aapt.path,
        <String>['dump', 'badging', apk.absolute.path],
        environment: context.environment,
        workingDirectory: context.exampleDirectory.path,
        timeout: _utilityTimeout,
      );
      _expectSuccessful(badgingResult, 'aapt dump badging');
      final badging = badgingResult.stdout;
      expect(
        badging.trim(),
        isNotEmpty,
        reason: 'aapt dump badging returned no readable APK metadata.',
      );

      final packageAttributes = _androidPackageAttributes(badging);
      expect(packageAttributes['name'], _expectedApplicationId);
      expect(packageAttributes['compileSdkVersion'], '36');
      expect(_androidBadgingValue(badging, 'targetSdkVersion'), '36');
      expect(_androidBadgingValue(badging, 'sdkVersion'), '24');

      // Keep the effective artifact contract visible in the machine-test log.
      // ignore: avoid_print
      print(
        'MMB0012_ANDROID_ARTIFACT '
        'package=${packageAttributes['name']} '
        'compileSdk=${packageAttributes['compileSdkVersion']} '
        'targetSdk=${_androidBadgingValue(badging, 'targetSdkVersion')} '
        'minSdk=${_androidBadgingValue(badging, 'sdkVersion')} '
        'apk=${apk.absolute.path}',
      );
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );

  test(
    'MMB0012_ios_simulator_example_build',
    () async {
      final context = _NativeBuildContext.load();
      final build = await _runCommand(
        context.flutterExecutable.path,
        const <String>[
          'build',
          'ios',
          '--simulator',
          '--debug',
          '--no-codesign',
          '--no-pub',
          '--target',
          'lib/main.dart',
        ],
        environment: context.environment,
        workingDirectory: context.exampleDirectory.path,
        timeout: _nativeBuildTimeout,
      );
      _expectSuccessful(build, 'Flutter iOS Simulator Example build');

      final builtApp = await _singleBuiltIosApp(
        context,
        _expectedApplicationId,
      );
      final plist = builtApp.infoPlist;
      expect(plist['CFBundleIdentifier'], _expectedApplicationId);
      expect(plist['UIMainStoryboardFile'], 'Main');

      final sceneManifest = _jsonObject(
        plist['UIApplicationSceneManifest'],
        'UIApplicationSceneManifest',
      );
      expect(sceneManifest['UIApplicationSupportsMultipleScenes'], isFalse);
      final configurations = _jsonObject(
        sceneManifest['UISceneConfigurations'],
        'UIApplicationSceneManifest.UISceneConfigurations',
      );
      final applicationScenes =
          configurations['UIWindowSceneSessionRoleApplication'];
      expect(
        applicationScenes,
        isA<List<dynamic>>(),
        reason: 'The built plist must declare application scene entries.',
      );
      final scenes = applicationScenes! as List<dynamic>;
      expect(
        scenes,
        hasLength(1),
        reason: 'Exactly one application scene must be configured.',
      );
      final scene = _jsonObject(
        scenes.single,
        'UIWindowSceneSessionRoleApplication[0]',
      );
      expect(scene['UISceneClassName'], 'UIWindowScene');
      expect(scene['UISceneDelegateClassName'], 'FlutterSceneDelegate');
      expect(scene['UISceneConfigurationName'], 'flutter');
      expect(scene['UISceneStoryboardFile'], 'Main');

      final minimumOsVersion = plist['MinimumOSVersion'];
      expect(
        minimumOsVersion,
        isA<String>(),
        reason: 'The built plist must expose its effective MinimumOSVersion.',
      );
      expect(
        minimumOsVersion as String,
        matches(RegExp(r'^15(?:\.0)*$')),
        reason: 'The Example must keep an effective iOS deployment target 15.',
      );

      // Keep the effective artifact contract visible in the machine-test log.
      // ignore: avoid_print
      print(
        'MMB0012_IOS_ARTIFACT '
        'bundle=${plist['CFBundleIdentifier']} '
        'minimumOS=$minimumOsVersion '
        'scenes=${scenes.length} '
        'delegate=${scene['UISceneDelegateClassName']} '
        'storyboard=${scene['UISceneStoryboardFile']} '
        'app=${builtApp.directory.absolute.path}',
      );
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

class _NativeBuildContext {
  const _NativeBuildContext({
    required this.exampleDirectory,
    required this.flutterExecutable,
    required this.environment,
  });

  factory _NativeBuildContext.load() {
    final exampleDirectory = Directory.current.absolute;
    _requireNonEmptyFile(
      _file(exampleDirectory, 'pubspec.yaml'),
      'Example pubspec',
    );

    final appRoot = _findAppRoot(exampleDirectory);
    final expectedExample = _directory(
      appRoot,
      'subrepos/flutter-in_app_purchases_paywall/example',
    );
    final actualExamplePath = exampleDirectory.resolveSymbolicLinksSync();
    final expectedExamplePath = expectedExample.resolveSymbolicLinksSync();
    if (actualExamplePath != expectedExamplePath) {
      throw StateError(
        'Native builds must run from the bound Paywall Example directory. '
        'Actual: $actualExamplePath; expected: $expectedExamplePath',
      );
    }

    final fvmPin = _readJsonObject(_file(appRoot, '.fvmrc'));
    if (fvmPin['flutter'] != _targetFlutterVersion) {
      throw StateError(
        'The App FVM pin is ${fvmPin['flutter']}; '
        'expected exactly $_targetFlutterVersion.',
      );
    }

    final flutterSdkLink = _directory(appRoot, '.fvm/flutter_sdk');
    if (!flutterSdkLink.existsSync()) {
      throw StateError(
        'The App FVM SDK link is missing: ${flutterSdkLink.path}',
      );
    }
    final flutterSdk = Directory(flutterSdkLink.resolveSymbolicLinksSync());
    final versionFile = _file(flutterSdk, 'bin/cache/flutter.version.json');
    final version = _readJsonObject(versionFile);
    if (version['frameworkVersion'] != _targetFlutterVersion) {
      throw StateError(
        'The resolved App FVM SDK is ${version['frameworkVersion']}; '
        'expected exactly $_targetFlutterVersion at ${flutterSdk.path}.',
      );
    }

    final flutterExecutable = _file(flutterSdk, 'bin/flutter');
    _requireExecutable(flutterExecutable, 'Flutter executable');
    _requireExecutable(File('$_javaHome/bin/java'), 'Java 17 executable');
    _requireExecutable(File('$_cocoaPodsBin/pod'), 'CocoaPods executable');
    _requireNonEmptyFile(
      File('$_androidSdkPath/platforms/android-36/android.jar'),
      'Android Platform 36',
    );

    final inheritedPath = Platform.environment['PATH'] ?? '';
    final environment = <String, String>{
      ...Platform.environment,
      'FLUTTER_ROOT': flutterSdk.path,
      'JAVA_HOME': _javaHome,
      'ANDROID_HOME': _androidSdkPath,
      'ANDROID_SDK_ROOT': _androidSdkPath,
      'DEVELOPER_DIR': _xcodeDeveloperDirectory,
      'PATH': <String>[
        _directory(flutterSdk, 'bin').path,
        '$_javaHome/bin',
        '$_androidSdkPath/platform-tools',
        '$_androidSdkPath/cmdline-tools/latest/bin',
        '$_androidSdkPath/emulator',
        _cocoaPodsBin,
        inheritedPath,
      ].where((entry) => entry.isNotEmpty).join(':'),
    };

    return _NativeBuildContext(
      exampleDirectory: exampleDirectory,
      flutterExecutable: flutterExecutable,
      environment: environment,
    );
  }

  final Directory exampleDirectory;
  final File flutterExecutable;
  final Map<String, String> environment;
}

Directory _findAppRoot(Directory start) {
  var candidate = start.absolute;
  while (true) {
    if (_file(candidate, '.fvmrc').existsSync()) {
      return candidate;
    }
    final parent = candidate.parent;
    if (parent.path == candidate.path) {
      throw StateError(
        'Unable to find the App root with .fvmrc above ${start.path}.',
      );
    }
    candidate = parent;
  }
}

Future<_BuiltIosApp> _singleBuiltIosApp(
  _NativeBuildContext context,
  String bundleIdentifier,
) async {
  final root = _directory(
    context.exampleDirectory,
    'build/ios/iphonesimulator',
  );
  if (!root.existsSync()) {
    throw StateError(
      'The successful iOS build produced no simulator output directory: '
      '${root.absolute.path}',
    );
  }

  final discovered = <String>[];
  final matching = <_BuiltIosApp>[];
  final appDirectories =
      root
          .listSync(followLinks: false)
          .whereType<Directory>()
          .where((directory) => directory.path.endsWith('.app'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));
  for (final app in appDirectories) {
    final plist = await _readInfoPlist(context, app);
    final actualBundleIdentifier = plist['CFBundleIdentifier'];
    discovered.add('${app.absolute.path}: $actualBundleIdentifier');
    if (actualBundleIdentifier == bundleIdentifier) {
      matching.add(_BuiltIosApp(directory: app, infoPlist: plist));
    }
  }

  if (matching.length != 1) {
    throw StateError(
      'Expected exactly one built .app with bundle identifier '
      '$bundleIdentifier under ${root.absolute.path}, found '
      '${matching.length}. Discovered: '
      '${discovered.isEmpty ? 'none' : discovered.join(', ')}',
    );
  }
  return matching.single;
}

Future<Map<String, dynamic>> _readInfoPlist(
  _NativeBuildContext context,
  Directory app,
) async {
  final infoPlist = _file(app, 'Info.plist');
  _requireNonEmptyFile(infoPlist, 'built iOS Info.plist');
  final result = await _runCommand(
    '/usr/bin/plutil',
    <String>['-convert', 'json', '-o', '-', infoPlist.absolute.path],
    environment: context.environment,
    workingDirectory: context.exampleDirectory.path,
    timeout: _utilityTimeout,
  );
  _expectSuccessful(result, 'plutil ${infoPlist.absolute.path}');
  final decoded = jsonDecode(result.stdout);
  if (decoded is! Map<String, dynamic>) {
    throw StateError(
      'plutil did not return an Info.plist dictionary for '
      '${infoPlist.absolute.path}.',
    );
  }
  return decoded;
}

Map<String, dynamic> _jsonObject(Object? value, String description) {
  if (value is! Map<String, dynamic>) {
    throw StateError('$description must be a dictionary, got $value.');
  }
  return value;
}

Map<String, String> _androidPackageAttributes(String badging) {
  final packageLines = badging
      .split(RegExp(r'\r?\n'))
      .where((line) => line.startsWith('package:'))
      .toList();
  if (packageLines.length != 1) {
    throw StateError(
      'Expected exactly one package line in aapt badging, found '
      '${packageLines.length}.',
    );
  }
  return <String, String>{
    for (final match in RegExp(
      r"([A-Za-z][A-Za-z0-9]*)='([^']*)'",
    ).allMatches(packageLines.single))
      match.group(1)!: match.group(2)!,
  };
}

String _androidBadgingValue(String badging, String key) {
  final match = RegExp(
    "^${RegExp.escape(key)}:'([^']+)'\\r?\$",
    multiLine: true,
  ).firstMatch(badging);
  if (match == null) {
    throw StateError('aapt badging does not contain $key.');
  }
  return match.group(1)!;
}

Map<String, dynamic> _readJsonObject(File file) {
  _requireNonEmptyFile(file, 'JSON file');
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('${file.absolute.path} is not a JSON object.');
  }
  return decoded;
}

Directory _directory(Directory root, String relativePath) {
  return Directory.fromUri(root.uri.resolve('$relativePath/'));
}

File _file(Directory root, String relativePath) {
  return File.fromUri(root.uri.resolve(relativePath));
}

void _requireNonEmptyFile(File file, String description) {
  if (!file.existsSync()) {
    throw StateError('$description is missing: ${file.absolute.path}');
  }
  if (file.lengthSync() == 0) {
    throw StateError('$description is empty: ${file.absolute.path}');
  }
}

void _requireExecutable(File file, String description) {
  _requireNonEmptyFile(file, description);
  if ((file.statSync().mode & 0x49) == 0) {
    throw StateError('$description is not executable: ${file.absolute.path}');
  }
}

Future<_CommandResult> _runCommand(
  String executable,
  List<String> arguments, {
  required Map<String, String> environment,
  required String workingDirectory,
  required Duration timeout,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    environment: environment,
    includeParentEnvironment: false,
    runInShell: false,
    workingDirectory: workingDirectory,
  );
  await process.stdin.close();
  final stdoutFuture = process.stdout.transform(utf8.decoder).join();
  final stderrFuture = process.stderr.transform(utf8.decoder).join();
  final exitCodeFuture = process.exitCode;

  var timedOut = false;
  late int exitCode;
  try {
    exitCode = await exitCodeFuture.timeout(timeout);
  } on TimeoutException {
    timedOut = true;
    process.kill(ProcessSignal.sigterm);
    try {
      exitCode = await exitCodeFuture.timeout(_processCleanupTimeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      exitCode = await exitCodeFuture;
    }
  }

  final outputs = await Future.wait(<Future<String>>[
    stdoutFuture,
    stderrFuture,
  ]);
  final result = _CommandResult(
    executable: executable,
    arguments: arguments,
    exitCode: exitCode,
    stdout: outputs[0],
    stderr: outputs[1],
  );
  if (timedOut) {
    fail(
      'Process exceeded ${timeout.inMinutes} minutes and was terminated '
      'with TERM/KILL cleanup.\n${result.diagnostics}',
    );
  }
  return result;
}

void _expectSuccessful(_CommandResult result, String description) {
  expect(
    result.exitCode,
    0,
    reason: '$description failed.\n${result.diagnostics}',
  );
}

class _CommandResult {
  const _CommandResult({
    required this.executable,
    required this.arguments,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final String executable;
  final List<String> arguments;
  final int exitCode;
  final String stdout;
  final String stderr;

  String get diagnostics => <String>[
    'command: $executable ${arguments.join(' ')}',
    'exit: $exitCode',
    'stdout:',
    stdout,
    'stderr:',
    stderr,
  ].join('\n');
}

class _BuiltIosApp {
  const _BuiltIosApp({required this.directory, required this.infoPlist});

  final Directory directory;
  final Map<String, dynamic> infoPlist;
}
