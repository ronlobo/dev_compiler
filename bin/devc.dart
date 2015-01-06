#!/usr/bin/env dart

/// Command line tool to run the checker on a Dart program.
library ddc.bin.checker;

import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart' show Logger, Level;

import 'package:ddc/devc.dart';
import 'package:ddc/src/checker/dart_sdk.dart'
    show dartSdkDirectory, mockSdkSources;
import 'package:ddc/src/checker/resolver.dart' show TypeResolver;

final ArgParser argParser = new ArgParser()
  ..addFlag(
      'sdk-check', abbr: 's', help: 'Typecheck sdk libs', defaultsTo: false)
  ..addOption('log', abbr: 'l', help: 'Logging level', defaultsTo: 'severe')
  ..addOption('dart-sdk', help: 'Dart SDK Path', defaultsTo: null)
  ..addFlag('dart-gen',
      abbr: 'd', help: 'Generate dart output', defaultsTo: false)
  ..addFlag('dart-gen-fmt',
      help: 'Generate readable dart output', defaultsTo: true)
  ..addFlag('mock-sdk',
      abbr: 'm', help: 'Use a mock Dart SDK', defaultsTo: false)
  ..addFlag('dump-info',
      abbr: 'i', help: 'Dump summary information', defaultsTo: false)
  ..addOption('dump-info-file',
      abbr: 'f',
      help: 'Dump info json file (requires dump-info)',
      defaultsTo: null)
  ..addOption('out', abbr: 'o', help: 'Output directory', defaultsTo: null)
  ..addFlag('help', abbr: 'h', help: 'Display this message');

void _showUsageAndExit() {
  print('usage: dartdevc [<options>] <file.dart>\n');
  print('<file.dart> is a single Dart file to process.\n');
  print('<options> include:\n');
  print(argParser.usage);
  exit(1);
}

void main(List<String> argv) {
  ArgResults args = argParser.parse(argv);
  if (args['help']) _showUsageAndExit();

  bool shouldMockSdk = args['mock-sdk'];
  String dartSdkPath;
  if (!shouldMockSdk) {
    dartSdkPath = args['dart-sdk'];
    if (dartSdkPath == null) dartSdkPath = dartSdkDirectory;
    if (dartSdkPath == null) {
      print('Could not automatically find dart sdk path.');
      print('Please pass in explicitly: --dart-sdk <path>');
      exit(1);
    }
  }

  if (args.rest.length == 0) {
    print('Expected filename.');
    _showUsageAndExit();
  }

  String levelName = args['log'].toUpperCase();
  Level level = Level.LEVELS.firstWhere((Level l) => l.name == levelName,
      orElse: () => Level.SEVERE);
  var useColors = stdioType(stdout) == StdioType.TERMINAL;
  if (!args['dump-info']) setupLogger(level, print);

  var typeResolver = new TypeResolver(shouldMockSdk ?
      TypeResolver.sdkResolverFromMock(mockSdkSources) :
      TypeResolver.sdkResolverFromDir(dartSdkPath));

  var filename = args.rest.first;
  compile(filename, typeResolver,
      checkSdk: args['sdk-check'],
      formatOutput: args['dart-gen-fmt'],
      outputDart: args['dart-gen'],
      dumpInfo: args['dump-info'],
      dumpInfoFile: args['dump-info-file'],
      outputDir: args['out'],
      useColors: useColors).then((success) {
    exit(success ? 0 : 1);
  });
}
