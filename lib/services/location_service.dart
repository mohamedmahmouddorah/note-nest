import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';


enum LocationOutcome {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class LocationFetchResult {
  final LocationOutcome outcome;
  final Position? position;
  const LocationFetchResult(this.outcome, [this.position]);
}

class LocationService {

  static Future<LocationFetchResult> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationFetchResult(LocationOutcome.serviceDisabled);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationFetchResult(LocationOutcome.permissionDenied);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationFetchResult(
        LocationOutcome.permissionDeniedForever,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationFetchResult(LocationOutcome.success, position);
    } catch (_) {
      return const LocationFetchResult(LocationOutcome.error);
    }
  }


  static Future<Position?> getApproximatePosition() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final age = DateTime.now().difference(lastKnown.timestamp);
        if (age < const Duration(minutes: 15)) return lastKnown;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return lastKnown;

      final permission = await Geolocator.checkPermission();
      final hasPermission = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!hasPermission) return lastKnown;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static double distanceBetweenMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }


  static Future<String> reverseGeocode(double latitude, double longitude) async {
    final hasNativeGeocoding = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    if (hasNativeGeocoding) {
      try {
        final geocoding = Geocoding();
        final placemarks = await geocoding.placemarkFromCoordinates(
          latitude,
          longitude,
        );
        if (placemarks.isEmpty) return 'Saved location';

        final place = placemarks.first;
        final parts = <String>[];

        final street = place.street;
        final locality = place.subLocality ?? place.locality;
        final subAdmin = place.subAdministrativeArea;
        final admin = place.administrativeArea;
        final country = place.country;

        if (street != null && street.trim().isNotEmpty) parts.add(street.trim());
        if (locality != null &&
            locality.trim().isNotEmpty &&
            !parts.contains(locality.trim())) {
          parts.add(locality.trim());
        }
        if (subAdmin != null &&
            subAdmin.trim().isNotEmpty &&
            subAdmin != locality) {
          parts.add(subAdmin.trim());
        }
        if (admin != null && admin.trim().isNotEmpty && admin != subAdmin) {
          parts.add(admin.trim());
        }
        if (country != null && country.trim().isNotEmpty) {
          parts.add(country.trim());
        }

        return parts.isNotEmpty ? parts.join(', ') : 'Saved location';
      } catch (_) {
        return 'Saved location';
      }
    }

    return _reverseGeocodeViaHttp(latitude, longitude);
  }

  static Future<String> _reverseGeocodeViaHttp(double latitude, double longitude) async {
    HttpClient? client;
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$latitude&lon=$longitude&zoom=16&addressdetails=1',
      );

      client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'NoteNestApp/1.0');
      final response = await request.close().timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return 'Saved location';

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;

      if (address == null) {
        final displayName = data['display_name'] as String?;
        return (displayName != null && displayName.trim().isNotEmpty)
            ? displayName.trim()
            : 'Saved location';
      }

      final parts = <String>[];
      final road = address['road'] as String?;
      final neighbourhood = (address['neighbourhood'] ?? address['suburb']) as String?;
      final city = (address['city'] ?? address['town'] ?? address['village']) as String?;
      final state = address['state'] as String?;
      final country = address['country'] as String?;

      if (road != null && road.trim().isNotEmpty) parts.add(road.trim());
      if (neighbourhood != null &&
          neighbourhood.trim().isNotEmpty &&
          !parts.contains(neighbourhood.trim())) {
        parts.add(neighbourhood.trim());
      }
      if (city != null && city.trim().isNotEmpty && !parts.contains(city.trim())) {
        parts.add(city.trim());
      }
      if (state != null && state.trim().isNotEmpty && state != city) {
        parts.add(state.trim());
      }
      if (country != null && country.trim().isNotEmpty) {
        parts.add(country.trim());
      }

      return parts.isNotEmpty ? parts.join(', ') : 'Saved location';
    } catch (_) {
      return 'Saved location';
    } finally {
      client?.close();
    }
  }

  static Future<bool> openSystemLocationSettings() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final opened = await Geolocator.openLocationSettings();
        if (opened) return true;

        return await Geolocator.openAppSettings();
      }

      if (Platform.isWindows) {
        final uri = Uri.parse('ms-settings:privacy-location');
        return await launchUrl(uri);
      }

      if (Platform.isMacOS) {
        final uri = Uri.parse(
          'x-apple.systempreferences:com.apple.preference.security'
          '?Privacy_LocationServices',
        );
        return await launchUrl(uri);
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}
