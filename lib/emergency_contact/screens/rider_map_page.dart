import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:novaride/emergency_contact/data/emergency_contact_repository.dart';
import 'package:novaride/emergency_contact/models/emergency_contact_models.dart';
import 'package:novaride/emergency_contact/models/rider_location.dart';
import 'package:novaride/emergency_contact/widgets/emergency_bottom_nav_bar.dart';
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

class RiderMapPage extends StatefulWidget {
  const RiderMapPage({super.key});
  @override
  State<RiderMapPage> createState() => _RiderMapPageState();
}

class _RiderMapPageState extends State<RiderMapPage> {
  final _repository = EmergencyContactRepository();
  GoogleMapController? _mapController;
  StreamSubscription<RiderLocation>? _locationSubscription;
  RiderLocation? _location;
  bool _hasCentered = false;

  @override
  void initState() {
    super.initState();
    _locationSubscription = _repository.watchRiderLocation().listen((location) {
      if (!mounted) return;
      setState(() => _location = location);
      if (_hasCentered) _animateToRider(location);
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    final location = _location;
    if (location != null) {
      _hasCentered = true;
      _animateToRider(location);
    }
  }

  Future<void> _animateToRider(RiderLocation location) async => _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(location.latitude, location.longitude), 16),
      );

  Set<Marker> _markers(RiderLocation location) => {
        Marker(
          markerId: const MarkerId('connected-rider'),
          position: LatLng(location.latitude, location.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          rotation: location.heading ?? 0,
          flat: true,
          infoWindow: InfoWindow(title: _repository.connectedRider.name, snippet: location.status),
        ),
      };

  @override
  Widget build(BuildContext context) {
    final rider = _repository.connectedRider;
    final location = _location;
    final emergency = rider.status == RiderStatus.accidentDetected || rider.status == RiderStatus.sosActive;
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              IconButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/emergency-dashboard'), icon: const Icon(Icons.arrow_back, color: Colors.white)),
              const SizedBox(width: 4),
              const Text('Live Location', style: TextStyle(color: NovaColors.primaryText, fontSize: 24, fontWeight: FontWeight.w800)),
            ]),
          ),
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: NovaColors.cardBorder)),
                  child: location == null
                      ? const Center(child: CircularProgressIndicator(color: NovaColors.cyan))
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(target: LatLng(location.latitude, location.longitude), zoom: 16),
                          style: _novaRideMapStyle,
                          onMapCreated: _onMapCreated,
                          markers: _markers(location),
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          compassEnabled: true,
                          mapToolbarEnabled: false,
                        ),
                ),
              ),
              if (emergency) Positioned(top: 20, left: 32, right: 32, child: _EmergencyBanner(status: rider.status.label)),
              Positioned(
                right: 20,
                bottom: 132,
                child: FloatingActionButton(
                  heroTag: 'emergency-center-rider',
                  backgroundColor: emergency ? NovaColors.red : NovaColors.cyan,
                  onPressed: location == null ? null : () { _hasCentered = true; _animateToRider(location); },
                  child: const Icon(Icons.my_location, color: Colors.black),
                ),
              ),
              Positioned(bottom: 24, left: 18, right: 18, child: _RiderInfoCard(rider: rider, location: location)),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: const EmergencyBottomNavBar(selectedIndex: 1),
    );
  }
}

class _RiderInfoCard extends StatelessWidget {
  final ConnectedRider rider;
  final RiderLocation? location;
  const _RiderInfoCard({required this.rider, required this.location});

  @override
  Widget build(BuildContext context) {
    final unavailable = !rider.gpsActive || location == null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: NovaColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: NovaColors.cardBorder), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6))]),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rider.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('● ${rider.status.label}', style: TextStyle(color: rider.status.color, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(unavailable ? 'Location unavailable' : '${location!.speedKmh.toStringAsFixed(0)} km/h', style: const TextStyle(color: NovaColors.primaryText, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(unavailable ? 'Rider location unavailable' : location!.address, style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12)),
          const SizedBox(height: 6),
          Text('Updated ${rider.lastUpdatedSeconds} seconds ago', style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11)),
        ])),
        Container(width: 14, height: 14, decoration: BoxDecoration(color: rider.internetConnected ? NovaColors.green : NovaColors.secondaryText, shape: BoxShape.circle)),
      ]),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  final String status;
  const _EmergencyBanner({required this.status});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: NovaColors.red.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.white), const SizedBox(width: 8), Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))]),
  );
}
