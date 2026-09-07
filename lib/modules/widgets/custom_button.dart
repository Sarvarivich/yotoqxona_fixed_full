import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? color;
  final bool isLoading;
  final bool isOutlined;
  final bool isFullWidth;
  final double? width;
  final double? height;
  final double borderRadius;

  const CustomButton({super.key, 
    required this.text,
    required this.onPressed,
    this.icon,
    this.color,
    this.isLoading = false,
    this.isOutlined = false,
    this.isFullWidth = true,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? Theme.of(context).primaryColor;
    
    Widget button;
    
    if (isOutlined) {
      button = OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading 
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: buttonColor,
                ),
              )
            : Icon(icon ?? Icons.check),
        label: Text(
          text,
          style: TextStyle(fontSize: 16),
        ),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          side: BorderSide(color: buttonColor),
          foregroundColor: buttonColor,
        ),
      );
    } else {
      button = ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading 
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon ?? Icons.check),
        label: Text(
          text,
          style: TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      );
    }
    
    if (isFullWidth) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: button,
      );
    }
    
    return SizedBox(
      width: width,
      height: height,
      child: button,
    );
  }
}

// Loading Button
class LoadingButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final Color? color;
  
  const LoadingButton({super.key, 
    required this.text,
    this.isLoading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isLoading ? Colors.grey.shade400 : (color ?? Theme.of(context).primaryColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}