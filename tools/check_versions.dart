#!/usr/bin/env dart
// ignore_for_file: avoid_print
/// Validates (and optionally fixes) sibling dependency version constraints
/// across all Titan packages.
///
/// Usage:
///   dart run tools/check_versions.dart          # Check only
///   dart run tools/check_versions.dart --fix     # Auto-fix stale constraints
///
/// Exit codes:
///   0 — all constraints match current sibling versions
///   1 — stale constraints found (use --fix to update)
library;

import 'dart:io';

/// Titan packages that can be published (excludes titan_example).
const _packages = [
  'titan',
  'titan_basalt',
  'titan_bastion',
  'titan_atlas',
  'titan_argus',
  'titan_colossus',
  'titan_envoy',
];

void main(List<String> args) {
  final fix = args.contains('--fix');
  final packagesDir = Directory('packages');

  if (!packagesDir.existsSync()) {
    print('Error: run from the workspace root (packages/ not found)');
    exit(2);
  }

  // 1. Collect current versions
  final versions = <String, String>{};
  for (final pkg in _packages) {
    final pubspec = File('packages/$pkg/pubspec.yaml');
    if (!pubspec.existsSync()) {
      print('Warning: packages/$pkg/pubspec.yaml not found');
      continue;
    }
    final content = pubspec.readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(content);
    if (match != null) {
      versions[pkg] = match.group(1)!;
    }
  }

  print('');
  print('Package versions:');
  for (final entry in versions.entries) {
    print('  ${entry.key}: ${entry.value}');
  }
  print('');

  // 2. Check all cross-references
  var staleCount = 0;
  var fixedCount = 0;

  for (final pkg in _packages) {
    final pubspecFile = File('packages/$pkg/pubspec.yaml');
    if (!pubspecFile.existsSync()) continue;

    var content = pubspecFile.readAsStringSync();
    var modified = false;

    for (final dep in _packages) {
      if (dep == pkg) continue;

      // Match lines like: "  titan_basalt: ^1.0.0"
      // Handles both dependencies: and dev_dependencies: sections
      final pattern = RegExp(
        r'(\s+' + RegExp.escape(dep) + r':\s+)\^(\d+\.\d+\.\d+)',
      );

      for (final match in pattern.allMatches(content)) {
        final constraintVersion = match.group(2)!;
        final currentVersion = versions[dep];

        if (currentVersion == null) continue;

        if (constraintVersion != currentVersion) {
          staleCount++;
          print(
            '  STALE  $pkg -> $dep: ^$constraintVersion '
            '(current: $currentVersion)',
          );

          if (fix) {
            content = content.replaceFirst(
              match.group(0)!,
              '${match.group(1)}^$currentVersion',
            );
            modified = true;
            fixedCount++;
          }
        }
      }
    }

    if (modified) {
      pubspecFile.writeAsStringSync(content);
      print('  FIXED  packages/$pkg/pubspec.yaml');
    }
  }

  // 3. Summary
  print('');
  if (staleCount == 0) {
    print('All sibling dependency constraints are up to date.');
    exit(0);
  } else if (fix) {
    print('Fixed $fixedCount stale constraint(s).');
    print('Run "dart pub get" to update the lockfile.');
    exit(0);
  } else {
    print('Found $staleCount stale constraint(s).');
    print('Run with --fix to auto-update them.');
    exit(1);
  }
}
