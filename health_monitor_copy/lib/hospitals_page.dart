import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class Hospital {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  double? distance;

  Hospital({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.distance,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) => Hospital(
        name: json['name'],
        address: json['address'],
        latitude: json['latitude'],
        longitude: json['longitude'],
      );
}

class HospitalsPage extends StatefulWidget {
  const HospitalsPage({super.key});

  @override
  State<HospitalsPage> createState() => _HospitalsPageState();
}

class _HospitalsPageState extends State<HospitalsPage> {
  List<Hospital> allHospitals = [];
  List<Hospital> nearestHospitals = [];
  List<Hospital> bestHospitals = [];
  List<Hospital> visitedHospitals = [];
  Position? _currentPosition;
  String _currentAddress = '';
  bool _isLoading = true;
  String _errorMessage = '';

  // Example: Use SharedPreferences or local storage for real visited hospital tracking
  final List<String> _visitedHospitalNames = [
    // Add visited hospital names here for demo
    'Apollo Hospital',
    'Dr. B.C Roy Hospital',
  ];

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    try {
      final String response =
          await rootBundle.loadString('assets/hospitals.json');
      final List<dynamic> data = json.decode(response);
      allHospitals = data.map((e) => Hospital.fromJson(e)).toList();
      // Mark best hospitals (static, e.g., Apollo, NRS)
      bestHospitals = allHospitals
          .where((h) =>
              h.name.contains('Apollo') || h.name.contains('Nil Ratan Sircar'))
          .toList();
      // Mark visited hospitals
      visitedHospitals = allHospitals
          .where((h) => _visitedHospitalNames.contains(h.name))
          .toList();
      await _getCurrentLocation();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading hospitals: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled.';
          _isLoading = false;
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are denied.';
            _isLoading = false;
          });
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
      await _getAddressFromLatLng();
      _calculateDistances();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _getAddressFromLatLng() async {
    if (_currentPosition == null) return;
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      Placemark place = placemarks.first;
      setState(() {
        _currentAddress =
            "${place.street}, ${place.subLocality}, ${place.locality}";
      });
    } catch (e) {
      setState(() {
        _currentAddress = 'Unable to get address';
      });
    }
  }

  void _calculateDistances() {
    if (_currentPosition == null) return;
    for (var hospital in allHospitals) {
      hospital.distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            hospital.latitude,
            hospital.longitude,
          ) /
          1000; // in km
    }
    allHospitals.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
    nearestHospitals = allHospitals.take(5).toList();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Hospitals'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentAddress.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.my_location, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentAddress,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (visitedHospitals.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Previously Visited Hospitals',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ...visitedHospitals.map((h) => _buildHospitalCard(h)),
                      if (bestHospitals.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Top Hospitals',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ...bestHospitals.map((h) => _buildHospitalCard(h)),
                      if (nearestHospitals.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Nearest Hospitals',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ...nearestHospitals.map((h) => _buildHospitalCard(h)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHospitalCard(Hospital hospital) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    hospital.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hospital.distance != null)
                  Row(
                    children: [
                      const Icon(Icons.directions_walk,
                          color: Colors.green, size: 20),
                      Text(
                        '${hospital.distance!.toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hospital.address,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _launchUrl('tel:'),
                  icon: const Icon(Icons.call),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _launchUrl(
                      'https://maps.google.com/?q=${hospital.latitude},${hospital.longitude}'),
                  icon: const Icon(Icons.map),
                  label: const Text('Directions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
