import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_theme.dart';

class LoginSelectionScreen extends StatelessWidget {
  const LoginSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for dynamic sizing
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textWhite),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(w * 0.06), // ~24px relative to width
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Welcome Back",
              style: TextStyle(
                fontSize: w * 0.08, // ~32px
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite,
              ),
            ),
            SizedBox(height: h * 0.01), // ~8px relative to height
            Text(
              "Who are you logging in as?",
              style: TextStyle(
                fontSize: w * 0.04, // ~16px
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: h * 0.06), // ~48px
            _SelectionCard(
              icon: Icons.business,
              title: "Company Login",
              subtitle: "For managers and admins",
              onTap: () => context.push('/login/company'),
              width: w,
              height: h,
            ),
            SizedBox(height: h * 0.02), // ~16px
            _SelectionCard(
              icon: Icons.person_outline,
              title: "Employee Login",
              subtitle: "For drivers and staff",
              onTap: () => context.push('/login/employee'),
              width: w,
              height: h,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double width;
  final double height;

  const _SelectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(width * 0.04), // ~16px
      child: Container(
        padding: EdgeInsets.all(width * 0.06), // ~24px
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(width * 0.04), // ~16px
          border: Border.all(color: AppTheme.border),
          // Subtle glow effect like the website
          boxShadow: [
            BoxShadow(
              // Replaced withOpacity(0.05) with withAlpha(~13)
              color: AppTheme.primary.withAlpha(13),
              blurRadius: width * 0.05, // ~20px
              offset: Offset(0, height * 0.005), // ~4px
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(width * 0.03), // ~12px
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(width * 0.03), // ~12px
              ),
              child: Icon(icon, color: AppTheme.primary, size: width * 0.08), // ~32px
            ),
            SizedBox(width: width * 0.04), // ~16px
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: width * 0.045, // ~18px
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  SizedBox(height: height * 0.005), // ~4px
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: width * 0.035, // ~14px
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: width * 0.04, // ~16px
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}