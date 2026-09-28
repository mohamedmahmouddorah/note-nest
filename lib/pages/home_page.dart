import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shake/shake.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/entities/note.dart';
import '../repositories/note_repository.dart';
import '../services/location_service.dart';
import '../utils/date_format.dart';
import 'add_note_page.dart';
import 'edit_note_page.dart';

class HomePage extends StatefulWidget {
  final NoteRepository repository;
  const HomePage({super.key, required this.repository});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  late final ShakeDetector _shakeDetector;

  bool _shakeListening = false;
  bool _pageCovered = false;
  bool _deleteDialogOpen = false;
  int _noteCount = 0;
  String _searchQuery = '';
  Timer? _searchDebounce;

  final Map<int, String> _addressCache = {};

  bool get _mapTabActive => _selectedIndex == 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shakeDetector = ShakeDetector.waitForStart(
      onPhoneShake: ([dynamic _]) {
        _confirmDeleteAllNotes(fromShake: true);
      },
      shakeThresholdGravity: 2.7,
    );
    _setShakeListening(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setShakeListening(false);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setShakeListening(!_pageCovered);
    } else if (state == AppLifecycleState.paused) {
      _setShakeListening(false);
    }
  }

  void _setShakeListening(bool listen) {
    if (listen == _shakeListening) return;
    _shakeListening = listen;
    if (listen) {
      _shakeDetector.startListening();
    } else {
      _shakeDetector.stopListening();
    }
  }

  Future<void> _openPage(Widget page) async {
    _pageCovered = true;
    _setShakeListening(false);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _pageCovered = false;
    if (mounted) _setShakeListening(true);
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  Future<void> _confirmDeleteAllNotes({bool fromShake = false}) async {
    if (_deleteDialogOpen) return;
    if (_noteCount == 0) {
      if (!fromShake) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('There are no notes to delete.')),
        );
      }
      return;
    }

    _deleteDialogOpen = true;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fromShake ? 'Shake detected!' : 'Delete all notes?'),
        content: const Text('Do you want to delete all notes? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllNotes();
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    _deleteDialogOpen = false;
  }

  Future<void> _clearAllNotes() async {
    await widget.repository.deleteAllNotes();
    _addressCache.clear();
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notes cleared successfully!')),
    );
  }

  List<Note> _applyFilters(List<Note> notes) {
    var filtered = notes.where((note) {
      final contentText = note.content.toLowerCase();
      final locationText = (note.address ?? '').toLowerCase();
      return _searchQuery.isEmpty ||
          contentText.contains(_searchQuery) ||
          locationText.contains(_searchQuery);
    }).toList();

    if (_mapTabActive) {
      filtered = filtered.where((note) => note.latitude != null && note.longitude != null).toList();
    }

    return filtered;
  }

  Future<String> _resolveAndCacheAddress(Note note) async {
    final address = await LocationService.reverseGeocode(note.latitude!, note.longitude!);
    _addressCache[note.id!] = address;
    await widget.repository.updateAddress(note.id!, address);
    return address;
  }

  Future<void> _openMapForLocation(Note note) async {
    if (note.latitude == null || note.longitude == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${note.latitude!},${note.longitude!}&travelmode=driving',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open map.')),
        );
      }
    }
  }

  Widget _buildNoteCard(Note note) {
    final lines = note.content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final title = lines.isNotEmpty ? lines.first : 'Note';
    final subtitle = lines.length > 1 ? lines.sublist(1).join(' ') : 'No additional text...';

    return GestureDetector(
      onTap: () => _openPage(
        EditNotePage(repository: widget.repository, note: note),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            if (note.latitude != null && note.longitude != null)
              Builder(
                builder: (context) {
                  final storedAddress = note.address?.trim();
                  final knownLabel = (storedAddress != null && storedAddress.isNotEmpty)
                      ? storedAddress
                      : _addressCache[note.id];

                  if (knownLabel != null) {
                    return _locationChip(knownLabel, note);
                  }

                  return FutureBuilder<String>(
                    future: _resolveAndCacheAddress(note),
                    builder: (context, snapshot) {
                      return _locationChip(snapshot.data ?? 'Finding location...', note);
                    },
                  );
                },
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  note.isEdited
                      ? 'Edited ${formatNoteDate(note.updatedAt)}'
                      : formatNoteDate(note.createdAt),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationChip(String locName, Note note) {
    return GestureDetector(
      onTap: () => _openMapForLocation(note),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, size: 12, color: Colors.green),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                locName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _mapTabActive ? 'Notes with a location' : 'My Notes',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _confirmDeleteAllNotes(),
                    tooltip: 'Delete all notes',
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x05000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search notes or locations...',
                    icon: Icon(Icons.search, color: Colors.grey, size: 20),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<List<Note>>(
                  stream: widget.repository.watchAllNotes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allNotes = snapshot.data ?? [];
                    _noteCount = allNotes.length;
                    final liveIds = allNotes.map((n) => n.id).whereType<int>().toSet();
                    _addressCache.removeWhere((id, _) => !liveIds.contains(id));

                    final notes = _applyFilters(allNotes);
                    if (notes.isEmpty) {
                      return Center(
                        child: Text(
                          _mapTabActive ? 'No notes with a saved location yet' : 'No notes found',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: notes.length,
                      itemBuilder: (context, index) => _buildNoteCard(notes[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3F4494),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _openPage(AddNotePage(repository: widget.repository)),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFF3F4494),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Notes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined),
              label: 'Map',
            ),
          ],
        ),
      ),
    );
  }
}
