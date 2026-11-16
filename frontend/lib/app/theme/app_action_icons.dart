import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Platform-aware icons for common application actions.
///
/// Keeps action icon choices consistent across features without
/// coupling presentation components to a particular platform.
abstract final class AppActionIcons {
  static bool _useCupertino(TargetPlatform platform) {
    if (kIsWeb) return false;

    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  static IconData edit(BuildContext context) {
    return _useCupertino(Theme.of(context).platform)
        ? CupertinoIcons.pencil
        : Icons.edit_outlined;
  }

  static IconData delete(BuildContext context) {
    return _useCupertino(Theme.of(context).platform)
        ? CupertinoIcons.trash
        : Icons.delete_outline_rounded;
  }

  static IconData add(BuildContext context) {
    return _useCupertino(Theme.of(context).platform)
        ? CupertinoIcons.add
        : Icons.add_rounded;
  }

  static IconData more(BuildContext context) {
    return _useCupertino(Theme.of(context).platform)
        ? CupertinoIcons.ellipsis
        : Icons.more_vert_rounded;
  }

  static IconData close(BuildContext context) {
    return _useCupertino(Theme.of(context).platform)
        ? CupertinoIcons.xmark
        : Icons.close_rounded;
  }
}
