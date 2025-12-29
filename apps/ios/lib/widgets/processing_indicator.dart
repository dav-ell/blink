import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class ProcessingIndicator extends StatelessWidget {
  final double? elapsedSeconds;
  final bool isPending;
  final bool small;

  const ProcessingIndicator({
    super.key,
    this.elapsedSeconds,
    this.isPending = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? AppTheme.spacingXSmall : AppTheme.spacingSmall,
        vertical: small ? 4 : AppTheme.spacingXSmall,
      ),
      decoration: BoxDecoration(
        color: (isDark
                ? AppTheme.thinkingColor.withOpacity(0.2)
                : AppTheme.thinkingColor.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: small ? 12 : 16,
            height: small ? 12 : 16,
            child: CupertinoActivityIndicator(
              radius: small ? 6 : 8,
              color: AppTheme.thinkingColor,
            ),
          ),
          SizedBox(width: small ? 4 : AppTheme.spacingXSmall),
          Text(
            _getStatusText(),
            style: TextStyle(
              fontSize: small ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.thinkingColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    if (isPending) {
      return 'Pending...';
    }
    
    if (elapsedSeconds == null) {
      return 'Processing...';
    }
    
    final seconds = elapsedSeconds!.toInt();
    if (seconds < 60) {
      return 'Processing ${seconds}s';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return 'Processing ${minutes}m ${remainingSeconds}s';
    }
  }
}

