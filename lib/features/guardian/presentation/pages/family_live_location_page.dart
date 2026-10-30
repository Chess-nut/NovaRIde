import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:novaride/core/constants/app_routes.dart';
import 'package:novaride/features/guardian/data/family_repository.dart';
import 'package:novaride/features/guardian/domain/models/family_models.dart';
import 'package:novaride/features/guardian/domain/models/rider_location.dart';
import 'package:novaride/features/guardian/presentation/widgets/family_bottom_nav_bar.dart';
import 'package:novaride/shared/maps/google_maps_key.dart';
import 'package:novaride/shared/maps/google_maps_script.dart';
import 'package:novaride/shared/theme.dart';

const _novaRideMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#101B2D"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8FA3B8"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#101B2D"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#26364A"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#123342"},{"visibility":"on"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#26364A"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#34465B"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3E5268"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#B7C7D8"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#102B3A"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#6F91A5"}]}
]''';

class FamilyLiveLocationPage extends ConsumerStatefulWidget {
  const FamilyLiveLocationPage({super.key, this.repository});

  final FamilyRepository? repository;

  @override
  ConsumerState<FamilyLiveLocationPage> createState() =>
      _FamilyLiveLocationPageState();
}

class _FamilyLiveLocationPageState extends ConsumerState<FamilyLiveLocationPage> {
  GoogleMapController? _mapController;
  bool _hasCentered = false;
  late Future<void> _mapsReady;

  FamilyRepository get _repository =>
      widget.repository ?? ref.watch(familyRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _mapsReady = kIsWeb
        ? loadGoogleMapsScript(googleMapsApiKeyWeb)
        : Future<void>.value();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller, RiderLocation location) {
    _mapController = controller;
    if (!_hasCentered) {
      _hasCentered = true;
      _animateToRider(location);
    }
  }

  Future<void> _animateToRider(RiderLocation location) async {
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        16,
      ),
    );
  }

  void _retryMapLoad() {
    setState(() {
      _mapsReady = loadGoogleMapsScript(googleMapsApiKeyWeb);
    });
  }

  Set<Marker> _markers(RiderLocation location, String riderName) => {
    Marker(
      markerId: const MarkerId('connected-rider'),
      position: LatLng(location.latitude, location.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      rotation: location.heading ?? 0,
      flat: true,
      infoWindow: InfoWindow(title: riderName, snippet: location.status),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go(AppRoutes.guardianHomePath),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Live Location',
                    style: TextStyle(
                      color: NovaColors.primaryText,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<FamilyConnectedRider?>(
                stream: _repository.watchRiderStatus(),
                builder: (context, riderSnapshot) {
                  if (riderSnapshot.hasError) {
                    return _LocationMessage(
                      title: 'Family data unavailable',
                      message: riderSnapshot.error.toString(),
                    );
                  }
                  if (riderSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: NovaColors.cyan),
                    );
                  }
                  final rider = riderSnapshot.data;
                  if (rider == null) {
                    return const _LocationMessage(
                      title: 'No rider connected',
                      message: 'Connect to a rider to view shared location.',
                    );
                  }
                  return StreamBuilder<RiderLocation?>(
                    stream: _repository.watchRiderLocation(),
                    builder: (context, locationSnapshot) {
                      if (locationSnapshot.hasError) {
                        return _LocationMessage(
                          title: 'Location unavailable',
                          message: locationSnapshot.error.toString(),
                        );
                      }
                      if (locationSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: NovaColors.cyan,
                          ),
                        );
                      }
                      final location = locationSnapshot.data;
                      if (location == null) {
                        return const _LocationMessage(
                          title: 'No GPS fix available',
                          message:
                              'The rider has not shared a valid GPS location, or location access is disabled.',
                        );
                      }
                      return _MapContent(
                        rider: rider,
                        location: location,
                        mapsReady: _mapsReady,
                        onRetry: _retryMapLoad,
                        onMapCreated: (controller) =>
                            _onMapCreated(controller, location),
                        markers: _markers(location, rider.name),
                        onCenter: () {
                          _hasCentered = true;
                          _animateToRider(location);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const FamilyBottomNavBar(selectedIndex: 1),
    );
  }
}

class _MapContent extends StatelessWidget {
  const _MapContent({
    required this.rider,
    required this.location,
    required this.mapsReady,
    required this.onRetry,
    required this.onMapCreated,
    required this.markers,
    required this.onCenter,
  });

  final FamilyConnectedRider rider;
  final RiderLocation location;
  final Future<void> mapsReady;
  final VoidCallback onRetry;
  final ValueChanged<GoogleMapController> onMapCreated;
  final Set<Marker> markers;
  final VoidCallback onCenter;

  @override
  Widget build(BuildContext context) {
    final isEmergency =
        rider.status == FamilyRiderStatus.accidentDetected ||
        rider.status == FamilyRiderStatus.sosActive;
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: NovaColors.cardBorder),
            ),
            child: FutureBuilder<void>(
              future: mapsReady,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _MapLoadError(
                    error: snapshot.error!,
                    onRetry: onRetry,
                  );
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: NovaColors.cyan),
                  );
                }
                return GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(location.latitude, location.longitude),
                    zoom: 16,
                  ),
                  style: _novaRideMapStyle,
                  onMapCreated: onMapCreated,
                  markers: markers,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                );
              },
            ),
          ),
        ),
        if (isEmergency)
          Positioned(
            top: 20,
            left: 32,
            right: 32,
            child: _EmergencyBanner(status: rider.status.label),
          ),
        Positioned(
          right: 20,
          bottom: 144,
          child: FloatingActionButton(
            heroTag: 'family-center-rider',
            backgroundColor: isEmergency ? NovaColors.red : NovaColors.cyan,
            onPressed: onCenter,
            child: const Icon(Icons.my_location, color: Colors.black),
          ),
        ),
        Positioned(
          bottom: 24,
          left: 18,
          right: 18,
          child: _RiderInfoCard(rider: rider, location: location),
        ),
      ],
    );
  }
}

class _MapLoadError extends StatelessWidget {
  const _MapLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, color: NovaColors.amber, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Map unavailable',
            style: TextStyle(
              color: NovaColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class _LocationMessage extends StatelessWidget {
  const _LocationMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_outlined, color: NovaColors.amber, size: 38),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: NovaColors.secondaryText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _RiderInfoCard extends StatelessWidget {
  const _RiderInfoCard({required this.rider, required this.location});

  final FamilyConnectedRider rider;
  final RiderLocation location;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: NovaColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: NovaColors.cardBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rider.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '● ${rider.status.label}',
                style: TextStyle(
                  color: rider.status.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                location.speedKmh == null
                    ? 'Speed unavailable'
                    : '${location.speedKmh!.toStringAsFixed(0)} km/h',
                style: const TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                location.address ?? 'Address unavailable',
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                location.timestamp == null
                    ? 'Update time unavailable'
                    : 'Updated ${_relativeTime(location.timestamp!)}',
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.wifi,
          color: rider.internetConnected == true
              ? NovaColors.green
              : NovaColors.secondaryText,
        ),
      ],
    ),
  );

  static String _relativeTime(DateTime timestamp) {
    final seconds = DateTime.now().difference(timestamp).inSeconds;
    if (seconds < 0) return 'recently';
    if (seconds < 60) return '$seconds seconds ago';
    return '${seconds ~/ 60} minutes ago';
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: NovaColors.red,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      status,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    ),
  );
}
