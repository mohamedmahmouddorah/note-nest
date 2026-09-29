import 'package:flutter/material.dart';
import '../db/entities/note.dart';
import '../repositories/note_repository.dart';
import '../services/location_service.dart';

class AddNotePage extends StatefulWidget {
  final NoteRepository repository;
  const AddNotePage({super.key, required this.repository});

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {
  final _contentController = TextEditingController();
  bool _includeLocation = false;
  bool _isSaving = false;
  bool _isFetchingLocation = false;
  double? _latitude;
  double? _longitude;
  String? _address;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {String? actionLabel, VoidCallback? onAction}) {
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

  Future<void> _fetchCurrentLocation() async {
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
            _address = address;
          });
        }
        break;
    }

    if (mounted) setState(() => _isFetchingLocation = false);
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showSnack('Please enter note content');
      return;
    }

    if (_includeLocation && _isFetchingLocation) {
      _showSnack('Still finding your location, please wait...');
      return;
    }
    if (_includeLocation && _latitude == null) {
      _showSnack('Location unavailable. Try again or turn "Add location" off.');
      return;
    }

    setState(() => _isSaving = true);

    final newNote = Note(
      content: content,
      latitude: _includeLocation ? _latitude : null,
      longitude: _includeLocation ? _longitude : null,
      address: _includeLocation ? _address : null,
    );

    await widget.repository.addNote(newNote);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2D3142), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add note',
          style: TextStyle(color: Color(0xFF2D3142), fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = MediaQuery.of(context).size.height * 0.40;
                return Container(
                  constraints: BoxConstraints(
                    minHeight: 160,
                    maxHeight: maxHeight,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.edit, color: Colors.orange, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _contentController,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                scrollPhysics: const BouncingScrollPhysics(),
                                decoration: const InputDecoration(
                                  hintText: 'What do you want to remember?',
                                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(fontSize: 16, color: Color(0xFF2D3142)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _contentController,
                          builder: (_, value, _) => Text(
                            '${value.text.length} حرف',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Add location (optional)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142)),
                    ),
                    subtitle: const Text(
                      'Save the place this note is about',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFFE8EAF6), shape: BoxShape.circle),
                      child: const Icon(Icons.location_on, color: Color(0xFF3F4494), size: 20),
                    ),
                    value: _includeLocation,
                    activeTrackColor: const Color(0xFFE8EAF6),
                    activeThumbColor: const Color(0xFF3F4494),
                    onChanged: (val) {
                      setState(() => _includeLocation = val);
                      if (val && _address == null) {
                        _fetchCurrentLocation();
                      }
                    },
                  ),
                  if (_includeLocation) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isFetchingLocation
                                ? 'Finding your location...'
                                : (_address ?? 'No address yet'),
                            style: TextStyle(
                              fontSize: 14,
                              color: _address == null
                                  ? Colors.grey
                                  : const Color(0xFF2D3142),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _isFetchingLocation ? null : _fetchCurrentLocation,
                          tooltip: 'Use my current location',
                          icon: _isFetchingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location, color: Color(0xFF3F4494), size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _isSaving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _saveNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F4494),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.save, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Save note', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}