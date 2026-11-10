import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClipwaveApp());
}

// ================= THEME CONSTANTS =================
const Color kInk = Color(0xFF1B1B3A);
const Color kAccentPink = Color(0xFFFF4F93);
const Color kYellow = Color(0xFFFFD93D);
const Color kSkyBlue = Color(0xFFBDE7FF);
const Color kBgCream = Color(0xFFFFF8EE);
const Color kCardWhite = Color(0xFFFFFFFF);
const Color kGreen = Color(0xFF00A859);
const Color kGreenDark = Color(0xFF008F4C);

class ClipwaveApp extends StatelessWidget {
  const ClipwaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clipwave',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kBgCream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccentPink,
          primary: kAccentPink,
          secondary: kYellow,
        ),
        textTheme: GoogleFonts.mPlusRounded1cTextTheme(),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  
  // Default to the live Cloudflare Tunnel URL, but user can customize in settings
  String _apiBaseUrl = 'https://pharmacology-frederick-henry-partnership.trycloudflare.com';

  bool _isLoading = false;
  double _loadProgress = 0.2;
  String _loadingStatusMsg = 'Fetching video info...';
  Timer? _progressTimer;

  Map<String, dynamic>? _videoData;
  String? _errorMessage;

  String _selectedQualityCode = '720p';
  String _selectedQualityLabel = 'MP4 720';

  bool _isDownloading = false;
  double _downloadPercent = 0.0;
  String _downloadNotice = '';

  late AnimationController _radarController;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Auto-detect clipboard on app startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForVideoUrl();
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _bounceController.dispose();
    _progressTimer?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _checkClipboardForVideoUrl() async {
    try {
      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        String text = data.text!.trim();
        if (_isSupportedUrl(text) && _urlController.text.isEmpty) {
          setState(() {
            _urlController.text = text;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: kInk,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: kYellow, width: 2),
                ),
                content: Row(
                  children: [
                    const Text('📋 ', style: TextStyle(fontSize: 18)),
                    Expanded(
                      child: Text(
                        'Found video link in clipboard!',
                        style: GoogleFonts.mPlusRounded1c(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      }
    } catch (_) {}
  }

  bool _isSupportedUrl(String url) {
    return url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('tiktok.com') ||
        url.contains('instagram.com') ||
        url.contains('twitter.com') ||
        url.contains('x.com') ||
        url.contains('facebook.com') ||
        url.contains('fb.watch');
  }

  Future<void> _fetchVideoInfo() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _errorMessage = 'Please paste a valid video link!';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _videoData = null;
      _loadProgress = 0.2;
      _loadingStatusMsg = 'Connecting to server...';
    });

    // Realistic progress animation steps matching web
    int step = 0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) return;
      step++;
      setState(() {
        if (_loadProgress < 0.85) {
          _loadProgress += 0.12;
          if (_loadProgress > 0.85) _loadProgress = 0.85;
          if (step == 2) _loadingStatusMsg = 'Extracting video streams...';
          if (step == 4) _loadingStatusMsg = 'Preparing HD formats...';
        }
      });
    });

    try {
      final endpoint = Uri.parse('$_apiBaseUrl/api/info');
      final res = await http.post(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': rawUrl}),
      ).timeout(const Duration(seconds: 35));

      _progressTimer?.cancel();

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _loadProgress = 1.0;
          _loadingStatusMsg = 'Video ready!';
        });

        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) {
          setState(() {
            _isLoading = false;
            _videoData = data;
          });
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['error'] ?? 'Server error ${res.statusCode}');
      }
    } catch (e) {
      _progressTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _startDownload() async {
    if (_videoData == null) return;
    final targetUrl = _videoData!['clean_url'] ?? _urlController.text.trim();
    final downloadUrl =
        '$_apiBaseUrl/api/download?url=${Uri.encodeComponent(targetUrl)}&quality=$_selectedQualityCode';

    setState(() {
      _isDownloading = true;
      _downloadPercent = 0.15;
      _downloadNotice = 'Preparing $_selectedQualityLabel on server...';
    });

    try {
      // Stream file download
      final req = http.Request('GET', Uri.parse(downloadUrl));
      final streamedResponse = await req.send().timeout(const Duration(seconds: 120));

      if (streamedResponse.statusCode != 200) {
        throw Exception('Download failed with status ${streamedResponse.statusCode}');
      }

      final contentLength = streamedResponse.contentLength ?? 1;
      List<int> bytes = [];

      streamedResponse.stream.listen(
        (chunk) {
          bytes.addAll(chunk);
          if (mounted && contentLength > 0) {
            setState(() {
              _downloadPercent = (bytes.length / contentLength).clamp(0.0, 0.99);
              _downloadNotice =
                  'Downloading... ${(_downloadPercent * 100).toInt()}% (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB)';
            });
          }
        },
        onDone: () async {
          setState(() {
            _downloadPercent = 1.0;
            _downloadNotice = 'Saving file to device...';
          });

          // Save file to device
          String ext = _selectedQualityCode == 'audio' ? '.mp3' : (_selectedQualityCode == 'm4a' ? '.m4a' : '.mp4');
          String cleanTitle = (_videoData!['title'] ?? 'video').replaceAll(RegExp(r'[\\/*?:"<>|]'), '');
          if (cleanTitle.length > 50) cleanTitle = cleanTitle.substring(0, 50);

          Directory? dir;
          if (kIsWeb) {
            // Web platform doesn't need file system
          } else if (Platform.isAndroid || Platform.isIOS) {
            dir = await getApplicationDocumentsDirectory();
          } else {
            dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
          }

          if (dir != null) {
            final filePath = '${dir.path}/$cleanTitle$ext';
            final file = File(filePath);
            await file.writeAsBytes(bytes);

            setState(() {
              _isDownloading = false;
            });

            if (mounted) {
              _showDownloadSuccessDialog(filePath, cleanTitle + ext);
            }
          }
        },
        onError: (err) {
          setState(() {
            _isDownloading = false;
            _errorMessage = 'Download error: $err';
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download error: $e';
        });
      }
    }
  }

  void _showDownloadSuccessDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: kInk, width: 3.5),
        ),
        title: Row(
          children: [
            const Text('🎉 ', style: TextStyle(fontSize: 26)),
            Expanded(
              child: Text(
                'Download Complete!',
                style: GoogleFonts.delaGothicOne(
                  fontSize: 18,
                  color: kInk,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              'Saved to:\n$filePath',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kYellow,
              foregroundColor: kInk,
              elevation: 0,
              side: const BorderSide(color: kInk, width: 2.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              // ignore: deprecated_member_use
              Share.shareXFiles([XFile(filePath)], text: 'Downloaded with Clipwave');
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share Video', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800, color: kInk)),
          ),
        ],
      ),
    );
  }

  void _showQualityPicker() {
    final options = [
      {'code': '1080p', 'label': 'MP4 1080', 'sub': '1080p Full HD (Crisp)'},
      {'code': '720p', 'label': 'MP4 720', 'sub': '720p HD (Recommended)'},
      {'code': '480p', 'label': 'MP4 480', 'sub': '480p SD (Data Saver)'},
      {'code': '360p', 'label': 'MP4 360', 'sub': '360p Mobile'},
      {'code': 'audio', 'label': 'Audio MP3', 'sub': 'High Quality 192kbps MP3'},
      {'code': 'm4a', 'label': 'Audio M4A', 'sub': '128kbps AAC Audio'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: kInk, width: 3.5),
            left: BorderSide(color: kInk, width: 3.5),
            right: BorderSide(color: kInk, width: 3.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Quality',
                  style: GoogleFonts.delaGothicOne(fontSize: 18, color: kInk),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: kInk),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
            const SizedBox(height: 12),
            ...options.map((opt) {
              final isSelected = _selectedQualityCode == opt['code'];
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedQualityCode = opt['code']!;
                    _selectedQualityLabel = opt['label']!;
                  });
                  Navigator.pop(ctx);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE6F8EF) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? kGreen : Colors.grey.shade300,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? kGreen : Colors.grey,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt['label']!,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isSelected ? kGreen : kInk,
                              ),
                            ),
                            Text(
                              opt['sub']!,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    final controller = TextEditingController(text: _apiBaseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: kInk, width: 3),
        ),
        title: Text(
          'API Server Settings',
          style: GoogleFonts.delaGothicOne(fontSize: 16, color: kInk),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the backend server URL (Cloudflare Tunnel, Render, or Local PC):',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kInk, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _apiBaseUrl = 'http://10.0.2.2:5000'; // Android emulator localhost
              });
              Navigator.pop(ctx);
            },
            child: const Text('Emulator', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _apiBaseUrl = 'http://127.0.0.1:5000';
              });
              Navigator.pop(ctx);
            },
            child: const Text('Localhost', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kYellow,
              foregroundColor: kInk,
              elevation: 0,
              side: const BorderSide(color: kInk, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              setState(() {
                _apiBaseUrl = controller.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSkyBlue,
        elevation: 0,
        toolbarHeight: 70,
        shape: const Border(bottom: BorderSide(color: kInk, width: 3)),
        title: Row(
          children: [
            // Pink Mascot Play Logo
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kAccentPink,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kInk, width: 2.5),
                boxShadow: const [BoxShadow(color: kInk, offset: Offset(2.5, 2.5))],
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            Text(
              'Clipwave',
              style: GoogleFonts.delaGothicOne(
                fontSize: 22,
                color: kInk,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: kInk, size: 24),
            onPressed: _showSettingsDialog,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Japanese Tagline Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: kInk,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: kAccentPink, offset: Offset(2.5, 2.5))],
              ),
              child: Text(
                'ダウンロード  FREE VIDEO SAVER',
                style: GoogleFonts.mPlusRounded1c(
                  color: kYellow,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Hero Main Title
            Text(
              'Save any video.',
              textAlign: TextAlign.center,
              style: GoogleFonts.delaGothicOne(
                fontSize: 28,
                color: kInk,
                height: 1.15,
              ),
            ),
            Text(
              'Keep it forever!',
              textAlign: TextAlign.center,
              style: GoogleFonts.delaGothicOne(
                fontSize: 28,
                color: kAccentPink,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Paste a link, pick your power level, and download. No watermark, no ads, no limits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),

            // URL Input Card with Paste Button
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kInk, width: 3),
                boxShadow: const [BoxShadow(color: kInk, offset: Offset(5, 5))],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.link_rounded, color: kInk, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Paste YouTube, TikTok, Reels link...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.normal),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _urlController.text = data!.text!.trim();
                        _fetchVideoInfo();
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: kYellow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kInk, width: 2),
                      ),
                      child: const Text(
                        'Paste',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: kInk),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Download Trigger Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentPink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  side: const BorderSide(color: kInk, width: 3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: Colors.transparent,
                ),
                onPressed: _isLoading ? null : _fetchVideoInfo,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLoading ? 'Checking...' : 'Download',
                      style: GoogleFonts.delaGothicOne(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_downward_rounded, size: 22),
                  ],
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE11D48), width: 2),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFBE123C),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ================= ANIMATED LOADING RADAR (MATCHING USER SCREENSHOT) =================
            if (_isLoading) _buildLoadingRadarCard(),

            // ================= VIDEO RESULT CARD WITH SPLIT BUTTON =================
            if (_videoData != null && !_isLoading) _buildVideoResultCard(),

            const SizedBox(height: 30),

            // Platforms & Trust Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTrustChip('⚡ Instant Speed'),
                _buildTrustChip('🛡️ No Ads'),
                _buildTrustChip('🎬 1080p Ready'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Animated Loading Radar Card Widget
  Widget _buildLoadingRadarCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kInk, width: 3.5),
        boxShadow: const [BoxShadow(color: kInk, offset: Offset(6, 6))],
      ),
      child: Column(
        children: [
          // Circular Radar Spinner with Orbiting Dots
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Concentric ripple rings
                    Container(
                      width: 115 * _radarController.value + 40,
                      height: 115 * _radarController.value + 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: (1 - _radarController.value).clamp(0.0, 1.0)),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
                      ),
                    ),
                    // Orbiting blue dots from screenshot
                    Positioned(
                      top: 10 + 6 * math.sin(_radarController.value * 2 * math.pi),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14 + 5 * math.cos(_radarController.value * 2 * math.pi),
                      top: 30,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 30,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Center Download Icon Box
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
                      ),
                      child: const Icon(
                        Icons.file_download_outlined,
                        color: Color(0xFF2563EB),
                        size: 28,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Smooth Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 9,
              child: LinearProgressIndicator(
                value: _loadProgress,
                backgroundColor: const Color(0xFFEEF2F6),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Animated Status Text
          Text(
            _loadingStatusMsg,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  // Video Result Card with Split Dropdown Button
  Widget _buildVideoResultCard() {
    final title = _videoData!['title'] ?? 'Untitled Video';
    final duration = _videoData!['duration'] ?? 'Video';
    final platform = _videoData!['platform'] ?? 'Social Video';
    final author = _videoData!['author'] ?? 'Creator';
    final thumb = _videoData!['thumbnail'] ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kInk, width: 3.5),
        boxShadow: const [BoxShadow(color: kInk, offset: Offset(6, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with Duration Overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: thumb.isNotEmpty
                      ? Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.black12))
                      : Container(color: Colors.black26),
                ),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kInk,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    duration,
                    style: GoogleFonts.delaGothicOne(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: kYellow,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: kInk, width: 1.5),
                      ),
                      child: Text(
                        platform,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kInk),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kInk),
                ),
                const SizedBox(height: 18),

                // THE SPLIT DROPDOWN BUTTON (AS REQUESTED)
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kInk, width: 2.5),
                    boxShadow: const [BoxShadow(color: kInk, offset: Offset(3, 3))],
                  ),
                  child: Row(
                    children: [
                      // Left Part: Big Download Button
                      Expanded(
                        child: InkWell(
                          onTap: _isDownloading ? null : _startDownload,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: kGreen,
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(9)),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isDownloading ? 'Working...' : 'Download',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_downward, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Vertical Divider
                      Container(width: 2.5, color: kInk),

                      // Right Part: Quality Dropdown Toggle Button
                      InkWell(
                        onTap: _showQualityPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(9)),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            children: [
                              Text(
                                _selectedQualityLabel,
                                style: const TextStyle(
                                  color: kGreen,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down, color: kGreen, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_isDownloading) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4D0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kInk, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _downloadNotice,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _downloadPercent,
                            backgroundColor: Colors.black12,
                            valueColor: const AlwaysStoppedAnimation<Color>(kGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kInk, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kInk),
      ),
    );
  }
}
