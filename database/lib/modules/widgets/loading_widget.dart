import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final double size;

  const LoadingWidget({super.key, this.message, this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? Theme.of(context).primaryColor,
            ),
            strokeWidth: 3,
          ),
          if (message != null) ...[
            SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

// Full Screen Loading
class FullScreenLoading extends StatelessWidget {
  final String? message;

  const FullScreenLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            if (message != null) ...[
              SizedBox(height: 16),
              Text(message!, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
    );
  }
}

// Shimmer Loading Effect
class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({super.key, required this.child, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    return Shimmer(
      linearGradient: LinearGradient(
        colors: [
          Colors.grey.shade300,
          Colors.grey.shade100,
          Colors.grey.shade300,
        ],
        stops: [0.0, 0.5, 1.0],
        begin: Alignment(-1.0, 0.0),
        end: Alignment(1.0, 0.0),
      ),
      child: Opacity(opacity: 0.3, child: child),
    );
  }
}

// Simple Shimmer (no external package)
class Shimmer extends StatelessWidget {
  final LinearGradient linearGradient;
  final Widget child;

  const Shimmer({super.key, required this.linearGradient, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(linearGradient: linearGradient, child: child);
  }
}

class ShimmerWidget extends StatefulWidget {
  final LinearGradient linearGradient;
  final Widget child;

  const ShimmerWidget({super.key, required this.linearGradient, required this.child});

  @override
  _ShimmerWidgetState createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5);
    _animation = _controller.drive(CurveTween(curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return widget.linearGradient.createShader(
              Rect.fromLTRB(
                bounds.left - bounds.width * _animation.value,
                0,
                bounds.right - bounds.width * _animation.value,
                bounds.height,
              ),
            );
          },
          child: widget.child,
        );
      },
    );
  }
}
