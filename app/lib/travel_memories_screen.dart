import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../api_service.dart';
import '../models/user.dart';

class TravelMemoriesScreen extends StatefulWidget {
  final Trip trip;

  const TravelMemoriesScreen({super.key, required this.trip});

  @override
  State<TravelMemoriesScreen> createState() => _TravelMemoriesScreenState();
}

class _TravelMemoriesScreenState extends State<TravelMemoriesScreen> {
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic>? _memories;
  List<Map<String, dynamic>> _memoryPhotos = [];

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final response = await ApiService().getMemories(widget.trip.id);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _memories = data;
          _memoryPhotos = List<Map<String, dynamic>>.from(
            (data['memory_photos'] ?? []).map((photo) => {
              'id': photo['id'],
              'url': photo['url'],
              'caption': photo['caption'] ?? '',
              'timestamp': DateTime.parse(photo['timestamp']),
              'location': photo['location'] ?? '',
            })
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = '無法載入回憶錄: ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '載入回憶錄失敗: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ZenVoyage 足跡回憶錄'),
        backgroundColor: const Color(0xFF16a085),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF16a085), Color(0xFF1abc9c)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero section with trip info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF16a085), Color(0xFF1abc9c)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '足跡回憶錄',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.trip.name,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.trip.destination} | ${_formatDateRange(widget.trip.startDate, widget.trip.endDate)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),

            // Loading state
            if (_isLoading)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 16),
                    Text('正在生成足跡回憶錄...'),
                  ],
                ),
              ),

            // Error state
            if (_hasError)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '載入失敗',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_errorMessage),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadMemories,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('重新載入'),
                    ),
                  ],
                ),
              ),

            // Memories summary
            if (_memories != null && !_isLoading && !_hasError)
              _buildMemoriesSummary(),

            // Memory timeline
            if (_memories != null && !_isLoading && !_hasError)
              _buildMemoryTimeline(),

            // Memory photos
            if (_memories != null && !_isLoading && !_hasError)
              _buildMemoryPhotos(),

            // Instructions for GPS tracking
            if (_memories == null && !_isLoading && !_hasError)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '生成足跡回憶錄',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '要生成足跡回憶錄，您需要先開啟GPS追蹤功能來記錄您的旅行足跡。追蹤完成後，系統將自動分析您的路徑和照片，生成精美的回憶錄。',
                      style: TextStyle(
                        color: Colors.orange[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to GPS tracking screen
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('開啟GPS追蹤'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoriesSummary() {
    if (_memories == null) return const SizedBox.shrink();

    final memories = _memories!;
    final segments = memories['memory_segments']?.length ?? 0;
    final totalDistance = memories['total_distance_km'] ?? 0.0;
    final totalDuration = memories['total_duration'] ?? '0小時';
    final totalPhotos = memories['total_photos'] ?? 0;
    final destinations = memories['destinations_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '回憶概覽',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2c3e50),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                _buildStatRow('足跡段落', '$segments 段'),
                _buildStatRow('總距離', '${totalDistance.toStringAsFixed(1)} 公里'),
                _buildStatRow('總時長', totalDuration),
                _buildStatRow('照片數量', '$totalPhotos 張'),
                _buildStatRow('探索地點', '$destinations 個'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryTimeline() {
    if (_memories == null) return const SizedBox.shrink();

    final memories = _memories!;
    final memorySegments = memories['memory_segments'] ?? [];

    if (memorySegments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '足跡時間軸',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2c3e50),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: memorySegments.length,
              itemBuilder: (context, index) {
                final segment = memorySegments[index];
                return _buildMemorySegmentCard(segment);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemorySegmentCard(Map<String, dynamic> segment) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: const Color(0xFF16a085),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    segment['title'] ?? '未標題足跡',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2c3e50),
                    ),
                  ),
                ),
                Text(
                  segment['duration'] ?? '',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (segment['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  segment['description'],
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ),
            if (segment['locations'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '地點: ${segment['locations'].join(', ')}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryPhotos() {
    if (_memoryPhotos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '回憶照片',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2c3e50),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${_memoryPhotos.length} 張)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 1,
              ),
              itemCount: _memoryPhotos.length,
              itemBuilder: (context, index) {
                final photo = _memoryPhotos[index];
                return _buildPhotoThumbnail(photo);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(Map<String, dynamic> photo) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: Icon(
                Icons.image,
                color: Colors.grey[400],
                size: 30,
              ),
            ),
          ),
          if (photo['caption'] != null && photo['caption'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                photo['caption'],
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              _formatTime(photo['timestamp']),
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF16a085),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '日期待設定';
    
    final formatter = DateFormat('yyyy-MM-dd');
    return '${formatter.format(start)} - ${formatter.format(end)}';
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime time = timestamp is DateTime ? timestamp : DateTime.parse(timestamp);
    return DateFormat('MM/dd HH:mm').format(time);
  }
}