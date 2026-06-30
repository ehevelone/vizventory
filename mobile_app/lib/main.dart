import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const VizventoryApp());

const hostedVizventoryUrl = String.fromEnvironment(
  'VIZVENTORY_SITE_URL',
  defaultValue: 'https://vizventory.netlify.app',
);

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
        ).copyWith(surface: linen),
        scaffoldBackgroundColor: linen,
        appBarTheme: const AppBarTheme(
          backgroundColor: ink,
          foregroundColor: Colors.white,
        ),
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
    this.subcategory = '',
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
  final String subcategory;
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
      status: json['status']?.toString() == 'Donated'
          ? 'Checked Out'
          : json['status']?.toString() ?? 'Available',
      category: json['category']?.toString() ?? '',
      subcategory: json['subcategory']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      condition: json['condition']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      tags: (json['tags'] as List? ?? []).map((tag) => tag.toString()).toList(),
      photos: (json['photos'] as List? ?? [])
          .map((photo) => photo.toString())
          .toList(),
    );
  }
}

class InventoryCategory {
  const InventoryCategory({required this.name, required this.subcategories});

  final String name;
  final List<String> subcategories;

  factory InventoryCategory.fromJson(Map<String, dynamic> json) {
    return InventoryCategory(
      name: json['name']?.toString() ?? '',
      subcategories: (json['subcategories'] as List? ?? [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }
}

const fallbackCategories = <InventoryCategory>[
  InventoryCategory(
    name: 'Clothing',
    subcategories: [
      'Tops',
      'Bottoms',
      'Dresses',
      'Outerwear',
      'Shoes',
      'Accessories',
      'Bags',
      'Jewelry',
      'Kids',
      'Other Clothing',
    ],
  ),
  InventoryCategory(
    name: 'Equipment',
    subcategories: [
      'Office Equipment',
      'Kitchen Equipment',
      'Medical Equipment',
      'Outdoor Equipment',
      'Other Equipment',
    ],
  ),
  InventoryCategory(
    name: 'Tool',
    subcategories: [
      'Power Tools',
      'Hand Tools',
      'Garden Tools',
      'Measuring Tools',
      'Other Tools',
    ],
  ),
  InventoryCategory(
    name: 'Electronics',
    subcategories: [
      'Computer',
      'Phone',
      'Tablet',
      'Audio',
      'Camera',
      'Other Electronics',
    ],
  ),
  InventoryCategory(
    name: 'Furniture',
    subcategories: [
      'Desk',
      'Chair',
      'Table',
      'Shelf',
      'Storage',
      'Other Furniture',
    ],
  ),
  InventoryCategory(
    name: 'Supply',
    subcategories: [
      'Office Supplies',
      'Cleaning Supplies',
      'Food Supplies',
      'Medical Supplies',
      'Other Supplies',
    ],
  ),
  InventoryCategory(
    name: 'Document',
    subcategories: [
      'Record',
      'Manual',
      'Receipt',
      'Certificate',
      'Other Document',
    ],
  ),
  InventoryCategory(
    name: 'Artwork',
    subcategories: ['Painting', 'Print', 'Sculpture', 'Decor', 'Other Artwork'],
  ),
  InventoryCategory(
    name: 'Part',
    subcategories: [
      'Replacement Part',
      'Hardware',
      'Cable',
      'Accessory',
      'Other Part',
    ],
  ),
  InventoryCategory(
    name: 'Container',
    subcategories: ['Box', 'Bin', 'Bag', 'Crate', 'Other Container'],
  ),
  InventoryCategory(
    name: 'Miscellaneous',
    subcategories: ['Unsorted', 'Unknown', 'Oddball', 'Mixed Lot'],
  ),
  InventoryCategory(name: 'Other', subcategories: ['Miscellaneous']),
];

String friendlyApiError(Object error) {
  if (error is TimeoutException) {
    return 'The server took too long to answer. Check the connection, then pull down to retry.';
  }
  final message = error.toString();
  if (message.contains('SocketException') || message.contains('ClientException')) {
    return 'The server connection dropped. Make sure you are online, then try again.';
  }
  return message.replaceFirst('Exception: ', '');
}

class VizventoryHome extends StatefulWidget {
  const VizventoryHome({super.key});

  @override
  State<VizventoryHome> createState() => _VizventoryHomeState();
}

class _VizventoryHomeState extends State<VizventoryHome> {
  static const _serverKey = 'vizventoryServerBase';
  static const _recentDevicesKey = 'vizventoryRecentDesktops';
  static const _authTokenKey = 'vizventoryAccessToken';
  static const _authRefreshKey = 'vizventoryRefreshToken';
  static const _authOrgKey = 'vizventoryOrganizationId';
  static const _authEmailKey = 'vizventoryEmail';
  static const _rememberEmailKey = 'vizventoryRememberEmail';
  static const _rememberPasswordKey = 'vizventoryRememberPassword';
  static const _securePasswordKey = 'vizventorySavedPassword';

  final _secureStorage = const FlutterSecureStorage();

  final _serverController = TextEditingController();
  int _tabIndex = 0;
  String _serverBase = hostedVizventoryUrl;
  String _message = 'Sign in to continue.';
  String _accessToken = '';
  String _refreshToken = '';
  String _organizationId = '';
  String _email = '';
  String _rememberedEmail = '';
  String _rememberedPassword = '';
  bool _rememberPassword = false;
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
    final savedServer = prefs.getString(_serverKey) ?? '';
    final server = savedServer.startsWith('https://') && !savedServer.contains('192.168.') ? savedServer : hostedVizventoryUrl;
    final recent = (prefs.getStringList(_recentDevicesKey) ?? []).where((item) => item.startsWith('https://') && !item.contains('192.168.')).toList();
    final accessToken = prefs.getString(_authTokenKey) ?? '';
    final refreshToken = prefs.getString(_authRefreshKey) ?? '';
    final organizationId = prefs.getString(_authOrgKey) ?? '';
    final email = prefs.getString(_authEmailKey) ?? '';
    final rememberedEmail = prefs.getString(_rememberEmailKey) ?? email;
    final rememberPassword = prefs.getBool(_rememberPasswordKey) ?? false;
    final rememberedPassword = rememberPassword
        ? await _secureStorage.read(key: _securePasswordKey) ?? ''
        : '';
    if (!mounted) return;
    setState(() {
      _serverBase = server;
      _serverController.text = server;
      _recentServers = recent;
      _accessToken = accessToken;
      _refreshToken = refreshToken;
      _organizationId = organizationId;
      _email = email;
      _rememberedEmail = rememberedEmail;
      _rememberedPassword = rememberedPassword;
      _rememberPassword = rememberPassword;
      _message = accessToken.isEmpty ? 'Using hosted Vizventory. Sign in to continue.' : 'Signed in as $email.';
    });
  }

  Future<void> _saveServer(String serverBase) async {
    final normalized = _normalizeServer(serverBase);
    if (normalized.isEmpty) return;
    final recent = [
      normalized,
      ..._recentServers.where((item) => item != normalized),
    ].take(5).toList();
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

  Map<String, String> get _authHeaders {
    final headers = <String, String>{};
    if (_accessToken.isNotEmpty) headers['Authorization'] = 'Bearer $_accessToken';
    if (_organizationId.isNotEmpty) headers['X-Vizventory-Organization-Id'] = _organizationId;
    return headers;
  }

  Future<void> _authenticate({
    required String email,
    required String password,
    required bool rememberEmail,
    required bool rememberPassword,
  }) async {
    final normalized = _serverBase.isEmpty ? hostedVizventoryUrl : _serverBase;
    final response = await http
        .post(
          Uri.parse('$normalized/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error'] ?? 'Sign in failed');
    }
    final token = data['accessToken']?.toString() ?? '';
    if (token.isEmpty) throw Exception('Sign in failed');

    final recent = [
      normalized,
      ..._recentServers.where((item) => item != normalized),
    ].take(5).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, normalized);
    await prefs.setStringList(_recentDevicesKey, recent);
    await prefs.setString(_authTokenKey, token);
    await prefs.setString(_authRefreshKey, data['refreshToken']?.toString() ?? '');
    await prefs.setString(_authOrgKey, data['organizationId']?.toString() ?? '');
    final signedInEmail = data['user']?['email']?.toString() ?? email;
    await prefs.setString(_authEmailKey, signedInEmail);
    if (rememberEmail) {
      await prefs.setString(_rememberEmailKey, signedInEmail);
    } else {
      await prefs.remove(_rememberEmailKey);
    }
    await prefs.setBool(_rememberPasswordKey, rememberPassword);
    if (rememberPassword) {
      await _secureStorage.write(key: _securePasswordKey, value: password);
    } else {
      await _secureStorage.delete(key: _securePasswordKey);
    }
    if (!mounted) return;
    setState(() {
      _serverBase = normalized;
      _serverController.text = normalized;
      _recentServers = recent;
      _accessToken = token;
      _refreshToken = data['refreshToken']?.toString() ?? '';
      _organizationId = data['organizationId']?.toString() ?? '';
      _email = signedInEmail;
      _rememberedEmail = rememberEmail ? signedInEmail : '';
      _rememberedPassword = rememberPassword ? password : '';
      _rememberPassword = rememberPassword;
      _message = 'Signed in as $_email.';
      _tabIndex = 0;
    });
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_authRefreshKey);
    await prefs.remove(_authOrgKey);
    await prefs.remove(_authEmailKey);
    if (!mounted) return;
    setState(() {
      _accessToken = '';
      _refreshToken = '';
      _organizationId = '';
      _email = '';
      _message = 'Signed out.';
      _tabIndex = 0;
    });
  }

  Future<void> _scanDesktopQr() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScannerPage(title: 'Scan Desktop QR'),
      ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _normalizeServer(String value) {
    var server = value.trim();
    if (server.isEmpty) return '';
    if (!server.startsWith('http://') && !server.startsWith('https://'))
      server = 'http://$server';
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
    final signedIn = _accessToken.isNotEmpty;
    final pages = [
      InventoryScreen(serverBase: _serverBase, authHeaders: _authHeaders, onMessage: _showMessage),
      AddItemScreen(serverBase: _serverBase, authHeaders: _authHeaders, onMessage: _showMessage),
      ScanScreen(serverBase: _serverBase, authHeaders: _authHeaders, onMessage: _showMessage),
      SettingsScreen(
        serverBase: _serverBase,
        serverController: _serverController,
        recentServers: _recentServers,
        email: _email,
        onSaveServer: _saveServer,
        onScanQr: _scanDesktopQr,
        onSignOut: _signOut,
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
              color: connected
                  ? const Color(0xFFE8F1EA)
                  : const Color(0xFFFFF4D7),
              child: ListTile(
                dense: true,
                leading: Icon(
                  connected ? Icons.check_circle : Icons.info_outline,
                ),
                title: Text(_message),
              ),
            ),
          Expanded(
            child: signedIn
                ? pages[_tabIndex]
                : AuthScreen(
                    initialEmail: _rememberedEmail,
                    initialPassword: _rememberedPassword,
                    initialRememberPassword: _rememberPassword,
                    onAuthenticate: _authenticate,
                  ),
          ),
        ],
      ),
      bottomNavigationBar: signedIn
          ? NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (index) => setState(() => _tabIndex = index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
                NavigationDestination(icon: Icon(Icons.add_a_photo_outlined), label: 'Add'),
                NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
              ],
            )
          : null,
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.initialEmail,
    required this.initialPassword,
    required this.initialRememberPassword,
    required this.onAuthenticate,
  });

  final String initialEmail;
  final String initialPassword;
  final bool initialRememberPassword;
  final Future<void> Function({
    required String email,
    required String password,
    required bool rememberEmail,
    required bool rememberPassword,
  }) onAuthenticate;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _rememberEmail = true;
  bool _rememberPassword = false;
  bool _busy = false;
  String _message = 'Create your account on the Vizventory website, then sign in here.';

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail;
    _password.text = widget.initialPassword;
    _rememberPassword = widget.initialRememberPassword;
  }

  @override
  void didUpdateWidget(covariant AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_email.text.isEmpty && widget.initialEmail.isNotEmpty) {
      _email.text = widget.initialEmail;
    }
    if (_password.text.isEmpty && widget.initialPassword.isNotEmpty) {
      _password.text = widget.initialPassword;
    }
    if (widget.initialRememberPassword != oldWidget.initialRememberPassword) {
      _rememberPassword = widget.initialRememberPassword;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = 'Signing in...';
    });
    try {
      await widget.onAuthenticate(
        email: _email.text,
        password: _password.text,
        rememberEmail: _rememberEmail,
        rememberPassword: _rememberPassword,
      );
    } catch (error) {
      if (mounted) setState(() => _message = friendlyApiError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Image.asset('assets/vizventory-logo.png', height: 96, fit: BoxFit.contain),
        const SizedBox(height: 16),
        Text('Sign in to Vizventory', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(_message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 10),
        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
        CheckboxListTile(
          value: _rememberEmail,
          onChanged: _busy ? null : (value) => setState(() => _rememberEmail = value ?? true),
          title: const Text('Remember my email on this device'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: _rememberPassword,
          onChanged: _busy ? null : (value) => setState(() => _rememberPassword = value ?? false),
          title: const Text('Remember my password securely'),
          subtitle: const Text('Saved in this phone\'s secure storage.'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
          label: Text(_busy ? 'Please wait...' : 'Sign In'),
        ),
        const SizedBox(height: 10),
        const Text('Need an account? Register on the Vizventory website, then come back and sign in here.'),
      ],
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.serverBase,
    required this.authHeaders,
    required this.onMessage,
  });
  final String serverBase;
  final Map<String, String> authHeaders;
  final ValueChanged<String> onMessage;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  List<InventoryItem> _items = [];
  bool _loading = false;
  String _loadError = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didUpdateWidget(covariant InventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverBase != widget.serverBase || oldWidget.authHeaders['Authorization'] != widget.authHeaders['Authorization']) _loadItems();
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
      final response = await http
          .get(Uri.parse('${widget.serverBase}/api/items'), headers: widget.authHeaders)
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200)
        throw Exception(data['error'] ?? 'Could not load inventory');
      setState(() {
        _items = (data['items'] as List? ?? [])
            .map((item) => InventoryItem.fromJson(item))
            .toList();
        _loadError = '';
      });
    } catch (error) {
      final message = friendlyApiError(error);
      setState(() => _loadError = message);
      widget.onMessage('Inventory load failed: $message');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.serverBase.isEmpty)
      return const EmptyState(
        message: 'Connect to a desktop in Settings first.',
      );
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? _items
        : _items.where((item) {
            return [
              item.id,
              item.title,
              item.category,
              item.subcategory,
              item.location,
              item.tags.join(' '),
            ].join(' ').toLowerCase().contains(query);
          }).toList();

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search inventory',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          for (final item in visible)
            InventoryCard(item: item, serverBase: widget.serverBase),
          if (!_loading && _loadError.isNotEmpty)
            EmptyState(
              message:
                  'Could not load inventory from ${widget.serverBase}. Check Settings, then pull down to retry.',
            ),
          if (!_loading && _loadError.isEmpty && visible.isEmpty)
            EmptyState(
              message: query.isEmpty
                  ? 'No inventory yet. Tap Add to take a picture and create your first item.'
                  : 'No matching inventory found.',
            ),
        ],
      ),
    );
  }
}

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({
    super.key,
    required this.serverBase,
    required this.authHeaders,
    required this.onMessage,
  });
  final String serverBase;
  final Map<String, String> authHeaders;
  final ValueChanged<String> onMessage;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _picker = ImagePicker();
  final _title = TextEditingController();
  final _category = TextEditingController();
  final _subcategory = TextEditingController();
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
  List<InventoryCategory> _categories = fallbackCategories;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void didUpdateWidget(covariant AddItemScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverBase != widget.serverBase || oldWidget.authHeaders['Authorization'] != widget.authHeaders['Authorization']) _loadCategories();
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _category,
      _subcategory,
      _size,
      _color,
      _condition,
      _location,
      _tags,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (widget.serverBase.isEmpty) {
      if (mounted) setState(() => _categories = fallbackCategories);
      return;
    }

    try {
      final response = await http
          .get(Uri.parse('${widget.serverBase}/api/categories'), headers: widget.authHeaders)
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200)
        throw Exception(data['error'] ?? 'Could not load categories');
      final loaded = (data['categories'] as List? ?? [])
          .map(
            (item) => InventoryCategory.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .where((item) => item.name.isNotEmpty)
          .toList();
      if (mounted && loaded.isNotEmpty) setState(() => _categories = loaded);
    } catch (_) {
      if (mounted) setState(() => _categories = fallbackCategories);
    }
  }

  List<String> get _categoryOptions {
    final names = _categories
        .map((item) => item.name)
        .where((item) => item.isNotEmpty)
        .toList();
    if (_category.text.isNotEmpty && !names.contains(_category.text))
      names.add(_category.text);
    return names;
  }

  List<String> get _subcategoryOptions {
    final selected = _category.text.trim();
    final match = _categories
        .where((item) => item.name.toLowerCase() == selected.toLowerCase())
        .toList();
    final names = match.isEmpty ? <String>[] : [...match.first.subcategories];
    if (_subcategory.text.isNotEmpty && !names.contains(_subcategory.text))
      names.add(_subcategory.text);
    return names;
  }

  void _setCategory(String? value) {
    setState(() {
      final selected = value ?? '';
      final match = _categories
          .where((item) => item.name.toLowerCase() == selected.toLowerCase())
          .toList();
      final allowedSubcategories = match.isEmpty
          ? <String>[]
          : match.first.subcategories;
      _category.text = selected;
      if (!allowedSubcategories.contains(_subcategory.text))
        _subcategory.clear();
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoMime = image.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
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
        'subcategory': _subcategory.text,
        'size': _size.text,
        'color': _color.text,
        'condition': _condition.text,
        'location': _location.text,
        'tags': _tags.text,
        'notes': _notes.text,
        'photoData': _photoBytes == null
            ? []
            : ['data:$_photoMime;base64,${base64Encode(_photoBytes!)}'],
      };
      final response = await http
          .post(
            Uri.parse('${widget.serverBase}/api/items'),
            headers: {'Content-Type': 'application/json', ...widget.authHeaders},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw Exception(data['error'] ?? 'Save failed');
      _title.clear();
      _category.clear();
      _subcategory.clear();
      _size.clear();
      _color.clear();
      _condition.text = 'Good';
      _location.clear();
      _tags.clear();
      _notes.clear();
      setState(() => _photoBytes = null);
      widget.onMessage('Item saved: ${data['item']?['id'] ?? ''}');
    } catch (error) {
      widget.onMessage('Could not save item: ${friendlyApiError(error)}');
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
            headers: {'Content-Type': 'application/json', ...widget.authHeaders},
            body: jsonEncode({
              'photoData':
                  'data:$_photoMime;base64,${base64Encode(_photoBytes!)}',
            }),
          )
          .timeout(const Duration(seconds: 60));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw Exception(data['error'] ?? 'AI suggestion failed');

      final suggestion =
          (data['suggestion'] as Map?)?.cast<String, dynamic>() ?? {};
      final tags = suggestion['tags'] is List
          ? (suggestion['tags'] as List).join(', ')
          : '${suggestion['tags'] ?? ''}';
      String suggestedText(String key) => '${suggestion[key] ?? ''}'.trim();
      if (suggestedText('title').isNotEmpty)
        _title.text = suggestedText('title');
      if (suggestedText('category').isNotEmpty)
        _category.text = suggestedText('category');
      if (suggestedText('subcategory').isNotEmpty)
        _subcategory.text = suggestedText('subcategory');
      if (suggestedText('size').isNotEmpty) _size.text = suggestedText('size');
      if (suggestedText('color').isNotEmpty)
        _color.text = suggestedText('color');
      if (suggestedText('condition').isNotEmpty)
        _condition.text = suggestedText('condition');
      _tags.text = tags.isEmpty ? _tags.text : tags;
      final notes = suggestedText('notes').isNotEmpty
          ? suggestedText('notes')
          : suggestedText('description');
      if (notes.isNotEmpty) _notes.text = notes;
      if (mounted) setState(() {});
      widget.onMessage(
        'AI filled in the item details. Review them, then save.',
      );
    } catch (error) {
      widget.onMessage('Could not read photo: ${friendlyApiError(error)}');
    } finally {
      if (mounted) setState(() => _classifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ImagePickerPanel(
          photoBytes: _photoBytes,
          onCamera: () => _pickPhoto(ImageSource.camera),
          onGallery: () => _pickPhoto(ImageSource.gallery),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _classifying ? null : _classifyPhoto,
          icon: _classifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_classifying ? 'Reading photo...' : 'AI Suggest'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Item name'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _category.text.isEmpty ? null : _category.text,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categoryOptions
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: _setCategory,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _subcategory.text.isEmpty ? null : _subcategory.text,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Subcategory'),
                items: _subcategoryOptions
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: _subcategoryOptions.isEmpty
                    ? null
                    : (value) =>
                          setState(() => _subcategory.text = value ?? ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _size,
          decoration: const InputDecoration(labelText: 'Size / Model'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _color,
                decoration: const InputDecoration(labelText: 'Color / Finish'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _condition,
                decoration: const InputDecoration(labelText: 'Condition'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _location,
          decoration: const InputDecoration(labelText: 'Location'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _tags,
          decoration: const InputDecoration(labelText: 'Tags'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_saving ? 'Saving...' : 'Save Item'),
        ),
      ],
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.serverBase,
    required this.authHeaders,
    required this.onMessage,
  });
  final String serverBase;
  final Map<String, String> authHeaders;
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
      MaterialPageRoute(
        builder: (_) => const QrScannerPage(title: 'Scan Item Label'),
      ),
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
            Uri.parse(
              '${widget.serverBase}/api/items/${Uri.encodeComponent(itemId)}/status',
            ),
            headers: {'Content-Type': 'application/json', ...widget.authHeaders},
            body: jsonEncode({
              'status': status,
              'note': 'Updated from mobile app',
            }),
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw Exception(data['error'] ?? 'Update failed');
      widget.onMessage('${data['item']?['id'] ?? itemId} marked $status.');
      _manualId.clear();
    } catch (error) {
      widget.onMessage('Could not update item: ${friendlyApiError(error)}');
    }
  }

  String _cleanItemCode(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri != null && uri.queryParameters['item'] != null)
      return uri.queryParameters['item']!;
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
        TextField(
          controller: _manualId,
          decoration: const InputDecoration(labelText: 'Or type item code'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => _updateStatus(_manualId.text, 'Checked Out'),
                child: const Text('Check Out'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _updateStatus(_manualId.text, 'Available'),
                child: const Text('Check In'),
              ),
            ),
          ],
        ),
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
    required this.email,
    required this.onSaveServer,
    required this.onScanQr,
    required this.onSignOut,
    required this.onMessage,
    required this.friendlyServer,
  });

  final String serverBase;
  final TextEditingController serverController;
  final List<String> recentServers;
  final String email;
  final ValueChanged<String> onSaveServer;
  final VoidCallback onScanQr;
  final VoidCallback onSignOut;
  final ValueChanged<String> onMessage;
  final String Function(String) friendlyServer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Image.asset(
          'assets/vizventory-logo.png',
          height: 88,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 16),
        if (email.isNotEmpty) ...[
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Signed in'),
            subtitle: Text(email),
          ),
          OutlinedButton.icon(onPressed: onSignOut, icon: const Icon(Icons.logout), label: const Text('Sign Out')),
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          onPressed: onScanQr,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Connect Camera Device'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: serverController,
          decoration: const InputDecoration(
            labelText: 'Hosted site',
            hintText: 'https://vizventory.netlify.app',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => onSaveServer(serverController.text),
          icon: const Icon(Icons.link),
          label: const Text('Save Hosted Site'),
        ),
        if (recentServers.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Remembered hosted sites',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.68),
              padding: const EdgeInsets.all(18),
              child: const Text(
                'Point this device at the QR or barcode.',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryCard extends StatelessWidget {
  const InventoryCard({
    super.key,
    required this.item,
    required this.serverBase,
  });
  final InventoryItem item;
  final String serverBase;

  @override
  Widget build(BuildContext context) {
    final firstPhoto = item.photos.isNotEmpty ? item.photos.first : '';
    final photo = firstPhoto.startsWith('http')
        ? firstPhoto
        : firstPhoto.isEmpty
        ? ''
        : '$serverBase$firstPhoto';
    return Card(
      child: ListTile(
        leading: photo.isEmpty
            ? const CircleAvatar(child: Icon(Icons.inventory_2_outlined))
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  photo,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
        title: Text(item.title),
        subtitle: Text(
          [
            item.id,
            item.category,
            item.subcategory,
            item.location,
          ].where((part) => part.isNotEmpty).join(' | '),
        ),
        trailing: Chip(label: Text(item.status)),
      ),
    );
  }
}

class ImagePickerPanel extends StatelessWidget {
  const ImagePickerPanel({
    super.key,
    required this.photoBytes,
    required this.onCamera,
    required this.onGallery,
  });
  final Uint8List? photoBytes;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: photoBytes == null
                ? const Center(
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      size: 56,
                      color: Colors.black38,
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(photoBytes!, fit: BoxFit.cover),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Photos'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
  );
}
