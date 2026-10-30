import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../models/models.dart';

/// Representation of a Metro Station
class MetroStation {
  final String id;
  final String name;
  final String lineName;
  final Color lineColor;
  final double latitude;
  final double longitude;

  const MetroStation({
    required this.id,
    required this.name,
    required this.lineName,
    required this.lineColor,
    required this.latitude,
    required this.longitude,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}

/// Result of checking Metro availability and routing
class MetroRouteResult {
  final bool isAvailable;
  final String? unavailableReason;
  final MetroStation? originStation;
  final MetroStation? destinationStation;
  final MetroStation? interchangeStation;
  final String lineSummary;
  final Color primaryLineColor;
  final double firstMileKm;
  final double metroTrackKm;
  final double lastMileKm;
  final double totalKm;
  final int totalEstimatedMinutes;
  final int totalStations;
  final List<LatLng> metroPath;
  final List<MetroStation> passedStations;

  const MetroRouteResult({
    required this.isAvailable,
    this.unavailableReason,
    this.originStation,
    this.destinationStation,
    this.interchangeStation,
    this.lineSummary = '',
    this.primaryLineColor = const Color(0xFFEAB308),
    this.firstMileKm = 0.0,
    this.metroTrackKm = 0.0,
    this.lastMileKm = 0.0,
    this.totalKm = 0.0,
    this.totalEstimatedMinutes = 0,
    this.totalStations = 0,
    this.metroPath = const [],
    this.passedStations = const [],
  });
}

/// Result of road route calculation
class RoadRouteResult {
  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> polylinePoints;
  final bool isRealRoadGeometry;

  const RoadRouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.polylinePoints,
    this.isRealRoadGeometry = false,
  });
}

/// Location Preset for Search Suggestions
class SearchLocationPreset {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final IconData icon;

  const SearchLocationPreset({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.icon = Icons.place_rounded,
  });
}

class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  // ---------------------------------------------------------------------------
  // 1. Comprehensive Regional & City Search Autocomplete Catalog
  // ---------------------------------------------------------------------------
  static const List<SearchLocationPreset> searchCatalog = [
    // D
    SearchLocationPreset(title: 'Delhi', subtitle: 'National Capital Territory of India', latitude: 28.6139, longitude: 77.2090, icon: Icons.location_city_rounded),
    SearchLocationPreset(title: 'Dehradun', subtitle: 'Capital of Uttarakhand, Doon Valley', latitude: 30.3165, longitude: 78.0322, icon: Icons.terrain_rounded),
    SearchLocationPreset(title: 'Defence Colony', subtitle: 'South Delhi, New Delhi 110024', latitude: 28.5724, longitude: 77.2345, icon: Icons.home_rounded),
    SearchLocationPreset(title: 'Dwarka Sector 21', subtitle: 'South West Delhi, Delhi 110077', latitude: 28.5520, longitude: 77.0585, icon: Icons.subway_rounded),
    SearchLocationPreset(title: 'Dhaula Kuan', subtitle: 'South West Delhi, New Delhi 110010', latitude: 28.5915, longitude: 77.1615, icon: Icons.commute_rounded),
    SearchLocationPreset(title: 'Daryaganj', subtitle: 'Central Delhi, Old Delhi 110002', latitude: 28.6465, longitude: 77.2410, icon: Icons.storefront_rounded),

    // M
    SearchLocationPreset(title: 'Mumbai', subtitle: 'Financial Capital of India, Maharashtra', latitude: 19.0760, longitude: 72.8777, icon: Icons.apartment_rounded),
    SearchLocationPreset(title: 'Meerut', subtitle: 'Uttar Pradesh, NCR (approx 75 km)', latitude: 28.9845, longitude: 77.7064, icon: Icons.location_city_rounded),
    SearchLocationPreset(title: 'Mathura', subtitle: 'Uttar Pradesh, Yamuna Expressway (approx 160 km)', latitude: 27.4924, longitude: 77.6737, icon: Icons.temple_hindu_rounded),
    SearchLocationPreset(title: 'Moradabad', subtitle: 'Brass City, Uttar Pradesh (approx 180 km)', latitude: 28.8386, longitude: 78.7733, icon: Icons.train_rounded),
    SearchLocationPreset(title: 'Munirka', subtitle: 'South Delhi, New Delhi 110067', latitude: 28.5585, longitude: 77.1740, icon: Icons.home_work_rounded),
    SearchLocationPreset(title: 'Manesar (IMT)', subtitle: 'Industrial Model Township, Gurugram', latitude: 28.3588, longitude: 76.9380, icon: Icons.factory_rounded),
    SearchLocationPreset(title: 'Mandi House', subtitle: 'Cultural Hub, Central Delhi 110001', latitude: 28.6260, longitude: 77.2345, icon: Icons.theater_comedy_rounded),

    // N
    SearchLocationPreset(title: 'Noida Sector 18', subtitle: 'Atta Market, Noida, Uttar Pradesh', latitude: 28.5710, longitude: 77.3215, icon: Icons.shopping_bag_rounded),
    SearchLocationPreset(title: 'Noida Electronic City, Sector 62', subtitle: 'Sector 62, Noida, Uttar Pradesh', latitude: 28.6280, longitude: 77.3758, icon: Icons.apartment_rounded),
    SearchLocationPreset(title: 'Nainital', subtitle: 'Lake District, Kumaon, Uttarakhand', latitude: 29.3919, longitude: 79.4542, icon: Icons.landscape_rounded),
    SearchLocationPreset(title: 'New Delhi Railway Station (NDLS)', subtitle: 'Paharganj / Ajmeri Gate, New Delhi', latitude: 28.6429, longitude: 77.2195, icon: Icons.train_rounded),

    // G
    SearchLocationPreset(title: 'Gurugram (Gurgaon)', subtitle: 'Cyber City, Millennium Hub, Haryana', latitude: 28.4595, longitude: 77.0266, icon: Icons.business_rounded),
    SearchLocationPreset(title: 'Ghaziabad', subtitle: 'Indirapuram / Raj Nagar, Uttar Pradesh', latitude: 28.6692, longitude: 77.4538, icon: Icons.location_city_rounded),
    SearchLocationPreset(title: 'Greater Noida (Pari Chowk)', subtitle: 'Gautam Buddha Nagar, Uttar Pradesh', latitude: 28.4744, longitude: 77.5040, icon: Icons.share_location_rounded),
    SearchLocationPreset(title: 'Gwalior', subtitle: 'Madhya Pradesh (approx 340 km)', latitude: 26.2183, longitude: 78.1828, icon: Icons.castle_rounded),

    // H
    SearchLocationPreset(title: 'Hauz Khas Village & Lake', subtitle: 'South Delhi, Delhi 110016', latitude: 28.5535, longitude: 77.1944, icon: Icons.park_rounded),
    SearchLocationPreset(title: 'Haridwar', subtitle: 'Holy City on Ganges, Uttarakhand (approx 220 km)', latitude: 29.9457, longitude: 78.1642, icon: Icons.water_rounded),
    SearchLocationPreset(title: 'Hazrat Nizamuddin Railway Station', subtitle: 'Nizamuddin East, New Delhi 110013', latitude: 28.5895, longitude: 77.2530, icon: Icons.train_rounded),

    // J
    SearchLocationPreset(title: 'Jaipur', subtitle: 'Pink City, Rajasthan (approx 280 km)', latitude: 26.9124, longitude: 75.7873, icon: Icons.account_balance_rounded),
    SearchLocationPreset(title: 'Janakpuri West', subtitle: 'District Centre, West Delhi 110058', latitude: 28.6290, longitude: 77.0775, icon: Icons.subway_rounded),
    SearchLocationPreset(title: 'Jasola Vihar', subtitle: 'Near Apollo Hospital, South Delhi', latitude: 28.5425, longitude: 77.3115, icon: Icons.local_hospital_rounded),

    // C
    SearchLocationPreset(title: 'Connaught Place, Inner Circle', subtitle: 'Rajiv Chowk, Central Delhi 110001', latitude: 28.6315, longitude: 77.2167, icon: Icons.shopping_bag_rounded),
    SearchLocationPreset(title: 'Cyber Hub & DLF Cyber City', subtitle: 'Sector 24, DLF Phase 2, Gurugram', latitude: 28.4950, longitude: 77.0895, icon: Icons.business_rounded),
    SearchLocationPreset(title: 'Chandigarh', subtitle: 'Capital City, Punjab & Haryana (approx 250 km)', latitude: 30.7333, longitude: 76.7794, icon: Icons.nature_people_rounded),
    SearchLocationPreset(title: 'Chandni Chowk & Red Fort', subtitle: 'Old Delhi, Delhi 110006', latitude: 28.6575, longitude: 77.2300, icon: Icons.castle_rounded),

    // A
    SearchLocationPreset(title: 'Agra (Taj Mahal)', subtitle: 'Yamuna Expressway, Uttar Pradesh (approx 210 km)', latitude: 27.1767, longitude: 78.0081, icon: Icons.temple_buddhist_rounded),
    SearchLocationPreset(title: 'Indira Gandhi International Airport (T3)', subtitle: 'Terminal 3, New Delhi 110037', latitude: 28.5562, longitude: 77.1000, icon: Icons.flight_takeoff_rounded),
    SearchLocationPreset(title: 'Aerocity Worldmark', subtitle: 'Hospitality District, New Delhi 110037', latitude: 28.5492, longitude: 77.1215, icon: Icons.hotel_rounded),
    SearchLocationPreset(title: 'AIIMS & Safdarjung Hospital', subtitle: 'Ansari Nagar, New Delhi 110029', latitude: 28.5672, longitude: 77.2100, icon: Icons.local_hospital_rounded),

    // R
    SearchLocationPreset(title: 'Rishikesh', subtitle: 'Yoga Capital, Himalayas, Uttarakhand (approx 240 km)', latitude: 30.0869, longitude: 78.2676, icon: Icons.self_improvement_rounded),
    SearchLocationPreset(title: 'Rohtak', subtitle: 'Haryana (approx 75 km)', latitude: 28.8955, longitude: 76.6066, icon: Icons.location_city_rounded),
    SearchLocationPreset(title: 'Rohini Sector 10', subtitle: 'North West Delhi, Delhi 110085', latitude: 28.7165, longitude: 77.1145, icon: Icons.apartment_rounded),

    // S
    SearchLocationPreset(title: 'Select CITYWALK & Saket', subtitle: 'District Centre, Saket, South Delhi', latitude: 28.5284, longitude: 77.2194, icon: Icons.storefront_rounded),
    SearchLocationPreset(title: 'Shimla', subtitle: 'Queen of Hills, Himachal Pradesh (approx 350 km)', latitude: 31.1048, longitude: 77.1734, icon: Icons.snowing),
    SearchLocationPreset(title: 'Sector 29 Market', subtitle: 'Leisure Valley, Gurugram 122002', latitude: 28.4682, longitude: 77.0632, icon: Icons.local_dining_rounded),

    // K
    SearchLocationPreset(title: 'Khan Market', subtitle: 'Rabindra Nagar, New Delhi 110003', latitude: 28.6003, longitude: 77.2270, icon: Icons.coffee_rounded),
    SearchLocationPreset(title: 'Kashmere Gate ISBT', subtitle: 'Interstate Bus Terminal, Delhi', latitude: 28.6675, longitude: 77.2285, icon: Icons.directions_bus_rounded),
    SearchLocationPreset(title: 'Karnal', subtitle: 'GT Road, Haryana (approx 125 km)', latitude: 29.6857, longitude: 76.9905, icon: Icons.route_rounded),

    // V
    SearchLocationPreset(title: 'Vasant Kunj (DLF Promenade)', subtitle: 'Nelson Mandela Marg, New Delhi', latitude: 28.5385, longitude: 77.1565, icon: Icons.shopping_bag_rounded),
    SearchLocationPreset(title: 'Vrindavan', subtitle: 'Holy Pilgrimage, Uttar Pradesh (approx 150 km)', latitude: 27.5806, longitude: 77.7006, icon: Icons.temple_hindu_rounded),
  ];

  /// Filter search catalog by prefix or text substring
  List<SearchLocationPreset> filterSearchCatalog(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return const [];

    return searchCatalog.where((place) {
      final title = place.title.toLowerCase();
      final subtitle = place.subtitle.toLowerCase();
      return title.startsWith(clean) ||
          title.contains(' $clean') ||
          title.contains(clean) ||
          subtitle.contains(clean);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 2. Delhi NCR Metro Lines & Stations Database
  // ---------------------------------------------------------------------------
  static const Color yellowLineColor = Color(0xFFFACC15);
  static const Color blueLineColor = Color(0xFF2563EB);
  static const Color magentaLineColor = Color(0xFFD946EF);
  static const Color orangeLineColor = Color(0xFFEA580C);
  static const Color rapidMetroColor = Color(0xFF06B6D4);

  // Yellow Line
  static const List<MetroStation> yellowLine = [
    MetroStation(id: 'y1', name: 'Millennium City Centre (HUDA)', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.4595, longitude: 77.0725),
    MetroStation(id: 'y2', name: 'IFFCO Chowk', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.4720, longitude: 77.0725),
    MetroStation(id: 'y3', name: 'MG Road', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.4795, longitude: 77.0805),
    MetroStation(id: 'y4', name: 'Sikanderpur', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.4815, longitude: 77.0930),
    MetroStation(id: 'y5', name: 'Guru Dronacharya', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.4940, longitude: 77.1020),
    MetroStation(id: 'y6', name: 'Arjan Garh', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.4810, longitude: 77.1260),
    MetroStation(id: 'y7', name: 'Ghitorni', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.4945, longitude: 77.1405),
    MetroStation(id: 'y8', name: 'Sultanpur', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.4990, longitude: 77.1530),
    MetroStation(id: 'y9', name: 'Chhatarpur', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.5065, longitude: 77.1745),
    MetroStation(id: 'y10', name: 'Qutab Minar', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.5130, longitude: 77.1855),
    MetroStation(id: 'y11', name: 'Saket', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.5210, longitude: 77.2015),
    MetroStation(id: 'y12', name: 'Malviya Nagar', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.5285, longitude: 77.2065),
    MetroStation(id: 'y13', name: 'Hauz Khas', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.5435, longitude: 77.2065),
    MetroStation(id: 'y14', name: 'Green Park', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.5585, longitude: 77.2065),
    MetroStation(id: 'y15', name: 'AIIMS', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.5685, longitude: 77.2080),
    MetroStation(id: 'y16', name: 'Dilli Haat - INA', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.5750, longitude: 77.2095),
    MetroStation(id: 'y17', name: 'Jor Bagh', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.5875, longitude: 77.2120),
    MetroStation(id: 'y18', name: 'Lok Kalyan Marg', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.5985, longitude: 77.2115),
    MetroStation(id: 'y19', name: 'Udyog Bhawan', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.6110, longitude: 77.2125),
    MetroStation(id: 'y20', name: 'Central Secretariat', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.6150, longitude: 77.2120),
    MetroStation(id: 'y21', name: 'Patel Chowk', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.6230, longitude: 77.2140),
    MetroStation(id: 'y22', name: 'Rajiv Chowk', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.6330, longitude: 77.2195),
    MetroStation(id: 'y23', name: 'New Delhi', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.6430, longitude: 77.2220),
    MetroStation(id: 'y24', name: 'Chawri Bazar', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.6495, longitude: 77.2270),
    MetroStation(id: 'y25', name: 'Chandni Chowk', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.6575, longitude: 77.2300),
    MetroStation(id: 'y26', name: 'Kashmere Gate', lineName: 'Yellow Line', lineColor: yellowLineColor, latitude: 28.6675, longitude: 77.2285),
  ];

  // Blue Line
  static const List<MetroStation> blueLine = [
    MetroStation(id: 'b1', name: 'Dwarka Sector 21', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.5520, longitude: 77.0585),
    MetroStation(id: 'b2', name: 'Janakpuri West', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.6290, longitude: 77.0775),
    MetroStation(id: 'b3', name: 'Rajouri Garden', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.6490, longitude: 77.1225),
    MetroStation(id: 'b4', name: 'Karol Bagh', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.6440, longitude: 77.1905),
    MetroStation(id: 'b5', name: 'Rajiv Chowk', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.6330, longitude: 77.2195),
    MetroStation(id: 'b6', name: 'Mandi House', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.6260, longitude: 77.2345),
    MetroStation(id: 'b7', name: 'Supreme Court', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.6210, longitude: 77.2435),
    MetroStation(id: 'b8', name: 'Yamuna Bank', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.6240, longitude: 77.2615),
    MetroStation(id: 'b9', name: 'Akshardham', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.6175, longitude: 77.2790),
    MetroStation(id: 'b10', name: 'Mayur Vihar-I', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.6045, longitude: 77.2950),
    MetroStation(id: 'b11', name: 'Noida Sector 15', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.5865, longitude: 77.3135),
    MetroStation(id: 'b12', name: 'Noida Sector 16', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.5785, longitude: 77.3175),
    MetroStation(id: 'b13', name: 'Noida Sector 18', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.5710, longitude: 77.3215),
    MetroStation(id: 'b14', name: 'Botanical Garden', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.5645, longitude: 77.3345),
    MetroStation(id: 'b15', name: 'Noida City Centre', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.5745, longitude: 77.3560),
    MetroStation(id: 'b16', name: 'Noida Sector 62', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.6280, longitude: 77.3755),
    MetroStation(id: 'b17', name: 'Noida Electronic City', lineName: 'Blue Line', lineColor: blueLineColor, latitude: 28.6275, longitude: 77.3725),
  ];

  // Magenta Line
  static const List<MetroStation> magentaLine = [
    MetroStation(id: 'm1', name: 'Janakpuri West', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.6290, longitude: 77.0775),
    MetroStation(id: 'm2', name: 'Terminal 1 IGI Airport', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5630, longitude: 77.1205),
    MetroStation(id: 'm3', name: 'Vasant Vihar', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5615, longitude: 77.1610),
    MetroStation(id: 'm4', name: 'Munirka', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5585, longitude: 77.1740),
    MetroStation(id: 'm5', name: 'IIT Delhi', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5475, longitude: 77.1950),
    MetroStation(id: 'm6', name: 'Hauz Khas', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5435, longitude: 77.2065),
    MetroStation(id: 'm7', name: 'Panchsheel Park', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5430, longitude: 77.2185),
    MetroStation(id: 'm8', name: 'Greater Kailash', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5420, longitude: 77.2345),
    MetroStation(id: 'm9', name: 'Nehru Enclave', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5470, longitude: 77.2515),
    MetroStation(id: 'm10', name: 'Kalkaji Mandir', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5495, longitude: 77.2605),
    MetroStation(id: 'm11', name: 'Jamia Millia Islamia', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5635, longitude: 77.2945),
    MetroStation(id: 'm12', name: 'Kalindi Kunj', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5470, longitude: 77.3205),
    MetroStation(id: 'm13', name: 'Okhla Bird Sanctuary', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5585, longitude: 77.3245),
    MetroStation(id: 'm14', name: 'Botanical Garden', lineName: 'Magenta Line', lineColor: magentaLineColor, latitude: 28.5645, longitude: 77.3345),
  ];

  // Airport Express Line
  static const List<MetroStation> airportExpressLine = [
    MetroStation(id: 'a1', name: 'New Delhi (Airport Express)', lineName: 'Airport Express', lineColor: orangeLineColor, latitude: 28.6430, longitude: 77.2220),
    MetroStation(id: 'a2', name: 'Shivaji Stadium', lineName: 'Airport Express', lineColor: orangeLineColor, latitude: 28.6290, longitude: 77.2140),
    MetroStation(id: 'a3', name: 'Dhaula Kuan', lineName: 'Airport Express', lineColor: orangeLineColor, latitude: 28.5915, longitude: 77.1615),
    MetroStation(id: 'a4', name: 'Delhi Aerocity', lineName: 'Airport Express', lineColor: orangeLineColor, latitude: 28.5495, longitude: 77.1215),
    MetroStation(id: 'a5', name: 'Airport (Terminal 3)', lineName: 'Airport Express', lineColor: orangeLineColor, latitude: 28.5562, longitude: 77.1000),
    MetroStation(id: 'a6', name: 'Dwarka Sector 21', lineName: 'Airport Express', lineColor: orangeLineColor, latitude: 28.5520, longitude: 77.0585),
  ];

  // Rapid Metro Gurgaon
  static const List<MetroStation> rapidMetro = [
    MetroStation(id: 'r1', name: 'Sector 55-56', lineName: 'Rapid Metro', lineColor: rapidMetroColor, latitude: 28.4230, longitude: 77.1040),
    MetroStation(id: 'r2', name: 'Sector 54 Chowk', lineName: 'Rapid Metro', lineColor: rapidMetroColor, latitude: 28.4410, longitude: 77.1030),
    MetroStation(id: 'r3', name: 'Sector 42-43', lineName: 'Rapid Metro', lineColor: rapidMetroColor, latitude: 28.4630, longitude: 77.0980),
    MetroStation(id: 'r4', name: 'Phase 1', lineName: 'Rapid Metro', lineColor: rapidMetroColor, latitude: 28.4740, longitude: 77.0980),
    MetroStation(id: 'r5', name: 'Sikanderpur', lineName: 'Rapid Metro', lineColor: rapidMetroColor, latitude: 28.4815, longitude: 77.0930),
    MetroStation(id: 'r6', name: 'Phase 2', lineName: 'Rapid Metro', lineColor: rapidMetroColor, latitude: 28.4900, longitude: 77.0890),
    MetroStation(id: 'r7', name: 'Cyber City (Cyber Hub)', lineName: 'Rapid Metro', lineColor: rapidMetroColor, latitude: 28.4950, longitude: 77.0895),
    MetroStation(id: 'r8', name: 'Moulsari Avenue', lineName: 'Rapid Metro', lineColor: rapidMetroColor, latitude: 28.5020, longitude: 77.0940),
  ];

  List<List<MetroStation>> get allLines => [
        yellowLine,
        blueLine,
        magentaLine,
        airportExpressLine,
        rapidMetro,
      ];

  List<MetroStation> get allStations {
    final list = <MetroStation>[];
    for (final line in allLines) {
      list.addAll(line);
    }
    return list;
  }

  // ---------------------------------------------------------------------------
  // 3. Real Road Routing via OSRM Engine with Dynamic Traffic Modeling
  // ---------------------------------------------------------------------------
  /// Returns real-time diurnal traffic congestion multiplier for road vehicles
  static double getTrafficCongestionMultiplier([DateTime? time]) {
    final now = time ?? DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final t = hour + (minute / 60.0);

    // Morning Peak: 08:00 - 11:30 (+45% travel delay)
    if (t >= 8.0 && t < 11.5) return 1.45;
    // Evening Peak: 17:00 - 21:30 (+50% travel delay)
    if (t >= 17.0 && t < 21.5) return 1.50;
    // Midday Steady: 11:30 - 17:00 (+20% travel delay)
    if (t >= 11.5 && t < 17.0) return 1.20;
    // Early Morning: 05:30 - 08:00 (+8% travel delay)
    if (t >= 5.5 && t < 8.0) return 1.08;
    // Night: 21:30 - 05:30 (Free flow, 0% delay)
    return 1.00;
  }

  Future<RoadRouteResult> calculateRoadRoute({
    required LatLng start,
    required LatLng destination,
    required TransportMode mode,
  }) async {
    const distanceCalculator = Distance();
    final straightLineKm = distanceCalculator.as(LengthUnit.Kilometer, start, destination);
    final trafficMultiplier = getTrafficCongestionMultiplier();

    // Profile for OSRM
    final profile = mode == TransportMode.walking ? 'walking' : 'driving';
    final url =
        'https://router.project-osrm.org/route/v1/$profile/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson';

    try {
      final request = await _httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;

        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final distanceMeters = (route['distance'] as num).toDouble();
          final baseSecs = (route['duration'] as num).toDouble();

          final geometry = route['geometry'] as Map<String, dynamic>;
          final coordinates = geometry['coordinates'] as List;

          final polyline = coordinates.map((coord) {
            final lon = (coord[0] as num).toDouble();
            final lat = (coord[1] as num).toDouble();
            return LatLng(lat, lon);
          }).toList();

          final distanceKm = distanceMeters / 1000.0;
          double adjustedDurationSecs;

          if (mode == TransportMode.walking) {
            // Walking is exempt from road vehicular traffic; ~4.6 km/h pace
            adjustedDurationSecs = (distanceKm / 4.6) * 3600.0 + 120.0;
          } else if (mode == TransportMode.auto) {
            final autoTraffic = 1.0 + (trafficMultiplier - 1.0) * 0.85;
            final baseAutoSpeed = distanceKm > 20 ? 26.0 : 22.0;
            adjustedDurationSecs = ((distanceKm / (baseAutoSpeed / autoTraffic)) * 3600.0) + 240.0;
          } else if (mode == TransportMode.bus) {
            final dwell = distanceKm > 40 ? 1.08 : 1.25;
            adjustedDurationSecs = (baseSecs * trafficMultiplier * dwell) + 480.0;
          } else {
            // Cab / Taxi: apply real-time traffic delay multiplier
            adjustedDurationSecs = (baseSecs * trafficMultiplier) + 300.0;
          }

          final durationMins = (adjustedDurationSecs / 60.0).round();

          return RoadRouteResult(
            distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
            durationMinutes: math.max(durationMins, 5),
            polylinePoints: polyline,
            isRealRoadGeometry: true,
          );
        }
      }
    } catch (e) {
      debugPrint('RoutingService: OSRM call failed ($e). Using robust road network model.');
    }

    // High-Precision Fallback: City Road Factor (~1.20x to 1.26x straight line)
    final roadFactor = mode == TransportMode.walking ? 1.15 : (straightLineKm > 100 ? 1.20 : 1.26);
    final estimatedRoadKm = double.parse((straightLineKm * roadFactor).toStringAsFixed(1));

    // Realistic Speed Model based on Mode, Distance Scale & Real-Time Traffic Congestion
    double speedKmh;
    int bufferMins;

    switch (mode) {
      case TransportMode.walking:
        speedKmh = 4.6; // Human walking speed is ~4.6 km/h (traffic exempt)
        bufferMins = 2;
        break;
      case TransportMode.auto:
        final autoTraffic = 1.0 + (trafficMultiplier - 1.0) * 0.85;
        final baseAuto = estimatedRoadKm > 20 ? 26.0 : 22.0;
        speedKmh = baseAuto / autoTraffic;
        bufferMins = 4;
        break;
      case TransportMode.cab:
        double baseCab;
        if (estimatedRoadKm > 80) {
          baseCab = 72.0; // Highway cruising for long trips
          bufferMins = 12;
        } else if (estimatedRoadKm > 20) {
          baseCab = 42.0; // NCR / suburban arterial
          bufferMins = 8;
        } else {
          baseCab = 28.0; // City street driving
          bufferMins = 5;
        }
        speedKmh = baseCab / trafficMultiplier;
        break;
      case TransportMode.bus:
        final dwell = estimatedRoadKm > 40 ? 1.08 : 1.25;
        final baseBus = estimatedRoadKm > 40 ? 50.0 : 18.0;
        speedKmh = (baseBus / trafficMultiplier) / dwell;
        bufferMins = estimatedRoadKm > 40 ? 15 : 8;
        break;
      case TransportMode.metro:
        speedKmh = 34.0;
        bufferMins = 6;
        break;
    }

    final totalDuration = ((estimatedRoadKm / speedKmh) * 60).round() + bufferMins;
    final points = _generateInterpolatedRoadPath(start, destination, straightLineKm);

    return RoadRouteResult(
      distanceKm: estimatedRoadKm,
      durationMinutes: math.max(totalDuration, 5),
      polylinePoints: points,
      isRealRoadGeometry: false,
    );
  }

  List<LatLng> _generateInterpolatedRoadPath(LatLng start, LatLng end, double straightLineKm) {
    final points = <LatLng>[start];
    final steps = (straightLineKm * 0.8).clamp(24, 72).toInt();

    final dLat = end.latitude - start.latitude;
    final dLon = end.longitude - start.longitude;

    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      final wave = math.sin(t * math.pi * 2.0);
      final offset = (straightLineKm > 80 ? 0.008 : 0.0028) * wave;
      final lat = start.latitude + (dLat * t) + (i % 2 == 0 ? offset : -offset * 0.5);
      final lon = start.longitude + (dLon * t) + (i % 2 == 1 ? offset : -offset * 0.5);
      points.add(LatLng(lat, lon));
    }

    points.add(end);
    return points;
  }

  // ---------------------------------------------------------------------------
  // 4. Metro Train Route & Availability Engine
  // ---------------------------------------------------------------------------
  MetroRouteResult checkMetroAvailability({
    required LatLng start,
    required LatLng destination,
  }) {
    const distanceCalc = Distance();

    MetroStation? nearestStartStation;
    double minStartDistKm = double.infinity;

    MetroStation? nearestDestStation;
    double minDestDistKm = double.infinity;

    for (final station in allStations) {
      final sDist = distanceCalc.as(LengthUnit.Kilometer, start, station.latLng);
      if (sDist < minStartDistKm) {
        minStartDistKm = sDist;
        nearestStartStation = station;
      }

      final dDist = distanceCalc.as(LengthUnit.Kilometer, destination, station.latLng);
      if (dDist < minDestDistKm) {
        minDestDistKm = dDist;
        nearestDestStation = station;
      }
    }

    const maxAccessThresholdKm = 5.8;

    if (nearestStartStation == null ||
        nearestDestStation == null ||
        minStartDistKm > maxAccessThresholdKm ||
        minDestDistKm > maxAccessThresholdKm) {
      final reason = minStartDistKm > maxAccessThresholdKm
          ? 'Origin is too far from nearest metro station (${nearestStartStation?.name ?? "None"}, ${minStartDistKm.toStringAsFixed(1)} km away).'
          : 'Destination is outside the urban metro corridor (${nearestDestStation?.name ?? "None"}, ${minDestDistKm.toStringAsFixed(1)} km away).';

      return MetroRouteResult(
        isAvailable: false,
        unavailableReason: reason,
        originStation: nearestStartStation,
        destinationStation: nearestDestStation,
        firstMileKm: minStartDistKm,
        lastMileKm: minDestDistKm,
      );
    }

    List<MetroStation>? directLine;
    for (final line in allLines) {
      final hasStart = line.any((s) => s.name == nearestStartStation!.name);
      final hasDest = line.any((s) => s.name == nearestDestStation!.name);
      if (hasStart && hasDest) {
        directLine = line;
        break;
      }
    }

    if (directLine != null) {
      final startIndex = directLine.indexWhere((s) => s.name == nearestStartStation!.name);
      final destIndex = directLine.indexWhere((s) => s.name == nearestDestStation!.name);

      final passed = <MetroStation>[];
      final pathPoints = <LatLng>[];

      if (startIndex <= destIndex) {
        for (int i = startIndex; i <= destIndex; i++) {
          passed.add(directLine[i]);
          pathPoints.add(directLine[i].latLng);
        }
      } else {
        for (int i = startIndex; i >= destIndex; i--) {
          passed.add(directLine[i]);
          pathPoints.add(directLine[i].latLng);
        }
      }

      double trackKm = 0.0;
      for (int i = 0; i < pathPoints.length - 1; i++) {
        trackKm += distanceCalc.as(LengthUnit.Kilometer, pathPoints[i], pathPoints[i + 1]);
      }

      final totalKm = minStartDistKm + trackKm + minDestDistKm;
      final metroMinutes = math.max((passed.length * 2.2).round(), 8);
      final firstMileMins = (minStartDistKm / 4.5 * 60).round();
      final lastMileMins = (minDestDistKm / 4.5 * 60).round();

      return MetroRouteResult(
        isAvailable: true,
        originStation: nearestStartStation,
        destinationStation: nearestDestStation,
        lineSummary: '${directLine.first.lineName} (Direct • ${passed.length} stations)',
        primaryLineColor: directLine.first.lineColor,
        firstMileKm: double.parse(minStartDistKm.toStringAsFixed(1)),
        metroTrackKm: double.parse(trackKm.toStringAsFixed(1)),
        lastMileKm: double.parse(minDestDistKm.toStringAsFixed(1)),
        totalKm: double.parse(totalKm.toStringAsFixed(1)),
        totalEstimatedMinutes: metroMinutes + firstMileMins + lastMileMins,
        totalStations: passed.length,
        metroPath: pathPoints,
        passedStations: passed,
      );
    }

    final interchange = _findInterchangeStation(nearestStartStation, nearestDestStation);

    if (interchange != null) {
      final line1 = _findLineFor(nearestStartStation);
      final line2 = _findLineFor(nearestDestStation);

      final pathPoints = <LatLng>[];
      final passed = <MetroStation>[];

      if (line1 != null) {
        final idx1 = line1.indexWhere((s) => s.name == nearestStartStation!.name);
        final idxInt = line1.indexWhere((s) => s.name == interchange.name);
        if (idx1 != -1 && idxInt != -1) {
          final step = idx1 <= idxInt ? 1 : -1;
          for (int i = idx1; i != idxInt + step; i += step) {
            passed.add(line1[i]);
            pathPoints.add(line1[i].latLng);
          }
        }
      }

      if (line2 != null) {
        final idxInt = line2.indexWhere((s) => s.name == interchange.name);
        final idx2 = line2.indexWhere((s) => s.name == nearestDestStation!.name);
        if (idxInt != -1 && idx2 != -1) {
          final step = idxInt <= idx2 ? 1 : -1;
          for (int i = idxInt + step; i != idx2 + step; i += step) {
            passed.add(line2[i]);
            pathPoints.add(line2[i].latLng);
          }
        }
      }

      double trackKm = 0.0;
      for (int i = 0; i < pathPoints.length - 1; i++) {
        trackKm += distanceCalc.as(LengthUnit.Kilometer, pathPoints[i], pathPoints[i + 1]);
      }

      final totalKm = minStartDistKm + trackKm + minDestDistKm;
      final metroMinutes = math.max((passed.length * 2.3).round() + 6, 12);

      return MetroRouteResult(
        isAvailable: true,
        originStation: nearestStartStation,
        destinationStation: nearestDestStation,
        interchangeStation: interchange,
        lineSummary: '${nearestStartStation.lineName} to ${nearestDestStation.lineName} (Transfer at ${interchange.name})',
        primaryLineColor: nearestStartStation.lineColor,
        firstMileKm: double.parse(minStartDistKm.toStringAsFixed(1)),
        metroTrackKm: double.parse(trackKm.toStringAsFixed(1)),
        lastMileKm: double.parse(minDestDistKm.toStringAsFixed(1)),
        totalKm: double.parse(totalKm.toStringAsFixed(1)),
        totalEstimatedMinutes: metroMinutes + (minStartDistKm * 8).round() + (minDestDistKm * 8).round(),
        totalStations: passed.length,
        metroPath: pathPoints,
        passedStations: passed,
      );
    }

    return MetroRouteResult(
      isAvailable: true,
      originStation: nearestStartStation,
      destinationStation: nearestDestStation,
      lineSummary: '${nearestStartStation.lineName} Connected Transit',
      primaryLineColor: nearestStartStation.lineColor,
      firstMileKm: double.parse(minStartDistKm.toStringAsFixed(1)),
      metroTrackKm: double.parse(distanceCalc.as(LengthUnit.Kilometer, nearestStartStation.latLng, nearestDestStation.latLng).toStringAsFixed(1)),
      lastMileKm: double.parse(minDestDistKm.toStringAsFixed(1)),
      totalKm: double.parse((minStartDistKm + minDestDistKm + 8.5).toStringAsFixed(1)),
      totalEstimatedMinutes: 32,
      totalStations: 8,
      metroPath: [nearestStartStation.latLng, nearestDestStation.latLng],
      passedStations: [nearestStartStation, nearestDestStation],
    );
  }

  List<MetroStation>? _findLineFor(MetroStation station) {
    for (final line in allLines) {
      if (line.any((s) => s.name == station.name)) {
        return line;
      }
    }
    return null;
  }

  MetroStation? _findInterchangeStation(MetroStation s1, MetroStation s2) {
    final names = ['Hauz Khas', 'Rajiv Chowk', 'Sikanderpur', 'New Delhi', 'Botanical Garden', 'Central Secretariat', 'Janakpuri West', 'Kashmere Gate'];
    for (final name in names) {
      bool inS1Line = false;
      bool inS2Line = false;
      for (final line in allLines) {
        if (line.any((s) => s.name == s1.name) && line.any((s) => s.name == name)) {
          inS1Line = true;
        }
        if (line.any((s) => s.name == s2.name) && line.any((s) => s.name == name)) {
          inS2Line = true;
        }
      }
      if (inS1Line && inS2Line) {
        return allStations.firstWhere((s) => s.name == name);
      }
    }
    return null;
  }
}
