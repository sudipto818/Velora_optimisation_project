import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/map_provider.dart';
import 'utils/app_theme.dart';
import 'screens/public/landing_screen.dart';
import 'screens/public/login_selection_screen.dart';
import 'screens/public/login_screen.dart';
import 'screens/company/company_dashboard.dart';
import 'screens/company/company_employees_screen.dart';
import 'screens/company/company_vehicles_screen.dart';
import 'screens/company/upload_fleet_screen.dart';
import 'screens/fleet/fleet_detail_screen.dart';
import 'screens/employee/employee_dashboard.dart';
import 'screens/employee/employee_profile_screen.dart';
import 'screens/employee/employee_ride_screen.dart';
import 'screens/vehicle/vehicle_detail_screen.dart';
import 'screens/trip/trip_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Load the .env file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Failed to load .env file: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
      ],
      child: const AppRouter(),
    );
  }
}

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    final router = GoRouter(
      refreshListenable: authProvider,
      initialLocation: '/',
      redirect: (context, state) {
        final isLoading = authProvider.status == AuthStatus.unknown;
        if (isLoading) return null; // Wait for session check

        final loggedIn = authProvider.status == AuthStatus.authenticated;
        final uri = state.uri.toString();
        final isAuthRoute =
            uri == '/' || uri.startsWith('/login') || uri == '/login-selection';

        if (!loggedIn && !isAuthRoute) return '/';
        if (loggedIn && isAuthRoute) {
          if (authProvider.userRole == 'company') return '/company-dashboard';
          if (authProvider.userRole == 'employee') return '/employee-dashboard';
        }
        return null;
      },
      routes: [
        // --- Public ---
        GoRoute(path: '/', builder: (_, _) => const LandingScreen()),
        GoRoute(
          path: '/login-selection',
          builder: (_, _) => const LoginSelectionScreen(),
        ),
        GoRoute(
          path: '/login/:role',
          builder: (_, state) =>
              LoginScreen(role: state.pathParameters['role']!),
        ),

        // --- Company ---
        GoRoute(
          path: '/company-dashboard',
          builder: (_, _) => const CompanyDashboard(),
        ),
        GoRoute(
          path: '/company/employees',
          builder: (_, _) => const CompanyEmployeesScreen(),
        ),
        GoRoute(
          path: '/company/vehicles',
          builder: (_, _) => const CompanyVehiclesScreen(),
        ),
        GoRoute(
          path: '/company/upload',
          builder: (_, _) => const UploadFleetScreen(),
        ),

        // --- Fleet ---
        GoRoute(
          path: '/fleet/:id',
          builder: (_, state) =>
              FleetDetailScreen(fleetId: state.pathParameters['id']!),
        ),

        // --- Employee ---
        GoRoute(
          path: '/employee-dashboard',
          builder: (_, _) => const EmployeeDashboard(),
        ),
        GoRoute(
          path: '/employee/profile',
          builder: (_, _) => const EmployeeProfileScreen(),
        ),
        GoRoute(
          path: '/employee/ride/:id',
          builder: (_, state) =>
              EmployeeRideScreen(tripId: state.pathParameters['id']!),
        ),

        // --- Vehicle ---
        GoRoute(
          path: '/vehicle/:id',
          builder: (_, state) =>
              VehicleDetailScreen(vehicleId: state.pathParameters['id']!),
        ),

        // --- Trip ---
        GoRoute(
          path: '/trip/:id',
          builder: (_, state) =>
              TripDetailScreen(tripId: state.pathParameters['id']!),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Fleet Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme, // Updated to use the new Velora theme
      routerConfig: router,
    );
  }
}
