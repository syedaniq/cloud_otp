
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:otp/otp.dart';
import 'dart:async';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io' show Platform;


final supabase = Supabase.instance.client;
late List<String> otpUris;
late String loginUsername;
late String loginPassword;
bool needToLogin=true;
final SharedPreferencesAsync prefs = SharedPreferencesAsync();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bclaahfvyffqzoqwwegd.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJjbGFhaGZ2eWZmcXpvcXd3ZWdkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjQ5MTcyMjcsImV4cCI6MjA0MDQ5MzIyN30.wAmbOCF70IcnqVylOUq9FqSzv3_pXcc7uEgVi7_qTQk',
  );

  otpUris = (await prefs.getStringList("otpUris"))??[];
  try{
    String savedLoginusername = (await prefs.getString("loginUsername"))!;
    String savedLoginPassword = (await prefs.getString("loginPassword"))!;
    final response = await supabase.auth.signInWithPassword(
      email: savedLoginusername,
      password: savedLoginPassword,
    );
    if (response.user != null) {
      needToLogin = false;
    }
  }catch(e) {
    if (kDebugMode) {
      print(e);
    }
  }

  runApp(const MyApp());
}

bool _isValidOtpUri(String uri) {
  // Basic validation for OTP URI format
  RegExp otpUriRegex = RegExp(r'^otpauth:\/\/(totp|hotp)\/(.+)\?secret=([A-Z2-7]+)(&.+)?$');
  return otpUriRegex.hasMatch(uri);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    StatefulWidget home;
    if (needToLogin){
      home = const AuthPage();
    }else{
      home = const MainPage();
    }
    return MaterialApp(
      title: 'Cloud OTP',
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.light, // Light theme
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark, // Dark theme
        useMaterial3: true,
      ),
      themeMode: ThemeMode.light, // Use this to switch between dark and light modes
      home: home,
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isObscure = true;
  bool _isLoading = false;
  final _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (_isLogin) {
          var response = await supabase.auth.signInWithPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );
          String id = response.user!.id;
        //  success sign in
          dynamic tResponse;
          tResponse = await supabase
              .from('user_data')
              .select()
              .maybeSingle();
          // no data
          if (tResponse==null){
            await supabase
                .from('user_data')
                .insert({ 'user_id': id,'user_data': [] });
            otpUris= [];

          }else {
            if (tResponse['user_data'] == null) {
              await supabase
                  .from('user_data')
                  .update({'user_data': []})
                  .eq('user_id', id);
              otpUris= [];
            } else {
              otpUris = List.from(tResponse['user_data']);
            }
          }
          loginUsername = _emailController.text;
          loginPassword = _passwordController.text;

          await prefs.setString("loginUsername", loginUsername);
          await prefs.setString("loginPassword", loginPassword);
          await prefs.setStringList("otpUris", otpUris);

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainPage()),
          );
        }
         else {
          final response = await supabase.auth.signUp(
            email: _emailController.text,
            password: _passwordController.text,
          );

          if (response.user != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign up successful. You can now log in.')),
            );
            setState(() => _isLogin = true);
          }
        }
      } on AuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade300, Colors.purple.shade300],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock,
                            size: 80,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _isLogin ? 'Welcome Back' : 'Create Account',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) =>
                            value!.isEmpty ? 'Please enter your email' : null,
                            keyboardType: TextInputType.emailAddress,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isObscure ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isObscure = !_isObscure;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            obscureText: _isObscure,
                            validator: (value) =>
                            value!.isEmpty ? 'Please enter your password' : null,
                            onFieldSubmitted: (_) {
                              if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
                                _submitForm();
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : Text(_isLogin ? 'Login' : 'Sign Up'),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => setState(() => _isLogin = !_isLogin),
                            child: Text(
                              _isLogin
                                  ? 'Need an account? Sign Up'
                                  : 'Already have an account? Login',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


Future<void> logout(BuildContext context) async {
  await prefs.remove("loginUsername");
  await prefs.remove("loginPassword");
  supabase.auth.signOut();
  Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
  
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});


  
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {


  // final dynamic userData;

  int _selectedIndex = 0;

  late List<Widget> _widgetOptions;
  
  // _MainPageState({required this.userData});

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      ListViewPage(),
      SettingsPage(),
    ];
  }
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud OTP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              logout(context);
            },
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}


class OtpItem {
  final String label;
  final String secret;
  final String issuer;
  final int length;
  final int interval;
  final Algorithm algorithm;

  OtpItem({
    required this.label,
    required this.secret,
    required this.issuer,
    this.length = 6,
    this.interval = 30,
    this.algorithm = Algorithm.SHA1,
  });

  factory OtpItem.fromUri(String uri) {
    final parsedUri = Uri.parse(uri);
    final label = parsedUri.path.substring(1); // Remove leading '/'
    final secret = parsedUri.queryParameters['secret'] ?? '';
    final issuer = parsedUri.queryParameters['issuer'] ?? '';
    final length = int.tryParse(parsedUri.queryParameters['digits'] ?? '6') ?? 6;
    final interval = int.tryParse(parsedUri.queryParameters['period'] ?? '30') ?? 30;
    final algorithm = _parseAlgorithm(parsedUri.queryParameters['algorithm']);
    
    return OtpItem(
      label: label,
      secret: secret,
      issuer: issuer,
      length: length,
      interval: interval,
      algorithm: algorithm,
    );
  }

  static Algorithm _parseAlgorithm(String? algorithmStr) {
    switch (algorithmStr?.toUpperCase()) {
      case 'SHA256':
        return Algorithm.SHA256;
      case 'SHA512':
        return Algorithm.SHA512;
      default:
        return Algorithm.SHA1;
    }
  }
}

class QRCodeDialog extends StatelessWidget {
  final String uri;

  const QRCodeDialog({super.key, required this.uri});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.4,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: uri,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: uri));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URI copied to clipboard')),
                        );
                      },
                      child: const Text('Copy URI'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class ListViewPage extends StatefulWidget {
  ListViewPage({super.key});

  // late List<String> originalUris;
  final List<String> initialOtpUris = List.from(otpUris);

  @override
  _ListViewPageState createState() => _ListViewPageState();
}

class _ListViewPageState extends State<ListViewPage> {
  late List<OtpItem> otpItems;
  late List<String> currentOtps;
  late List<bool> _isExpanded;
  late List<double> _progress;
  late List<Timer> _timers;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  @override
  void didUpdateWidget(ListViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOtpUris != oldWidget.initialOtpUris) {
      initState();
    }
  }

void _initializeState() {
  try {
    // Create a new modifiable list from widget.otpUris
    // originalUris = List<String>.from(otpUris);
    otpItems = List<OtpItem>.from(otpUris.map((uri) => OtpItem.fromUri(uri)));
    
    // Use List.filled to create modifiable lists
    _isExpanded = List<bool>.filled(otpItems.length, false, growable: true);
    _progress = List<double>.filled(otpItems.length, 0.0, growable: true);
    _timers = List<Timer>.generate(otpItems.length, (_) => Timer(Duration.zero, () {}), growable: true);
    currentOtps = List<String>.filled(otpItems.length, '', growable: true);

    if (otpItems.isNotEmpty) {
      _generateAllOtps();
    }
  } catch (e) {
    print('Error in initState: $e');
    _setDefaultValues();
  }
}

void _setDefaultValues() {
  // Initialize modifiable lists
  // originalUris = [];
  otpItems = [];
  _isExpanded = [];
  _progress = [];
  _timers = [];
  currentOtps = [];
}

  @override
  void dispose() {
    for (var timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _resetAndStartTimer(int index) {
    if (index < 0 || index >= _timers.length) return;
    
    _timers[index].cancel();
    _progress[index] = 0.0;

    const updateInterval = Duration(milliseconds: 100);
    final totalDuration = Duration(seconds: otpItems[index].interval);
    var elapsed = Duration.zero;

    _timers[index] = Timer.periodic(updateInterval, (timer) {
      elapsed += updateInterval;
      if (mounted) {
        setState(() {
          _progress[index] = elapsed.inMilliseconds / totalDuration.inMilliseconds;
        });
      }

      if (elapsed >= totalDuration) {
        timer.cancel();
        _refreshOtp(index);
      }
    });
  }

  void _refreshOtp(int index) {
    if (index < 0 || index >= otpItems.length) return;
    
    setState(() {
      currentOtps[index] = _generateOtp(otpItems[index]);
      _resetAndStartTimer(index);
    });
  }

  void _generateAllOtps() {
    setState(() {
      for (int i = 0; i < otpItems.length; i++) {
        currentOtps[i] = _generateOtp(otpItems[i]);
        _resetAndStartTimer(i);
      }
    });
  }

  void _addOtp(String uri) {
    setState(() {
      try {
        otpUris.add(uri);
        prefs.setStringList('otpUris', otpUris);
        // originalUris.add(uri);
        final newOtpItem = OtpItem.fromUri(uri);
        otpItems.add(newOtpItem);
        _isExpanded.add(false);
        _progress.add(0.0);
        _timers.add(Timer(Duration.zero, () {}));
        currentOtps.add('');
        final newIndex = otpItems.length - 1;
        currentOtps[newIndex] = _generateOtp(newOtpItem);
        _resetAndStartTimer(newIndex);
      } catch (e) {
        print('Error adding OTP: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add OTP: $e')),
        );
      }
    });
  }

  String _generateOtp(OtpItem item) {
    try {
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      return OTP.generateTOTPCodeString(
        item.secret,
        currentTime,
        length: item.length,
        interval: item.interval,
        algorithm: item.algorithm,
        isGoogle: true,
      );
    } catch (e) {
      print('Error generating OTP: $e');
      return 'Error';
    }
  }

  void _copyOtp(int index) {
    if (index < 0 || index >= currentOtps.length) return;
    
    Clipboard.setData(ClipboardData(text: currentOtps[index]));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP copied to clipboard')),
    );
  }
  

void _exportOtp(BuildContext context, int index) {
  var singleOtpUri = otpUris[index];
  
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return QRCodeDialog(uri: singleOtpUri);
    },
  );
}

  void _deleteOtp(int index) {
    try {
      // Remove the OTP URI from the list
      otpUris.removeAt(index);
      // Remove the OTP item from the list
      otpItems.removeAt(index);
      // Remove the corresponding expansion state
      _isExpanded.removeAt(index);
      // Cancel and remove the timer
      _timers[index].cancel();
      _timers.removeAt(index);
      // Remove the progress indicator value
      _progress.removeAt(index);
      // Remove the current OTP value
      currentOtps.removeAt(index);
      // Update the stored URIs in SharedPreferences
      prefs.setStringList('otpUris', otpUris);
      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted successfully')),
      );
    } catch (e) {
      print('Error deleting OTP: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete OTP: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP List'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: otpItems.isEmpty
          ? const Center(child: Text('No OTPs added yet. Tap the + button to add one.'))
          : ListView.builder(
              itemCount: otpItems.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    title: Text(
                      otpItems[index].label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(otpItems[index].issuer),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.ios_share),
                          onPressed: () => _exportOtp(context, index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteOtp(index),
                        ),
                      ],
                    ),
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _isExpanded[index] = expanded;
                      });
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('OTP: ${currentOtps[index]}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Digits: ${otpItems[index].length}'),
                            Text('Interval: ${otpItems[index].interval}s'),
                            Text('Algorithm: ${otpItems[index].algorithm.toString().split('.').last}'),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: _progress[index],
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () => _copyOtp(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () => _refreshOtp(index),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.input),
            label: 'Manual Input',
            onTap: _manualInput,
          ),
          SpeedDialChild(
            child: const Icon(Icons.qr_code_scanner),
            label: 'QR Scanner',
            onTap: _qrScanner,
          ),
        ],
      ),
    );
  }

  void _manualInput() async {
    String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String secret = '';
        String label = '';
        String issuer = '';

        return AlertDialog(
          title: const Text('Manual Input'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Secret'),
                onChanged: (value) {
                  secret = value;
                },
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Label'),
                onChanged: (value) {
                  label = value;
                },
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Issuer (optional)'),
                onChanged: (value) {
                  issuer = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final uri = Uri(
                  scheme: 'otpauth',
                  host: 'totp',
                  path: label,
                  queryParameters: {
                    'secret': secret,
                    if (issuer.isNotEmpty) 'issuer': issuer,
                  },
                );
                Navigator.of(context).pop(uri.toString());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      _addOtp(result);
    }
  }

void _qrScanner() async {
  String? scannedData;
  if (kIsWeb){
    scannedData = await _webQRScanner();
  }else{
    if (Platform.isAndroid) {
      // Check for mobile platforms without using dart:io
      scannedData = await _mobileQRScanner();
    } else {
      // Web-specific implementation
      scannedData = await _webQRScanner();
    }
  }
  if (scannedData != null) {
    if (_isValidOtpUri(scannedData)) {
      _addOtp(scannedData);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP QR code')),
      );
    }
  }
}

Future<String?> _webQRScanner() async {
  String? string_result;
  // For web, we'll use file picker to select an image
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );

  if (result != null) {
    Uint8List fileBytes = result.files.first.bytes!;
    img.Image? image = img.decodeImage(fileBytes);

    if (image != null) {
      string_result = _processQRCodeImage(image);
    }
  }
  return string_result;
}

  String? _processQRCodeImage(img.Image image) {
    LuminanceSource source = RGBLuminanceSource(
        image.width,
        image.height,
        image
            .convert(numChannels: 4)
            .getBytes(order: img.ChannelOrder.abgr)
            .buffer
            .asInt32List());
    var bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));

    try {
      var result = QRCodeReader().decode(bitmap);
      return result.text;
    } catch (e) {
      print('Error decoding QR code: $e');
      return null;
    }
  }




  Future<String?> _mobileQRScanner() async {
    String? result;
    bool hasScanned = false;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Scan QR Code'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: MobileScanner(
            onDetect: (capture) {
              if (hasScanned) return; // Prevent multiple scans
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  hasScanned = true;
                  result = barcode.rawValue;
                  Navigator.of(context).pop(); // This should close the scanner page
                  return;
                }
              }
            },
          ),
        ),
      ),
    );

    // If we've reached this point and hasScanned is still false,
    // it means the user manually went back without scanning
    if (!hasScanned) {
      result = null;
    }

    return result;
  }

}



class SettingsPage extends StatelessWidget {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  SettingsPage({super.key});

  Future<void> _changePassword(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TextField(
            //   controller: _oldPasswordController,
            //   obscureText: true,
            //   decoration: const InputDecoration(labelText: 'Old Password'),
            // ),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try{
                if (_newPasswordController.text != _confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match')),
                  );
                  return;
                }
                await supabase.auth.updateUser(UserAttributes(
                    password: _newPasswordController.text
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed successfully')),
                );
              }catch(e){
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unexpected error: ${e.toString()}')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _pullData(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Pull Data'),
          content: const Text('This will overwrite the data in local storage. Are you sure you want to proceed?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Proceed'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Perform the pull data operation
      try {
        var response = await supabase
            .from('user_data')
            .select()
            .maybeSingle();

        if (response['user_data'] != null) {
          var userData = response['user_data'];
          // Use the userData as needed
          otpUris = List.from(userData);
          await prefs.setStringList("otpUris", otpUris);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data pulled successfully')),
          );
        }
      }catch (e){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pull data, maybe there is no data in cloud. Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _backupData(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Backup Data'),
          content: const Text('This will overwrite the data in web storage. Are you sure you want to proceed?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Proceed'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Perform the backup data operation
      var userData = List.from(otpUris); // Populate this with the user data to be backed up
      try {
        String id = supabase.auth.currentUser!.id;
        await supabase
            .from('user_data')
            .update({ 'user_data': userData })
            .eq('user_id', id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data backed up successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to backup data')),
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Implement account deletion here
        // For now, just return to the login page
        logout(context);
        // Navigator.of(context).pushAndRemoveUntil(
        //   MaterialPageRoute(builder: (_) => const AuthPage()),
        //   (route) => false,
        // );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.lock),
          title: const Text('Change Password'),
          onTap: () => _changePassword(context),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_download),
          title: const Text('Pull Data'),
          onTap: () => _pullData(context),
        ),
        ListTile(
          leading: const Icon(Icons.backup),
          title: const Text('Backup Data'),
          onTap: () => _backupData(context),
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
          onTap: () => _deleteAccount(context),
        ),
      ],
    );
  }
}