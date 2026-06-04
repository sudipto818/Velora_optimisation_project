import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ApiService {
  static final _baseUrl = dotenv.env['API_URL'] ?? 'http://10.0.2.2:3000';
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      validateStatus: (status) => status! < 500,
    ),
  );

  final _storage = const FlutterSecureStorage();
  final Function() onUnauthenticated;

  ApiService({required this.onUnauthenticated}) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            debugPrint("Session expired. Logging out.");
            await _storage.deleteAll();
            onUnauthenticated();
          }
          return handler.next(e);
        },
      ),
    );
  }

  // ===================== AUTH =====================

  /// Login - matches backend: POST /auth/login/employee or /auth/login/company
  Future<Map<String, dynamic>> login(
    String email,
    String password,
    String type,
  ) async {
    // Backend has separate endpoints for employee and company
    final endpoint = type == 'employee'
        ? '/auth/login/employee'
        : '/auth/login/company';

    final response = await _dio.post(
      endpoint,
      data: {'email': email, 'password': password},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data;
      if (data['token'] != null) {
        await _storage.write(key: 'token', value: data['token']);
      }
      final userId = data['user']?['_id'] ?? data['user']?['id'];
      if (userId != null) {
        await _storage.write(key: 'userId', value: userId);
      }
      debugPrint('🚨🚨🚨🚨:${data['token']}');
      return data;
    } else {
      throw Exception(response.data['message'] ?? 'Login failed');
    }
  }

  /// Verify token - matches backend: GET /auth/verify
  Future<Map<String, dynamic>?> verifyToken() async {
    try {
      final response = await _dio.get('/auth/verify');
      if (response.statusCode == 200) return response.data;
      return null;
    } catch (e) {
      return null;
    }
  }

  // ===================== COMPANY =====================

  Future<Map<String, dynamic>> fetchCompanyDashboard(String companyId) async {
    final response = await _dio.get('/company/dashboard/$companyId');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data['data'];
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch dashboard');
  }

  /// Company fleets - matches backend: GET /company/fleets/:id
  Future<Map<String, dynamic>> fetchCompanyFleets(
    String companyId, {
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _dio.get(
      '/company/fleets/$companyId',
      queryParameters: {'page': page, 'limit': limit},
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch fleets');
  }

  /// Company employees - matches backend: GET /company/employees/:id
  Future<Map<String, dynamic>> fetchCompanyEmployees(
    String companyId, {
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _dio.get(
      '/company/employees/$companyId',
      queryParameters: {'page': page, 'limit': limit},
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch employees');
  }

  /// Company vehicles - matches backend: GET /company/vehicles/:id
  Future<Map<String, dynamic>> fetchCompanyVehicles(
    String companyId, {
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _dio.get(
      '/company/vehicles/$companyId',
      queryParameters: {'page': page, 'limit': limit},
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch vehicles');
  }

  /// Update company - matches backend: PUT /company/update/:id
  Future<Map<String, dynamic>> updateCompany(
    String companyId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _dio.put(
      '/company/update/$companyId',
      data: updates,
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(response.data['message'] ?? 'Failed to update company');
  }

  // ===================== FLEET =====================

  /// Get all fleets with filters - matches backend: GET /fleet/
  Future<Map<String, dynamic>> fetchFleets({
    String? companyId,
    String? days,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (companyId != null) params['company'] = companyId;
    if (days != null) params['days'] = days;

    final response = await _dio.get('/fleet', queryParameters: params);
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch fleets');
  }

  /// Fleet details - matches backend: GET /fleet/:id
  Future<Map<String, dynamic>> fetchFleetById(String fleetId) async {
    final response = await _dio.get('/fleet/$fleetId');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data['fleet'];
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch fleet');
  }

  /// Delete fleet - matches backend: DELETE /fleet/:id
  Future<Map<String, dynamic>> deleteFleet(String fleetId) async {
    final response = await _dio.delete('/fleet/$fleetId');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(response.data['message'] ?? 'Failed to delete fleet');
  }

  /// Fleet vehicles - matches backend: GET /fleet/:id/vehicles
  Future<Map<String, dynamic>> fetchFleetVehicles(
    String fleetId, {
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _dio.get(
      '/fleet/$fleetId/vehicles',
      queryParameters: {'page': page, 'limit': limit},
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch fleet vehicles',
    );
  }

  /// Fleet employees - matches backend: GET /fleet/:id/employees
  Future<Map<String, dynamic>> fetchFleetEmployees(
    String fleetId, {
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _dio.get(
      '/fleet/$fleetId/employees',
      queryParameters: {'page': page, 'limit': limit},
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch fleet employees',
    );
  }

  /// Upload fleet file - matches backend: POST /upload
  Future<Map<String, dynamic>> uploadFleetFile(
    String filePath,
    String companyId, {
    List<String> days = const ["Mon", "Tue", "Wed", "Thu", "Fri"],
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'companyId': companyId,
      'days': jsonEncode(days), // Using jsonEncode to pass a valid JSON string
    });

    final response = await _dio.post(
      '/upload',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 120), // Uploads may take longer
        receiveTimeout: const Duration(seconds: 120),
      ),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(response.data['message'] ?? 'Failed to upload fleet file');
  }

  // ===================== EMPLOYEE =====================

  /// Employee profile - matches backend: GET /employee/profile/:id
  Future<Map<String, dynamic>> fetchEmployeeProfile(String employeeId) async {
    final response = await _dio.get('/employee/profile/$employeeId');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch profile');
  }

  /// Employee ride details - matches backend: GET /employee/ride/:id
  Future<Map<String, dynamic>> fetchEmployeeRideDetails(
    String employeeId,
  ) async {
    final response = await _dio.get('/employee/ride/$employeeId');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch ride details');
  }

  /// Employee fleets - matches backend: GET /employee/fleets/:id
  Future<Map<String, dynamic>> fetchEmployeeFleets(String employeeId) async {
    final response = await _dio.get('/employee/fleets/$employeeId');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch employee fleets',
    );
  }

  /// Employee fleets by day - matches backend: GET /employee/fleets/:id/filter
  Future<Map<String, dynamic>> fetchEmployeeFleetsByDay(
    String employeeId,
    String day,
  ) async {
    final response = await _dio.get(
      '/employee/fleets/$employeeId/filter',
      queryParameters: {'days': day},
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(response.data['message'] ?? 'Failed to filter fleets');
  }

  /// Update employee details - matches backend: POST /employee/update/:id
  Future<Map<String, dynamic>> updateEmployeeDetails(
    String employeeId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _dio.post(
      '/employee/update/$employeeId',
      data: updates,
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(
      response.data['message'] ?? 'Failed to update employee details',
    );
  }

  /// Submit complex dynamic changes - matches backend: POST /dynamic/
  Future<Map<String, dynamic>> submitDynamicChanges(
    String companyId,
    String fleetId,
    String employeeId,
    Map<String, dynamic> changes,
  ) async {
    // Inject the employee ID into the changes payload
    changes['employeeId'] = employeeId;
    changes['action'] = 'update';

    final response = await _dio.post(
      '/dynamic/',
      data: {
        'companyId': companyId,
        'fleetId': fleetId,
        'changes': [changes],
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(
      response.data['message'] ?? 'Failed to complete dynamic updates',
    );
  }

  // ===================== VEHICLE =====================

  /// Fetch vehicle by id - matches backend: GET /vehicle/:id
  Future<Map<String, dynamic>> fetchVehicleById(String vehicleId) async {
    final response = await _dio.get('/vehicle/$vehicleId');
    if (response.statusCode == 200) {
      // Backend returns the vehicle directly or inside a property depending on implementation
      // Assuming it returns the direct vehicle object based on backend standard
      return response.data;
    }
    throw Exception('Vehicle not found');
  }

  // ===================== TRIPS =====================

  /// Fetch Trips - matches backend: GET /trip
  Future<Map<String, dynamic>> fetchTrips({
    String? fleetId,
    String? vehicleId,
    String? status,
    String? employeeId,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (fleetId != null) params['fleet'] = fleetId;
    if (vehicleId != null) params['vehicle'] = vehicleId;
    if (status != null) params['status'] = status;
    if (employeeId != null) params['employee'] = employeeId;

    final response = await _dio.get('/trip', queryParameters: params);
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data;
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch trips');
  }

  /// Fetch Trip by ID - matches backend GET /trip/:id
  Future<Map<String, dynamic>> fetchTripById(String tripId) async {
    final response = await _dio.get('/trip/$tripId');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data['trip'];
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch trip details');
  }

  // Separate Dio instance for Google APIs (no auth interceptors/base URL)
  static final Dio _googleDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    ),
  );

  /// Fetch Directions from Google Maps (Proxy or direct)
  Future<Map<String, dynamic>> fetchDirections(
    String origin,
    String destination,
    String waypointsParam,
    String apiKey,
  ) async {
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination$waypointsParam&key=$apiKey";
    debugPrint("📍 Directions API URL: $url");
    final response = await _googleDio.get(url);
    debugPrint("📍 Directions API status: ${response.statusCode}");
    debugPrint(
      "📍 Directions API response status field: ${response.data['status']}",
    );
    if (response.statusCode == 200 && response.data['status'] == 'OK') {
      return response.data;
    }
    throw Exception(
      'Failed to fetch directions: ${response.data['status']} - ${response.data['error_message'] ?? 'Unknown error'}',
    );
  }

  /// Fetch Geolocation Name (Reverse Geocoding)
  Future<String> fetchLocationName(
    double lat,
    double lng,
    String apiKey,
  ) async {
    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey";
    try {
      final response = await _googleDio.get(url);
      if (response.statusCode == 200) {
        final results = response.data['results'] as List<dynamic>;
        if (results.isNotEmpty) {
          String formattedAddress =
              results[0]['formatted_address'] ?? 'Unknown Location';
          // Split to avoid extremely long addresses breaking the UI
          List<String> parts = formattedAddress.split(',');
          if (parts.length >= 2) {
            return "${parts[0]}, ${parts[1]}".trim();
          }
          return formattedAddress;
        }
      }
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
    }
    return 'Unknown Location';
  }

  /// Fetches the route polyline between two LatLng points using Google Directions API
  Future<String?> fetchRoutePolyline(
    LatLng origin,
    LatLng destination,
    String apiKey,
  ) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$apiKey';

    try {
      final response = await _googleDio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          return data['routes'][0]['overview_polyline']['points'] as String?;
        } else {
          debugPrint('Directions API Error: ${data['status']}');
        }
      } else {
        debugPrint(
          'Failed to load directions. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching directions: $e');
    }
    return null;
  }
}
