import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const VizventoryApp());

class VizventoryApp extends StatelessWidget {
  const VizventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF06142C);
    const blue = Color(0xFF0477F2);
    const linen = Color(0xFFF8F5EF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vizventory',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: blue).copyWith(surface: linen),
        scaffoldBackgroundColor: linen,
        appBarTheme: const AppBarTheme(backgroundColor: ink, foregroundColor: Colors.white),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const VizventoryHome(),
    );
  }
}

class InventoryItem {
  InventoryItem({
    required this.id,
    required this.title,
    required this.status,
    this.category = '',
    this.size = '',
    this.color = '',
    this.condition = '',
    this.location = '',
    this.notes = '',
    this.tags = const [],
    this.photos = const [],
  });

  final String id;
  final String title;
  final String status;
  final String category;
  final String size;
  final String color;
  final String condition;
  final String location;
  final String notes;
  final List<String> tags;
  final List<String> photos;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Inventory item',
      status: json['status']?.toString() == 'Donated' ? 'Checked Out' : json['status']?.toString() ?? 'Available',
      category: json['category']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      condition: json['condition']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      tags: (json['tags'] as List? ?? []).map((tag) => tag.toString()).toList(),
      photos: (json['photos'] as List? ?? []).map((photo) => photo.toString()).toList(),
    );
  }
}

class VizventoryHome extends StatefulWidget {
  const VizventoryHome({super.key});

  @override
  State<VizventoryHome> createState() => _VizventoryHomeState();
}

class _VizventoryHomeState extends State<VizventoryHome> {
  static const _serverKey = 'vizventoryServerBase';
  static const _recentDevicesKey = 'vizventoryRecentDesktops';

  final _serverController = TextEditingController();
  int _tabIndex = 0;
  String _serverBase = '';
  String _message = 'Connect to a Vizventory desktop to begin.';
  List<String> _recentServers = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString(_serverKey) ?? '';
    final recent = prefs.getStringList(_recentDevicesKey) ?? [];
    if (!mounted) return;
    setState(() {
      _serverBase = server;
      _serverController.text = server;
      _recentServers = recent;
      _message = server.isEmpty ? _message : 'Connected to ${_friendlyServer(server)}.';
    });
  }

  Future<void> _saveServer(String serverBase) async {
    final normalized = _normalizeServer(serverBase);
    if (normalized.isEmpty) return;
    final recent = [normalized, ..._recentServers.where((item) => item != normalized)].take(5).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, normalized);
    await prefs.setStringList(_recentDevicesKey, recent);
    if (!mounted) return;
    setState(() {
      _serverBase = normalized;
      _serverController.text = normalized;
      _recentServers = recent;
      _message = 'Connected to ${_friendlyServer(normalized)}.';
    });
  }

  Future<void> _scanDesktopQr() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage(title: 'Scan Desktop QR')),
    );
    if (value == null) return;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _showMessage('That QR is not a Vizventory desktop link.');
      return;
    }
    final port = uri.hasPort ? ':${uri.port}' : '';
    await _saveServer('${uri.scheme}://${uri.host}$port');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    setState(() => _message = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _normalizeServer(String value) {
    var server = value.trim();
    if (server.isEmpty) return '';
    if (!server.startsWith('http://') && !server.startsWith('https://')) server = 'http://$server';
    while (server.endsWith('/')) {
      server = server.substring(0, server.length - 1);
    }
    return server;
  }

  String _friendlyServer(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  @override
  Widget build(BuildContext context) {
    final connected = _serverBase.isNotEmpty;
    final pages = [
      InventoryScreen(serverBase: _serverBase, onMessage: _showMessage),
      AddItemScreen(serverBase: _serverBase, onMessage: _showMessage),
      ScanScreen(serverBase: _serverBase, onMessage: _showMessage),
      SettingsScreen(
        serverBase: _serverBase,
        serverController: _serverController,
        recentServers: _recentServers,
        onSaveServer: _saveServer,
        onScanQr: _scanDesktopQr,
        onMessage: _showMessage,
        friendlyServer: _friendlyServer,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vizventory'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(connected ? Icons.cloud_done : Icons.cloud_off),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_message.isNotEmpty)
            Material(
              color: connected ? const Color(0xFFE8F1EA) : const Color(0xFFFFF4D7),
              child: ListTile(
                dense: true,
                leading: Icon(connected ? Icons.check_circle : Icons.info_outline),
                title: Text(_message),
              ),
            ),
          Expanded(child: pages[_tabIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.add_a_photo_outlined), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.serverBase, required this.onMessage});
  final String serverBase;
  final ValueChanged<String> onMessage;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  List<InventoryItem> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didUpdateWidget(covariant InventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverBase != widget.serverBase) _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (widget.serverBase.isEmpty) return;
    setState(() => _loading = true);
    try {
      final response = await http.get(Uri.parse('${widget.serverBase}/api/items')).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) throw Exception(data['error'] ?? 'Could not load inventory');
      setState(() {
        _items = (data['items'] as List? ?? []).map((item) => InventoryItem.fromJson(item)).toList();
      });
    } catch (error) {
      widget.onMessage('Inventory load failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.serverBase.isEmpty) return const EmptyState(message: 'Connect to a desktop in Settings first.');
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? _items
        : _items.where((item) {
            return [item.id, item.title, item.category, item.location, item.tags.join(' ')]
                .join(' ')
                .toLowerCase()
                .contains(query);
          }).toList();

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search inventory'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          for (final item in visible) InventoryCard(item: item, serverBase: widget.serverBase),
          if (!_loading && visible.isEmpty) const EmptyState(message: 'No inventory items found.'),
        ],
      ),
    );
  }
}

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key, required this.serverBase, required this.onMessage});
  final String serverBase;
  final ValueChanged<String> onMessage;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _picker = ImagePicker();
  final _title = TextEditingController();
  final _category = TextEditingController();
  final _size = TextEditingController();
  final _color = TextEditingController();
  final _condition = TextEditingController(text: 'Good');
  final _location = TextEditingController();
  final _tags = TextEditingController();
  final _notes = TextEditingController();
  Uint8List? _photoBytes;
  String _photoMime = 'image/jpeg';
  bool _saving = false;
  bool _classifying = false;

  @override
  void dispose() {
    for (final controller in [_title, _category, _size, _color, _condition, _location, _tags, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final image = await _picker.pickImage(source: source, imageQuality: 82, maxWidth: 1800);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoMime = image.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    });
  }

  Future<void> _save() async {
    if (widget.serverBase.isEmpty) {
      widget.onMessage('Connect to a desktop in Settings first.');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'title': _title.text,
        'category': _category.text,
        'size': _size.text,
        'color': _color.text,
        'condition': _condition.text,
        'location': _location.text,
        'tags': _tags.text,
        'notes': _notes.text,
        'photoData': _photoBytes == null ? [] : ['data:$_photoMime;base64,${base64Encode(_photoBytes!)}'],
      };
      final response = await http
          .post(
            Uri.parse('${widget.serverBase}/api/items'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(data['error'] ?? 'Save failed');
      _title.clear();
      _category.clear();
      _size.clear();
      _color.clear();
      _condition.text = 'Good';
      _location.clear();
      _tags.clear();
      _notes.clear();
      setState(() => _photoBytes = null);
      widget.onMessage('Item saved: ${data['item']?['id'] ?? ''}');
    } catch (error) {
      widget.onMessage('Could not save item: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _classifyPhoto() async {
    if (widget.serverBase.isEmpty) {
      widget.onMessage('Connect to a desktop in Settings first.');
      return;
    }
    if (_photoBytes == null) {
      widget.onMessage('Take or choose a photo first.');
      return;
    }

    setState(() => _classifying = true);
    try {
      final response = await http
          .post(
            Uri.parse('${widget.serverBase}/api/classify-photo'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'photoData': 'data:$_photoMime;base64,${base64Encode(_photoBytes!)}'}),
          )
          .timeout(const Duration(seconds: 35));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(data['error'] ?? 'AI suggestion failed');

      final suggestion = (data['suggestion'] as Map?)?.cast<String, dynamic>() ?? {};
      final tags = suggestion['tags'] is List ? (suggestion['tags'] as List).join(', ') : '${suggestion['tags'] ?? ''}';
      String suggestedText(String key) => '${suggestion[key] ?? ''}'.trim();
      if (suggestedText('title').isNotEmpty) _title.text = suggestedText('title');
      if (suggestedText('category').isNotEmpty) _category.text = suggestedText('category');
      if (suggestedText('size').isNotEmpty) _size.text = suggestedText('size');
      if (suggestedText('color').isNotEmpty) _color.text = suggestedText('color');
      if (suggestedText('condition').isNotEmpty) _condition.text = suggestedText('condition');
      _tags.text = tags.isEmpty ? _tags.text : tags;
      final notes = suggestedText('notes').isNotEmpty ? suggestedText('notes') : suggestedText('description');
      if (notes.isNotEmpty) _notes.text = notes;
      widget.onMessage('AI filled in the item details. Review them, then save.');
    } catch (error) {
      widget.onMessage('Could not read photo: $error');
    } finally {
      if (mounted) setState(() => _classifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ImagePickerPanel(photoBytes: _photoBytes, onCamera: () => _pickPhoto(ImageSource.camera), onGallery: () => _pickPhoto(ImageSource.gallery)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _classifying ? null : _classifyPhoto,
          icon: _classifying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
          label: Text(_classifying ? 'Reading photo...' : 'AI Suggest'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Item name')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _category, decoration: const InputDecoration(labelText: 'Category'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _size, decoration: const InputDecoration(labelText: 'Size / Model'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _color, decoration: const InputDecoration(labelText: 'Color / Finish'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _condition, decoration: const InputDecoration(labelText: 'Condition'))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location')),
        const SizedBox(height: 10),
        TextField(controller: _tags, decoration: const InputDecoration(labelText: 'Tags')),
        const SizedBox(height: 10),
        TextField(controller: _notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes')),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
          label: Text(_saving ? 'Saving...' : 'Save Item'),
        ),
      ],
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.serverBase, required this.onMessage});
  final String serverBase;
  final ValueChanged<String> onMessage;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _manualId = TextEditingController();

  @override
  void dispose() {
    _manualId.dispose();
    super.dispose();
  }

  Future<void> _scanAndUpdate(String status) async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage(title: 'Scan Item Label')),
    );
    if (value != null) await _updateStatus(_cleanItemCode(value), status);
  }

  Future<void> _updateStatus(String itemId, String status) async {
    if (widget.serverBase.isEmpty) {
      widget.onMessage('Connect to a desktop in Settings first.');
      return;
    }
    if (itemId.isEmpty) return;
    try {
      final response = await http
          .post(
            Uri.parse('${widget.serverBase}/api/items/${Uri.encodeComponent(itemId)}/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': status, 'note': 'Updated from mobile app'}),
          )
          .timeout(const Duration(seconds: 12));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(data['error'] ?? 'Update failed');
      widget.onMessage('${data['item']?['id'] ?? itemId} marked $status.');
      _manualId.clear();
    } catch (error) {
      widget.onMessage('Could not update item: $error');
    }
  }

  String _cleanItemCode(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri != null && uri.queryParameters['item'] != null) return uri.queryParameters['item']!;
    return value.trim().split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => _scanAndUpdate('Checked Out'),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan and Check Out'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _scanAndUpdate('Available'),
          icon: const Icon(Icons.assignment_return_outlined),
          label: const Text('Scan and Check In'),
        ),
        const SizedBox(height: 18),
        TextField(controller: _manualId, decoration: const InputDecoration(labelText: 'Or type item code')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FilledButton(onPressed: () => _updateStatus(_manualId.text, 'Checked Out'), child: const Text('Check Out'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton(onPressed: () => _updateStatus(_manualId.text, 'Available'), child: const Text('Check In'))),
        ]),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.serverBase,
    required this.serverController,
    required this.recentServers,
    required this.onSaveServer,
    required this.onScanQr,
    required this.onMessage,
    required this.friendlyServer,
  });

  final String serverBase;
  final TextEditingController serverController;
  final List<String> recentServers;
  final ValueChanged<String> onSaveServer;
  final VoidCallback onScanQr;
  final ValueChanged<String> onMessage;
  final String Function(String) friendlyServer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Image.asset('assets/vizventory-logo.png', height: 88, fit: BoxFit.contain),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: onScanQr, icon: const Icon(Icons.qr_code_scanner), label: const Text('Connect Camera Device')),
        const SizedBox(height: 12),
        TextField(controller: serverController, decoration: const InputDecoration(labelText: 'Desktop server', hintText: 'http://192.168.1.20:4174')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => onSaveServer(serverController.text), icon: const Icon(Icons.link), label: const Text('Save Server')),
        if (recentServers.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Remembered desktops', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final server in recentServers)
            ListTile(
              leading: const Icon(Icons.computer),
              title: Text(friendlyServer(server)),
              subtitle: Text(server),
              onTap: () => onSaveServer(server),
            ),
        ],
      ],
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key, required this.title});
  final String title;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _foundCode = false;
  void _handleDetect(BarcodeCapture capture) {
    if (_foundCode) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.trim().isEmpty) continue;
      _foundCode = true;
      Navigator.of(context).pop(value.trim());
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(children: [
        MobileScanner(onDetect: _handleDetect),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            color: Colors.black.withValues(alpha: 0.68),
            padding: const EdgeInsets.all(18),
            child: const Text('Point this device at the QR or barcode.', style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
          ),
        ),
      ]),
    );
  }
}

class InventoryCard extends StatelessWidget {
  const InventoryCard({super.key, required this.item, required this.serverBase});
  final InventoryItem item;
  final String serverBase;

  @override
  Widget build(BuildContext context) {
    final photo = item.photos.isNotEmpty ? '$serverBase${item.photos.first}' : '';
    return Card(
      child: ListTile(
        leading: photo.isEmpty
            ? const CircleAvatar(child: Icon(Icons.inventory_2_outlined))
            : ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(photo, width: 56, height: 56, fit: BoxFit.cover)),
        title: Text(item.title),
        subtitle: Text([item.id, item.category, item.location].where((part) => part.isNotEmpty).join(' • ')),
        trailing: Chip(label: Text(item.status)),
      ),
    );
  }
}

class ImagePickerPanel extends StatelessWidget {
  const ImagePickerPanel({super.key, required this.photoBytes, required this.onCamera, required this.onGallery});
  final Uint8List? photoBytes;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: 4 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
          child: photoBytes == null
              ? const Center(child: Icon(Icons.add_a_photo_outlined, size: 56, color: Colors.black38))
              : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(photoBytes!, fit: BoxFit.cover)),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: onCamera, icon: const Icon(Icons.photo_camera), label: const Text('Camera'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(onPressed: onGallery, icon: const Icon(Icons.photo_library), label: const Text('Photos'))),
      ]),
    ]);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
      );
}
