import 'package:flutter/material.dart';

class Loading {
  Loading(this.context);

  final BuildContext context;
  bool _isShowing = false;

  void start() {
    if (_isShowing) {
      return;
    }

    _isShowing = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: const SimpleDialog(
            elevation: 0.0,
            backgroundColor: Colors.transparent,
            children: [
              Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _isShowing = false;
    });
  }

  void stop() {
    if (!_isShowing) {
      return;
    }

    _isShowing = false;

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
