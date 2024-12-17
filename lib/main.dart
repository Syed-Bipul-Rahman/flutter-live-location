import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

void main() {
  runApp(const LiveLocationApp());
}

class LiveLocationApp extends StatefulWidget {
  const LiveLocationApp({super.key});

  @override
  State<LiveLocationApp> createState() => _LiveLocationAppState();
}

class _LiveLocationAppState extends State<LiveLocationApp> {
  late GoogleMapController _mapController;
  Location _location = Location();
  LatLng _currentPosition = const LatLng(0, 0);
  LatLng _targetLocation = const LatLng(23.8103, 90.4125);

  Marker _userMarker =
      const Marker(markerId: MarkerId("user_marker"), position: LatLng(0, 0));
  Marker _targetMarker = const Marker(
    markerId: MarkerId("target_marker"),
    position: LatLng(23.748795207974442, 90.57620608223354),
    infoWindow: InfoWindow(title: "Target Location"),
  );

  Set<Polyline> _polylines = {};
  String _distanceText = "Calculating...";

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }


  void _fitMarkersInView() {
    if (_currentPosition == const LatLng(0, 0)) return;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        _currentPosition.latitude < _targetLocation.latitude
            ? _currentPosition.latitude
            : _targetLocation.latitude,
        _currentPosition.longitude < _targetLocation.longitude
            ? _currentPosition.longitude
            : _targetLocation.longitude,
      ),
      northeast: LatLng(
        _currentPosition.latitude > _targetLocation.latitude
            ? _currentPosition.latitude
            : _targetLocation.latitude,
        _currentPosition.longitude > _targetLocation.longitude
            ? _currentPosition.longitude
            : _targetLocation.longitude,
      ),
    );

    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _updateTargetLocation(LatLng newTarget) {
    setState(() {
      _targetLocation = newTarget;

      _targetMarker = Marker(
        markerId: const MarkerId("target_marker"),
        position: newTarget,
        infoWindow: const InfoWindow(title: "New Target Location"),
      );

      // Recalculate the route and fit the view
      _fetchRoute();
      _fitMarkersInView();
    });
  }

  void _initializeLocation() async {
    bool permissionGranted = await _location.requestService();
    if (!permissionGranted) return;

    LocationData locationData = await _location.getLocation();
    _updateLocation(locationData);

    _location.onLocationChanged.listen((LocationData newLocation) {
      _updateLocation(newLocation);
    });
  }

  void _updateLocation(LocationData locationData) {
    setState(() {

      _updateTargetLocation(_targetLocation);

      _currentPosition = LatLng(locationData.latitude!, locationData.longitude!);

      _userMarker = Marker(
        markerId: const MarkerId("user_marker"),
        position: _currentPosition,
        infoWindow: const InfoWindow(title: "You are here"),
      );

      // Calculate Distance
      double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition.latitude,
        _currentPosition.longitude,
        _targetLocation.latitude,
        _targetLocation.longitude,
      );

      if (distanceInMeters >= 1000) {
        _distanceText = "${(distanceInMeters / 1000).toStringAsFixed(2)} km";
      } else {
        _distanceText = "${distanceInMeters.toStringAsFixed(0)} meters";
      }

      // Fetch route and draw it
      _fetchRoute();

      // Adjust zoom to fit both markers
      _fitMarkersInView();
    });
  }


  void _fetchRoute() async {
    const String googleAPIKey = 'api_key';
    Dio dio = Dio();

    String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${_currentPosition.latitude},${_currentPosition.longitude}&destination=${_targetLocation.latitude},${_targetLocation.longitude}&key=$googleAPIKey";

    try {
      var response = await dio.get(url);
      if (response.statusCode == 200) {
        List<LatLng> routePoints = _decodePolyline(
            response.data['routes'][0]['overview_polyline']['points']);

        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: routePoints,
            color: Colors.blue,
            width: 5,
          ));
        });
      }
    } catch (e) {
      print("Error fetching route: $e");
    }
  }


  // void _fetchRoute() async {
  //   const String googleAPIKey = 'AIzaSyCZ6YIiEkZnGVCQUyFIKsu3RdOJ49GVeLU';
  //   Dio dio = Dio();
  //   String url =
  //       "https://maps.googleapis.com/maps/api/directions/json?origin=${_currentPosition.latitude},${_currentPosition.longitude}&destination=${_targetLocation.latitude},${_targetLocation.longitude}&key=$googleAPIKey";
  //   try {
  //     var response = await dio.get(url);
  //     if (response.statusCode == 200) {
  //       List<LatLng> routePoints = _decodePolyline(
  //           response.data['routes'][0]['overview_polyline']['points']);
  //
  //       setState(() {
  //         _polylines.clear();
  //         _polylines.add(Polyline(
  //           polylineId: const PolylineId('route'),
  //           points: routePoints,
  //           color: Colors.blue,
  //           width: 5,
  //         ));
  //       });
  //     }
  //   } catch (e) {
  //     print("Error fetching route: $e");
  //   }
  // }

  List<LatLng> _decodePolyline(String encoded) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(encoded);
    return decodedPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Route with Distance'),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            // Google Map
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 12,
              ),
              myLocationEnabled: true,
              markers: {_userMarker, _targetMarker},
              polylines: _polylines,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _fitMarkersInView();
                _mapController.animateCamera(CameraUpdate.newLatLngBounds(
                  LatLngBounds(
                    southwest: LatLng(
                      _currentPosition.latitude < _targetLocation.latitude
                          ? _currentPosition.latitude
                          : _targetLocation.latitude,
                      _currentPosition.longitude < _targetLocation.longitude
                          ? _currentPosition.longitude
                          : _targetLocation.longitude,
                    ),
                    northeast: LatLng(
                      _currentPosition.latitude > _targetLocation.latitude
                          ? _currentPosition.latitude
                          : _targetLocation.latitude,
                      _currentPosition.longitude > _targetLocation.longitude
                          ? _currentPosition.longitude
                          : _targetLocation.longitude,
                    ),
                  ),
                  100,
                ));
              },
            ),
            // Distance display
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
                ),
                child: Text(
                  "Distance to Target: $_distanceText",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
