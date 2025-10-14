class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final String baseUrl = 'https://api.example.com';

  // طلب GET
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      // منطق الطلب
      return {'status': 'success', 'data': []};
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // طلب POST
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      // منطق الطلب
      return {'status': 'success', 'data': data};
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // طلب PUT
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      // منطق الطلب
      return {'status': 'success', 'data': data};
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // طلب DELETE
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      // منطق الطلب
      return {'status': 'success'};
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }
}
