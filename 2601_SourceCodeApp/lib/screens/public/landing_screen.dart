import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_theme.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.background,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF050505), Color(0xFF0F0F0F)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.06),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Text(
                    "V",
                    style: TextStyle(
                      fontSize: w * 0.35,
                      color: AppTheme.primary,
                    ),
                  ),
                  SizedBox(height: h * 0.04),
                  Text(
                    "VELORA FLEET",
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: w * 0.08,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: h * 0.02),
                  Text(
                    "Designed for Enterprise Efficiency.\nPrecision tracking and dynamic routing.",
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: w * 0.04,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: h * 0.07,
                    child: ElevatedButton(
                      onPressed: () => context.push('/login-selection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        shadowColor: AppTheme.primary.withAlpha(102), // 0.4
                        elevation: 8,
                      ),
                      child: Text(
                        "Get Started",
                        style: TextStyle(
                          fontSize: w * 0.045,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: h * 0.06),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
