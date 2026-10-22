import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class LocationResult {
  final String address;
  final double latitude;
  final double longitude;
  final String? city;

  const LocationResult({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.city,
  });
}

/// Interactive Location Picker Modal with OpenStreetMap tiles, Nominatim search, and GPS detection
class LocationPickerModal extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const LocationPickerModal({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  static Future<LocationResult?> show(
    BuildContext context, {
    double? initialLatitude,
    double? initialLongitude,
    String? initialAddress,
  }) {
    return showModalBottomSheet<LocationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerModal(
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        initialAddress: initialAddress,
      ),
    );
  }

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  late LatLng _selectedPoint;
  String _currentAddress = 'Loading address...';
  bool _isLoadingAddress = false;
  bool _isLocating = false;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  static const List<({String name, String city, double lat, double lng})> _kenyaHubs = [
    (name: 'KICC', city: 'Nairobi', lat: -1.2887, lng: 36.8233),
    (name: 'Westlands', city: 'Nairobi', lat: -1.2674, lng: 36.8110),
    (name: 'Upper Hill', city: 'Nairobi', lat: -1.2980, lng: 36.8164),
    (name: 'Gigiri / UN', city: 'Nairobi', lat: -1.2335, lng: 36.8049),
    (name: 'Karen', city: 'Nairobi', lat: -1.3197, lng: 36.7065),
    (name: 'Mombasa Beach', city: 'Mombasa', lat: -4.0435, lng: 39.6682),
    (name: 'Kisumu Hub', city: 'Kisumu', lat: -0.0917, lng: 34.7680),
    (name: 'Nakuru Town', city: 'Nakuru', lat: -0.3031, lng: 36.0800),
    (name: 'Eldoret Hub', city: 'Eldoret', lat: 0.5143, lng: 35.2698),
  ];

  @override
  void initState() {
    super.initState();
    // Default to Nairobi, Kenya (-1.286389, 36.817223)
    final lat = widget.initialLatitude ?? -1.286389;
    final lng = widget.initialLongitude ?? 36.817223;
    _selectedPoint = LatLng(lat, lng);

    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _currentAddress = widget.initialAddress!;
    } else {
      _reverseGeocode(_selectedPoint);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Reverse geocode LatLng to human-readable address via OpenStreetMap Nominatim
  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isLoadingAddress = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'EntreeEventCheckinApp/1.0 (support@entree.app)',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final displayName = data['display_name']?.toString() ?? '';
        if (mounted && displayName.isNotEmpty) {
          setState(() {
            _currentAddress = _shortenAddress(displayName);
            _isLoadingAddress = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentAddress = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        _isLoadingAddress = false;
      });
    }
  }

  String _shortenAddress(String raw) {
    final parts = raw.split(',');
    if (parts.length > 3) {
      return '${parts[0].trim()}, ${parts[1].trim()}, ${parts[2].trim()}';
    }
    return raw;
  }

  // Search places via Nominatim geocoding, prioritizing Kenya
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      try {
        // Prioritize Kenya venues first
        final uriKe = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query.trim())}&countrycodes=ke&format=json&limit=6&addressdetails=1',
        );
        var res = await http.get(uriKe, headers: {
          'User-Agent': 'EntreeEventCheckinApp/1.0 (support@entree.app)',
        }).timeout(const Duration(seconds: 4));

        List<Map<String, dynamic>> results = [];
        if (res.statusCode == 200) {
          results = (jsonDecode(res.body) as List<dynamic>)
              .map((e) => e as Map<String, dynamic>)
              .toList();
        }

        // If no results specifically in Kenya, fallback to global
        if (results.isEmpty) {
          final uriGlobal = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query.trim())}&format=json&limit=5&addressdetails=1',
          );
          res = await http.get(uriGlobal, headers: {
            'User-Agent': 'EntreeEventCheckinApp/1.0 (support@entree.app)',
          }).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            results = (jsonDecode(res.body) as List<dynamic>)
                .map((e) => e as Map<String, dynamic>)
                .toList();
          }
        }

        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
          return;
        }
      } catch (_) {}

      if (mounted) setState(() => _isSearching = false);
    });
  }

  void _selectSearchResult(Map<String, dynamic> item) {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat != null && lon != null) {
      final point = LatLng(lat, lon);
      setState(() {
        _selectedPoint = point;
        _currentAddress = _shortenAddress(item['display_name']?.toString() ?? '');
        _searchResults = [];
        _searchController.text = _currentAddress;
      });
      _mapController.move(point, 15.0);
    }
  }

  void _selectHub(({String name, String city, double lat, double lng}) hub) {
    final point = LatLng(hub.lat, hub.lng);
    setState(() {
      _selectedPoint = point;
      _currentAddress = '${hub.name}, ${hub.city}, Kenya';
      _searchResults = [];
      _searchController.text = '${hub.name}, ${hub.city}';
    });
    _mapController.move(point, 15.0);
    _reverseGeocode(point);
  }

  // Geolocator GPS detection
  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied.')),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final point = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _selectedPoint = point;
          _isLocating = false;
        });
        _mapController.move(point, 16.0);
        _reverseGeocode(point);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
        setState(() => _isLocating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Container(
      height: size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : AppTheme.surfaceWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Stack(
          children: [
            // 1. OpenStreetMap Map View
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedPoint,
                initialZoom: 14.5,
                onTap: (_, point) {
                  setState(() {
                    _selectedPoint = point;
                    _searchResults = [];
                  });
                  _reverseGeocode(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.entree.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint,
                      width: 50,
                      height: 50,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 24,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 2. Top Header & Search Bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // Header Row with Drag Handle
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search Kenyan venues (e.g. KICC, Sarit, Radisson)...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13.5,
                              color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                            ),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : (_searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchResults = []);
                                        },
                                      )
                                    : null),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),

                        // Search Results Dropdown List
                        if (_searchResults.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: isDark ? AppTheme.darkCardBorder : const Color(0xFFF1F5F9),
                                ),
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: isDark ? AppTheme.darkCardBorder : const Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (context, idx) {
                                final item = _searchResults[idx];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.place_outlined, size: 18),
                                  title: Text(
                                    item['display_name']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontSize: 12.5),
                                  ),
                                  onTap: () => _selectSearchResult(item),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _kenyaHubs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, idx) {
                        final hub = _kenyaHubs[idx];
                        return ActionChip(
                          label: Text(hub.name),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                          side: BorderSide(
                            color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          onPressed: () => _selectHub(hub),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 3. Floating GPS Button ("Use Current Location")
            Positioned(
              right: 16,
              bottom: 180,
              child: FloatingActionButton.extended(
                heroTag: 'gps_loc_btn',
                onPressed: _isLocating ? null : _useCurrentLocation,
                backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                foregroundColor: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                elevation: 4,
                icon: _isLocating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  'My Location',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // 4. Bottom Confirmation Sheet
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.accentLime.withValues(alpha: 0.15)
                                : AppTheme.primaryPurple.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.location_city_rounded,
                            color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SELECTED VENUE',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              _isLoadingAddress
                                  ? const Row(
                                      children: [
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 1.5),
                                        ),
                                        SizedBox(width: 8),
                                        Text('Resolving address...', style: TextStyle(fontSize: 13)),
                                      ],
                                    )
                                  : Text(
                                      _currentAddress,
                                      style: GoogleFonts.inter(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : AppTheme.textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              const SizedBox(height: 4),
                              Text(
                                'Lat: ${_selectedPoint.latitude.toStringAsFixed(5)}, Lon: ${_selectedPoint.longitude.toStringAsFixed(5)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(
                            context,
                            LocationResult(
                              address: _currentAddress,
                              latitude: _selectedPoint.latitude,
                              longitude: _selectedPoint.longitude,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppTheme.accentLime : AppTheme.primaryBlack,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(
                          'Confirm Location',
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
