import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/entities/note.dart';
import '../repositories/note_repository.dart';
import '../services/location_service.dart';

class EditNotePage extends StatefulWidget {
  final NoteRepository repository;
  final Note note;

  const EditNotePage({
    super.key,
    required this.repository,
    required this.note,
  });

  @override
  State<EditNotePage> createState() => _EditNotePageState();
}

class _EditNotePageState extends State<EditNotePage> {
  late TextEditingController _contentController;
  String _distanceText = '';
  bool _hasLocation = false;
  bool _isFetchingLocation = false;
  double? _latitude;
  double? _longitude;
  String? _address;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.note.content);

    _latitude = widget.note.latitude;
    _longitude = widget.note.longitude;
    _hasLocation = _latitude != null && _longitude != null;
    _address = widget.note.address;

    if (_hasLocation &&
        (widget.note.address == null || widget.note.address!.trim().isEmpty)) {
      _backfillAddress();
    }

    if (_hasLocation) {
      _loadDistanceInfo();
    }
  }

  Future<void> _backfillAddress() async {
    final address =
        await LocationService.reverseGeocode(_latitude!, _longitude!);
    if (mounted) {
      setState(() => _address = address);
    }
  }

  Future<void> _loadDistanceInfo() async {
    if (_latitude == null || _longitude == null) return;
    try {
      final currentPosition = await LocationService.getApproximatePosition();
      if (currentPosition == null) {
        if (mounted) setState(() => _distanceText = '');
        return;
      }

      final distanceInMeters = LocationService.distanceBetweenMeters(
        currentPosition.latitude,
        currentPosition.longitude,
        _latitude!,
        _longitude!,
      );

      final distanceText = distanceInMeters >= 1000
          ? '${(distanceInMeters / 1000).toStringAsFixed(1)} km'
          : '${distanceInMeters.round()} m';

      final minutes = ((distanceInMeters / 1000) / 30 * 60).round();
      final driveTime = minutes <= 0 ? '1 min' : '$minutes min';

      if (mounted) {
        setState(() => _distanceText = '$distanceText • $driveTime');
      }
    } catch (_) {
      if (mounted) setState(() => _distanceText = '');
    }
  }

  Future<void> _openMap() async {
    if (_latitude == null || _longitude == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$_latitude,$_longitude&travelmode=driving',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('Could not open map app.');
    }
  }

  void _showSnack(String message,
      {String? actionLabel, VoidCallback? onAction}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }

  Future<void> _refreshFromCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    final result = await LocationService.getCurrentLocation();

    switch (result.outcome) {
      case LocationOutcome.serviceDisabled:
        _showSnack('Location is off on this device - opening settings...');
        await LocationService.openSystemLocationSettings();
        break;
      case LocationOutcome.permissionDenied:
        _showSnack('Location permission is off - opening settings...');
        await LocationService.openSystemLocationSettings();
        break;
      case LocationOutcome.permissionDeniedForever:
        _showSnack('Location permission is denied - opening settings...');
        await LocationService.openSystemLocationSettings();
        break;
      case LocationOutcome.error:
        _showSnack('Could not get your current location.');
        break;
      case LocationOutcome.success:
        final position = result.position!;
        final address = await LocationService.reverseGeocode(
          position.latitude,
          position.longitude,
        );
        if (mounted) {
          setState(() {
            _latitude = position.latitude;
            _longitude = position.longitude;
            _hasLocation = true;
            _address = address;
          });
          _loadDistanceInfo();
        }
        break;
    }

    if (mounted) setState(() => _isFetchingLocation = false);
  }

  void _removeLocation() {
    setState(() {
      _hasLocation = false;
      _latitude = null;
      _longitude = null;
      _distanceText = '';
      _address = null;
    });
  }

  Future<void> _updateNote() async {
    final updatedText = _contentController.text.trim();
    if (updatedText.isEmpty) {
      _showSnack('Note cannot be empty');
      return;
    }

    final latitude = _hasLocation ? _latitude : null;
    final longitude = _hasLocation ? _longitude : null;
    final address = _hasLocation ? _address : null;
    final original = widget.note;
    final unchanged = updatedText == original.content &&
        latitude == original.latitude &&
        longitude == original.longitude &&
        address == original.address;
    if (unchanged) {
      Navigator.pop(context);
      return;
    }

    final updatedNote = Note(
      id: original.id,
      content: updatedText,
      latitude: latitude,
      longitude: longitude,
      address: address,
      createdAt: original.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await widget.repository.updateNote(updatedNote);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteNote() async {
    await widget.repository.deleteNote(widget.note);
    if (mounted) Navigator.pop(context, widget.note);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF2D3142), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Edit note',
            style: TextStyle(
              color: Color(0xFF2D3142),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isVeryCompact = constraints.maxWidth < 280;
            final isDesktop = constraints.maxWidth > 700;
            final horizontalPadding = isVeryCompact
                ? 8.0
                : (isDesktop ? 40.0 : 16.0);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildNoteInputCard(constraints),
                      const SizedBox(height: 16),
                      _buildLocationCard(isVeryCompact),
                      const SizedBox(height: 20),
                      _buildActionButtons(constraints.maxWidth),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoteInputCard(BoxConstraints constraints) {
    final maxHeight = constraints.maxHeight * 0.35;
    return Container(
      constraints: BoxConstraints(
        minHeight: 140,
        maxHeight: maxHeight < 160 ? 160 : maxHeight,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.edit, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    scrollPhysics: const BouncingScrollPhysics(),
                    decoration: const InputDecoration(
                      hintText: 'What do you want to remember?',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.bottomRight,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _contentController,
              builder: (_, value, _) => Text(
                '${value.text.length} characters',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(bool isVeryCompact) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EAF6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on,
                    color: Color(0xFF3F4494), size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Location',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                ),
              ),
              if (_hasLocation)
                IconButton(
                  onPressed: _removeLocation,
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  tooltip: 'Remove location',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              IconButton(
                onPressed:
                    _isFetchingLocation ? null : _refreshFromCurrentLocation,
                tooltip: 'Use my current location',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                icon: _isFetchingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location,
                        color: Color(0xFF3F4494), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _hasLocation
                ? (_isFetchingLocation
                    ? 'Finding your location...'
                    : (_address ?? 'Resolving address...'))
                : 'No address yet',
            style: TextStyle(
              fontSize: 13,
              color: _hasLocation ? const Color(0xFF2D3142) : Colors.grey,
            ),
          ),
          if (_hasLocation) ...[
            if (_distanceText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _distanceText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF3F4494),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _openMap,
              child: Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.location_on,
                          size: 32, color: Color(0xCC3F4494)),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Color(0x1A000000), blurRadius: 4),
                          ],
                        ),
                        child: const Text(
                          'View on map',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'No GPS pin attached.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(double maxWidth) {
    final isDesktopRow = maxWidth > 500;
    final isUltraCompact = maxWidth < 200;

    final saveButton = ElevatedButton(
      onPressed: _updateNote,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3F4494),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isUltraCompact) ...[
            const Icon(Icons.save, color: Colors.white, size: 18),
            const SizedBox(width: 6),
          ],
          const Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Save changes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final deleteButton = OutlinedButton(
      onPressed: _deleteNote,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.redAccent),
        backgroundColor: const Color(0xFFFFF4F4),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isUltraCompact) ...[
            const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
            const SizedBox(width: 6),
          ],
          const Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Delete note',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isDesktopRow) {
      return Row(
        children: [
          Expanded(child: deleteButton),
          const SizedBox(width: 12),
          Expanded(child: saveButton),
        ],
      );
    }

    return Column(
      children: [
        saveButton,
        const SizedBox(height: 10),
        deleteButton,
      ],
    );
  }
}