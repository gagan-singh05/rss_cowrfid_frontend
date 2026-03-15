import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

const String baseUrl = "https://rss-cowrfid-backend.vercel.app/api";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RFID Block Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C3CE1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const ControllerPage(),
    );
  }
}

// ─────────────────────────────────────────────
//  MAIN CONTROLLER PAGE
// ─────────────────────────────────────────────
class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _activeBlock;
  bool _isSessionActive = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkStatus(); // Once on app start to get initial state
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/session/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _isSessionActive = data['is_active'];
            _activeBlock = data['block'];
          });
        }
      }
    } catch (e) {
      debugPrint("SESSION ERROR: $e");
    }
  }

  Future<void> _startSession(String blockName) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/session/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'start', 'block': blockName}),
      );
      if (response.statusCode == 200) {
        await _checkStatus();
        if (mounted) {
          // Open block detail page — stream + stop button are inside
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlockDetailPage(blockName: blockName),
            ),
          );
          // Refresh status when returning from detail page
          _checkStatus();
        }
      } else {
        _showError("Failed to start: ${response.body}");
      }
    } catch (e) {
      _showError("Connection error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openBlockDetail(String block) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BlockDetailPage(blockName: block)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStatusBanner(),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                  children: ["A", "B", "C", "D"]
                      .map((block) => _buildBlockCard(block))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C3CE1), Color(0xFF9B59B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.wifi_tethering, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cow RFID Controller',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Block Scanning System',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: _isSessionActive
          ? const Color(0xFF1DB954).withValues(alpha: 0.12)
          : const Color(0xFF6C3CE1).withValues(alpha: 0.07),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _isSessionActive ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSessionActive
                      ? const Color(0xFF1DB954)
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _isSessionActive
                ? 'LIVE — Block $_activeBlock is recording'
                : 'IDLE — Select a block to start scanning',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _isSessionActive
                  ? const Color(0xFF1DB954)
                  : Colors.grey.shade600,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          if (_isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildBlockCard(String block) {
    final bool isActive = _isSessionActive && _activeBlock == block;
    final bool isDisabled =
        _isLoading || (_isSessionActive && _activeBlock != block);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isActive ? const Color(0xFF1DB954) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isActive
                ? const Color(0xFF1DB954).withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: isActive ? 20 : 10,
            spreadRadius: isActive ? 2 : 0,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isActive
              ? const Color(0xFF17A948)
              : isDisabled
                  ? Colors.grey.shade200
                  : const Color(0xFF6C3CE1).withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Opacity(
        opacity: isDisabled && !isActive ? 0.45 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openBlockDetail(block),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top: block label + status chip + view hint
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BLOCK',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: isActive
                                    ? Colors.white70
                                    : Colors.grey.shade400,
                              ),
                            ),
                            Text(
                              block,
                              style: TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                color: isActive
                                    ? Colors.white
                                    : const Color(0xFF6C3CE1),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildStatusChip(isActive, isDisabled),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 10,
                                  color: isActive
                                      ? Colors.white60
                                      : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'View',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isActive
                                        ? Colors.white60
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Bottom: Start / Stop button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: isActive
                          ? _buildStopButton(block)
                          : _buildStartButton(block, isDisabled),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive, bool isDisabled) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.25)
            : isDisabled
                ? Colors.grey.shade100
                : const Color(0xFF6C3CE1).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.white
                  : isDisabled
                      ? Colors.grey.shade400
                      : const Color(0xFF6C3CE1).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'ACTIVE' : 'IDLE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: isActive
                  ? Colors.white
                  : isDisabled
                      ? Colors.grey.shade400
                      : const Color(0xFF6C3CE1).withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(String block, bool isDisabled) {
    return ElevatedButton.icon(
      onPressed: isDisabled ? null : () => _startSession(block),
      icon: const Icon(Icons.play_arrow_rounded, size: 20),
      label: const Text(
        'START',
        style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C3CE1),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade200,
        disabledForegroundColor: Colors.grey.shade400,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildStopButton(String block) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : () => _openBlockDetail(block),
      icon: const Icon(Icons.stop_rounded, size: 20),
      label: const Text(
        'STOP',
        style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFE53935),
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BLOCK DETAIL PAGE  (SSE live stream)
// ─────────────────────────────────────────────
class BlockDetailPage extends StatefulWidget {
  final String blockName;
  const BlockDetailPage({super.key, required this.blockName});

  @override
  State<BlockDetailPage> createState() => _BlockDetailPageState();
}

class _BlockDetailPageState extends State<BlockDetailPage> {
  List<Map<String, dynamic>> _scans = [];
  bool _isLoading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  // Live polling
  Timer? _pollTimer;
  bool _isViewingToday = true;

  // Session
  bool _isSessionActive = true; // opened via START so assume active initially
  bool _isStopping = false;

  bool get _isLive => _isViewingToday && _pollTimer != null;

  String get _selectedDateStr =>
      "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

  @override
  void initState() {
    super.initState();
    _fetchScans(showLoading: true);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isViewingToday && mounted) _fetchScans();
    });
  }

  // ── Stop session ─────────────────────────────
  Future<void> _stopSession() async {
    setState(() => _isStopping = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/session/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'stop'}),
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() => _isSessionActive = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stop failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isStopping = false);
    }
  }

  // ── Historical fetch ────────────────────────
  Future<void> _fetchScans({bool showLoading = false}) async {
    if (showLoading) setState(() { _isLoading = true; _error = null; });
    try {
      final response = await http.get(Uri.parse('$baseUrl/scans/'));
      if (response.statusCode == 200) {
        final List<dynamic> all = json.decode(response.body);
        final filtered = all
            .cast<Map<String, dynamic>>()
            .where((s) =>
                s['block'] == widget.blockName && s['date'] == _selectedDateStr)
            .toList();
        debugPrint("SCANS total:${all.length} filtered:${filtered.length} block=${widget.blockName} date=$_selectedDateStr");
        if (!mounted) return;
        setState(() {
          _scans = filtered;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        if (showLoading) setState(() { _error = "Server error: ${response.statusCode}"; _isLoading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      if (showLoading) setState(() { _error = "Connection error: $e"; _isLoading = false; });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF6C3CE1)),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      final today = DateTime.now();
      final isToday = picked.year == today.year &&
          picked.month == today.month &&
          picked.day == today.day;
      setState(() {
        _selectedDate = picked;
        _isViewingToday = isToday;
      });
      _fetchScans(showLoading: true);
    }
  }

  // Removed _inCount and _outCount as they are no longer needed


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildDetailHeader(),
            _buildSummaryRow(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchScans(showLoading: true),
                color: const Color(0xFF6C3CE1),
                child: _buildBody(),
              ),
            ),
            // STOP SESSION button — visible only when session is active
            if (_isSessionActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isStopping ? null : _stopSession,
                    icon: _isStopping
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.stop_rounded, size: 24),
                    label: Text(
                      _isStopping ? 'Stopping...' : 'STOP SESSION',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C3CE1), Color(0xFF9B59B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.blockName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Block ${widget.blockName}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              // Live / Offline indicator
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isLive ? const Color(0xFF1DB954) : Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isLive ? 'LIVE' : 'Connecting...',
                    style: TextStyle(
                      color: _isLive ? const Color(0xFF1DB954) : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Date picker
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _buildSummaryChip(Icons.format_list_numbered_rounded,
              '${_scans.length}', 'Total Scans', const Color(0xFF6C3CE1)),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
      IconData icon, String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(count,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF6C3CE1)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchScans,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C3CE1),
                  foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_scans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors_off_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No scans for Block ${widget.blockName}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text(
              'on ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded),
              label: const Text('Change Date'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _scans.length,
      itemBuilder: (context, index) => _buildScanCard(_scans[index], index),
    );
  }

  Widget _buildScanCard(Map<String, dynamic> scan, int index) {
    const Color primaryColor = Color(0xFF6C3CE1);
    final String time = scan['time'] ?? '--';
    final String date = scan['date'] ?? '--';
    final String uid = scan['uid'] ?? '--';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.tag_rounded,
            color: primaryColor,
            size: 22,
          ),
        ),
        title: Text(uid,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                fontFamily: 'monospace')),
        subtitle: Text(date,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        trailing: Text(
          time.length > 5 ? time.substring(0, 5) : time,
          style: const TextStyle(
              fontSize: 16, color: primaryColor, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
