/// Repository URL parsing and filesystem-target validation.
///
/// The clone flow used to take the last `/`-separated chunk of the URL and
/// `replaceAll('.git', '')`. A trailing slash produced an empty name, which
/// made the target path equal to the repos root — and the pre-clone cleanup
/// then recursively deleted every cloned repository (including `.meta` with
/// reading progress and bookmarks). Keep every path derivation in this file
/// pure and testable; see `test/clone_safety_test.dart`.
library;

import 'dart:io';

/// Result of parsing a clone URL into the pieces needed by [RepoInfo].
typedef RepoUrlParts = ({String owner, String name});

/// Parses [url] into a display owner and a **safe** single-segment repo name.
///
/// Returns null when no safe name can be derived. Accepts full URLs
/// (`https://host/owner/repo`, optional trailing slash, query or fragment) as
/// well as short `owner/repo` input; an owner-only or empty path is rejected.
RepoUrlParts? parseRepoUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } on FormatException {
    return null;
  }
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  // `https://host/owner/` is an owner page, not a repository; the UI resolves
  // bare repo names against the default owner before calling this.
  if (segments.length < 2) return null;

  var name = segments.last;
  // Strip only a trailing `.git`, case-insensitively; `my.git.repo` stays.
  if (name.length > 4 && name.toLowerCase().endsWith('.git')) {
    name = name.substring(0, name.length - 4);
  }
  if (!isSafeRepoName(name)) return null;

  final owner = segments.length >= 2 ? segments[segments.length - 2] : '';
  return (owner: owner, name: name);
}

final RegExp _invalidFileNameChars = RegExp(r'[\\/:*?"<>|\x00-\x1F]');
final RegExp _windowsReservedNames = RegExp(
  r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$',
  caseSensitive: false,
);

/// Whether [name] is safe to use as a single directory name under the repos
/// root on every supported platform.
///
/// Deliberately rejects dot-prefixed names so `.meta` (reading progress,
/// bookmarks, index caches) can never become a clone target.
bool isSafeRepoName(String name) {
  if (name.isEmpty || name == '.' || name == '..') return false;
  if (name.trim().isEmpty) return false;
  if (name.startsWith('.')) return false;
  if (name.endsWith('.') || name.endsWith(' ')) return false;
  if (_invalidFileNameChars.hasMatch(name)) return false;
  if (_windowsReservedNames.hasMatch(name)) return false;
  // Most filesystems cap a single component at 255 bytes; leave margin.
  if (name.length > 200) return false;
  return true;
}

/// Whether [child] is exactly one level below [parent] after normalizing
/// `.`/`..` and separators.
///
/// Used before any recursive delete so a malformed name can never point at the
/// repos root, `.meta`, or an unrelated directory.
bool isDirectChildPath(String parent, String child) {
  final parentSegments = _pathSegments(parent);
  final childSegments = _pathSegments(child);
  if (childSegments.length != parentSegments.length + 1) return false;
  for (var i = 0; i < parentSegments.length; i++) {
    if (parentSegments[i] != childSegments[i]) return false;
  }
  return true;
}

/// Last path segment of [path] after normalization ('' when empty).
String pathBaseName(String path) {
  final segments = _pathSegments(path);
  return segments.isEmpty ? '' : segments.last;
}

List<String> _pathSegments(String path) {
  return Directory(path).absolute.uri
      .normalizePath()
      .pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
}
