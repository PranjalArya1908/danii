import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../models/models.dart';
import '../theme/app_colors.dart';

enum MapLayerStyle {
  satellite,
  streets,
}

class SatelliteMapView extends StatefulWidget {
  final LatLngPoint location;
  final double? heading;
  final double height;
  final bool isInteractive;
  final bool showControls;
  final bool autoFollow;

  const SatelliteMapView({
    super.key,
    required this.location,
    this.heading,
    this.height = 250,
    this.isInteractive = true,
    this.showControls = true,
    this.autoFollow = true,
  });

  @override
  State<SatelliteMapView> createState() => _SatelliteMapViewState();
}

class _SatelliteMapViewState extends State<SatelliteMapView>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  late final AnimationController _zoomInController;
  late final Animation<double> _zoomAnimation;
  StreamSubscription<CompassEvent>? _compassSub;

  double _zoom = 2.0; // Start completely zoomed out (maximum world view)
  double _deviceHeading = 0.0;
  bool _autoFollow = true;
  MapLayerStyle _layerStyle = MapLayerStyle.satellite;
  final bool _showHybridLabels = true;
  bool _isZoomingIn = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _autoFollow = widget.autoFollow;
    _deviceHeading = widget.heading ?? 0.0;
    _zoom = 2.0;
    _isZoomingIn = true;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _zoomInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _zoomAnimation = CurvedAnimation(
      parent: _zoomInController,
      curve: Curves.easeInOutCubic,
    );

    _zoomInController.addListener(() {
      if (_isZoomingIn && mounted) {
        final targetLatLng = LatLng(widget.location.latitude, widget.location.longitude);
        final animZoom = 2.0 + (_zoomAnimation.value * 14.0); // 2.0 (max out) -> 16.0 (user location)
        _zoom = animZoom;
        try {
          _mapController.move(targetLatLng, animZoom);
        } catch (_) {}
      }
    });

    _zoomInController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _isZoomingIn = false;
          _zoom = 16.0;
        });
      }
    });

    _zoomInController.forward();
    _initCompass();
  }

  void _replayZoomInAnimation() {
    setState(() {
      _isZoomingIn = true;
      _zoom = 2.0;
    });
    final targetLatLng = LatLng(widget.location.latitude, widget.location.longitude);
    try {
      _mapController.move(targetLatLng, 2.0);
    } catch (_) {}
    _zoomInController.reset();
    _zoomInController.forward();
  }

  void _skipZoomInAnimation() {
    _zoomInController.stop();
    final targetLatLng = LatLng(widget.location.latitude, widget.location.longitude);
    try {
      _mapController.move(targetLatLng, 16.0);
    } catch (_) {}
    setState(() {
      _isZoomingIn = false;
      _zoom = 16.0;
    });
  }

  void _initCompass() {
    try {
      final stream = FlutterCompass.events;
      if (stream != null) {
        _compassSub = stream.listen((event) {
          if (event.heading != null && mounted) {
            final h = (event.heading! % 360 + 360) % 360;
            if ((h - _deviceHeading).abs() > 0.5) {
              setState(() {
                _deviceHeading = h;
              });
            }
          }
        }, onError: (err) {
          debugPrint('SatelliteMapView compass error: $err');
        });
      }
    } catch (e) {
      debugPrint('SatelliteMapView compass init error: $e');
    }
  }

  @override
  void didUpdateWidget(SatelliteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.heading != null && widget.heading != oldWidget.heading) {
      _deviceHeading = widget.heading!;
    }

    if (widget.location.latitude != oldWidget.location.latitude ||
        widget.location.longitude != oldWidget.location.longitude) {
      if (_autoFollow && !_isZoomingIn && mounted) {
        try {
          _mapController.move(
            LatLng(widget.location.latitude, widget.location.longitude),
            _zoom,
          );
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _pulseController.dispose();
    _zoomInController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    if (_zoom < 19) {
      setState(() {
        _zoom = (_zoom + 1).clamp(3.0, 19.0);
      });
      try {
        _mapController.move(
          _mapController.camera.center,
          _zoom,
        );
      } catch (_) {}
    }
  }

  void _zoomOut() {
    if (_zoom > 4) {
      setState(() {
        _zoom = (_zoom - 1).clamp(3.0, 19.0);
      });
      try {
        _mapController.move(
          _mapController.camera.center,
          _zoom,
        );
      } catch (_) {}
    }
  }

  void _recenterOnUser() {
    setState(() {
      _autoFollow = true;
    });
    _mapController.move(
      LatLng(widget.location.latitude, widget.location.longitude),
      _zoom,
    );
  }

  String _formatCoordinate(double val, bool isLat) {
    final cardinal = isLat ? (val >= 0 ? 'N' : 'S') : (val >= 0 ? 'E' : 'W');
    return '${val.abs().toStringAsFixed(4)}° $cardinal';
  }

  String _getHeadingDirection(double deg) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = ((deg + 22.5) % 360 / 45).floor();
    return directions[idx];
  }

  void _openFullScreenSatelliteSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.90,
          decoration: BoxDecoration(
            color: isDark ? AppColors.midnightDarkBackground : AppColors.lightBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryCobalt.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.satellite_alt,
                              color: AppColors.primaryCobalt, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live Telemetry Navigation',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              'Continuous Tiles • Device Compass Active',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Expanded Map
              Expanded(
                child: SatelliteMapView(
                  location: widget.location,
                  heading: _deviceHeading,
                  height: double.infinity,
                  isInteractive: true,
                  showControls: true,
                ),
              ),

              // Telemetry Data Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.midnightDarkCardBorder
                          : AppColors.lightCardBorder,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('LATITUDE', _formatCoordinate(widget.location.latitude, true), isDark),
                    _buildStatItem('LONGITUDE', _formatCoordinate(widget.location.longitude, false), isDark),
                    _buildStatItem('HEADING', '${_deviceHeading.toStringAsFixed(0)}° ${_getHeadingDirection(_deviceHeading)}', isDark, color: AppColors.primaryCobalt),
                    _buildStatItem('GNSS LOCK', '±3.2 m', isDark, color: AppColors.safeGreen),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color ?? (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildRotatingPuck() {
    final effectiveHeading = widget.heading ?? _deviceHeading;
    final headingRad = effectiveHeading * math.pi / 180.0;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Pulsing radar aura
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final scale = 1.0 + (_pulseController.value * 0.45);
              final alpha = (1.0 - _pulseController.value) * 0.35;
              return Container(
                width: 48 * scale,
                height: 48 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryCobalt.withValues(alpha: alpha),
                ),
              );
            },
          ),

          // 2. Compass Rotating Arrow & Navigation Cone
          Transform.rotate(
            angle: headingRad,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Directional cone beam pointing forward
                  Positioned(
                    top: 0,
                    child: CustomPaint(
                      size: const Size(28, 20),
                      painter: _DirectionBeamPainter(),
                    ),
                  ),

                  // Core Puck Circle
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryCobalt,
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCobalt.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryCobalt,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),

                  // Pointer Arrow Tip at the edge of the puck
                  Positioned(
                    top: 6,
                    child: CustomPaint(
                      size: const Size(10, 8),
                      painter: _ArrowTipPainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetLatLng = LatLng(widget.location.latitude, widget.location.longitude);

    return Container(
      width: double.infinity,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF070B19),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 1. Continuous FlutterMap Layer
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: targetLatLng,
                initialZoom: 2.0, // Start completely zoomed out (maximum world view)
                minZoom: 2.0,
                maxZoom: 19.0,
                interactionOptions: InteractionOptions(
                  flags: widget.isInteractive
                      ? (_autoFollow
                          ? (InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom)
                          : InteractiveFlag.all)
                      : InteractiveFlag.none,
                ),
                onPositionChanged: (camera, hasGesture) {
                  // Follow Mode is firmly locked - do NOT switch to Free mode on gesture!
                  _zoom = camera.zoom;
                },
              ),
              children: [
                // Base Tile Layer
                TileLayer(
                  urlTemplate: _layerStyle == MapLayerStyle.satellite
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}.jpg'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.shemove.app',
                  maxZoom: 19,
                  errorTileCallback: (tile, error, stackTrace) {
                    debugPrint('Tile loading error: $error');
                  },
                ),

                // Hybrid Street Names & Boundaries Overlay for Satellite
                if (_layerStyle == MapLayerStyle.satellite && _showHybridLabels)
                  TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}.png',
                    userAgentPackageName: 'com.shemove.app',
                    maxZoom: 19,
                  ),

                // Accuracy Radius Circle
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: targetLatLng,
                      radius: 38,
                      useRadiusInMeter: false,
                      color: AppColors.primaryCobalt.withValues(alpha: 0.16),
                      borderColor: AppColors.primaryCobalt.withValues(alpha: 0.5),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

                // Rotating Directional Arrow Marker
                MarkerLayer(
                  markers: [
                    Marker(
                      point: targetLatLng,
                      width: 60,
                      height: 60,
                      child: _buildRotatingPuck(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Top Status HUD Overlay (horizontally scrollable to guarantee 0 overflow on all screen sizes)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Live Satellite / Vector Mode Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xDD0D132D),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primaryCobalt.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.safeGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _layerStyle == MapLayerStyle.satellite
                              ? 'LIVE SATELLITE'
                              : 'STREET VECTOR',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. Zooming In Badge & Skip Button (active during initial entry or replay)
                  if (_isZoomingIn) ...[
                    AnimatedBuilder(
                      animation: _zoomInController,
                      builder: (context, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xDD0D132D),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.electricCyan),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.electricCyan,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ZOOMING IN ${(2.0 + (_zoomAnimation.value * 14.0)).toStringAsFixed(1)}x',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _skipZoomInAnimation,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCobalt,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryCobalt.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(Icons.fast_forward_rounded, size: 12, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Auto-follow indicator / button with locked Follow Mode
                  InkWell(
                    onTap: () {
                      setState(() {
                        _autoFollow = !_autoFollow;
                        if (_autoFollow) {
                          _mapController.move(targetLatLng, _zoom);
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _autoFollow
                                ? 'Follow Mode: Locked on User GPS'
                                : 'Free Exploration Mode Active',
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          backgroundColor:
                              _autoFollow ? AppColors.primaryCobalt : AppColors.infoBlue,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _autoFollow
                            ? AppColors.primaryCobalt.withValues(alpha: 0.9)
                            : const Color(0xDD0D132D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _autoFollow
                              ? AppColors.electricCyan
                              : AppColors.primaryCobalt.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _autoFollow ? Icons.lock_rounded : Icons.lock_open_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _autoFollow ? 'Follow Locked' : 'Free Mode',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Zoom-In Replay Button
                  InkWell(
                    onTap: _replayZoomInAnimation,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xDD0D132D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryCobalt.withValues(alpha: 0.35)),
                      ),
                      child: const Tooltip(
                        message: 'Replay Zoom-In Animation',
                        child: Icon(Icons.travel_explore, size: 14, color: AppColors.electricCyan),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Map Layer Toggle (Sat / Street)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _layerStyle = _layerStyle == MapLayerStyle.satellite
                            ? MapLayerStyle.streets
                            : MapLayerStyle.satellite;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xDD0D132D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryCobalt.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _layerStyle == MapLayerStyle.satellite
                                ? Icons.map
                                : Icons.satellite_alt,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _layerStyle == MapLayerStyle.satellite ? 'Street' : 'Sat',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Fullscreen Button
                  InkWell(
                    onTap: () => _openFullScreenSatelliteSheet(context, isDark),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xDD0D132D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryCobalt.withValues(alpha: 0.35)),
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Coordinates & Zoom Controls Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xEE070B19)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location, size: 14, color: AppColors.safeGreen),
                  const SizedBox(width: 6),
                  // GPS coordinates & direction display
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.location.address.isNotEmpty
                              ? widget.location.address
                              : 'Real-time GPS Telemetry',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_formatCoordinate(widget.location.latitude, true)}, ${_formatCoordinate(widget.location.longitude, false)} • ${_deviceHeading.toStringAsFixed(0)}° ${_getHeadingDirection(_deviceHeading)} • Z${_zoom.toStringAsFixed(0)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.electricCyan,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Zoom & Recenter Controls
                  if (widget.showControls) ...[
                    const SizedBox(width: 6),
                    _buildMapActionButton(
                      icon: Icons.filter_center_focus,
                      onTap: _recenterOnUser,
                    ),
                    const SizedBox(width: 4),
                    _buildMapActionButton(
                      icon: Icons.remove,
                      onTap: _zoomOut,
                    ),
                    const SizedBox(width: 4),
                    _buildMapActionButton(
                      icon: Icons.add,
                      onTap: _zoomIn,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xDD0D132D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryCobalt.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}

class _DirectionBeamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          AppColors.primaryCobalt.withValues(alpha: 0.65),
          AppColors.electricCyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.35, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width * 0.65, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArrowTipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryCobalt
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width / 2, size.height * 0.65);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
