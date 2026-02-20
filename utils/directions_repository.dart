import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:aevavoiceassistant/utils/directions_model.dart';
import 'package:aevavoiceassistant/utils/.env.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsRepository {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json?';

  final Dio _dio;

  DirectionsRepository({Dio? dio}) : _dio = dio ?? Dio();

  Future<Directions> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final response = await _dio.get(
      _baseUrl,
      queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': googleAPIKey,
      },
    );

    // Check if response is successful
    if (response.statusCode == 200) {
      return Directions.fromMap(response.data);
    }

    return Directions(bounds: LatLngBounds(southwest: LatLng(23.785182, 90.330702),
        northeast: LatLng(24.582782, 88.821163)), polylinePoints: null,
        totalDistance: null, totalDuration: null);

  }
}