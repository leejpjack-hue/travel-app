import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../api_service.dart';
import '../models/user.dart';

class AIScreen extends StatefulWidget {
  final Trip trip;

  const AIScreen({super.key, required this.trip});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadConversationHistory();
  }

  Future<void> _loadConversationHistory() async {
    try {
      final response = await ApiService().getAIConversation(widget.trip.id);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages = (data['messages'] as List).map((msg) => {
            'id': msg['id'],
            'type': msg['type'] ?? 'ai',
            'content': msg['content'],
            'timestamp': DateTime.parse(msg['timestamp']),
            'suggestions': msg['suggestions'] ?? [],
          }).toList();
        });
      }
    } catch (e) {
      print('Failed to load conversation history: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isTyping) return;

    final userMessage = _messageController.text.trim();
    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'user',
        'content': userMessage,
        'timestamp': DateTime.now(),
        'suggestions': [],
      });
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await ApiService().postAIModification(widget.trip.id, userMessage);
      setState(() {
        _isTyping = false;
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          _messages.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'type': 'ai',
            'content': data['response'],
            'timestamp': DateTime.parse(data['timestamp']),
            'suggestions': (data['suggestions'] as List).map((s) => {
              'type': s['type'],
              'action': s['action'],
              'details': s['details'],
            }).toList(),
          });
          _scrollToBottom();
        });

        if (data['suggestions'] != null && data['suggestions'].isNotEmpty) {
          _showSuggestionsDialog(data['suggestions']);
        }
      } else {
        setState(() {
          _messages.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'type': 'ai',
            'content': '抱歉，我無法處理您的請求。請稍後再試或檢查網路連線。',
            'timestamp': DateTime.now(),
            'suggestions': [],
          });
          _isTyping = false;
          _scrollToBottom();
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'type': 'ai',
          'content': '抱歉，發生錯誤：$e',
          'timestamp': DateTime.now(),
          'suggestions': [],
        });
        _isTyping = false;
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSuggestionsDialog(List<dynamic> suggestions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('行程建議'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: suggestions.map((suggestion) => _buildSuggestionCard(suggestion)).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(dynamic suggestion) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getSuggestionIcon(suggestion['type']),
                  color: Color(0xFF3498db),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  _getSuggestionTitle(suggestion['action']),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2c3e50),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              suggestion['details']['description'] ?? '無描述',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              '預估時間: ${suggestion['details']['estimated_time'] ?? '待確認'}',
              style: TextStyle(
                color: Color(0xFF7f8c8d),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSuggestionIcon(String type) {
    switch (type) {
      case 'timeline':
        return Icons.schedule;
      case 'destination':
        return Icons.place;
      case 'transportation':
        return Icons.directions;
      case 'preference':
        return Icons.settings;
      default:
        return Icons.lightbulb;
    }
  }

  String _getSuggestionTitle(String action) {
    switch (action) {
      case 'add':
        return '新增項目';
      case 'modify':
        return '修改項目';
      case 'remove':
        return '移除項目';
      case 'recommend':
        return '推薦項目';
      case 'clarify':
        return '需要澄清';
      default:
        return '建議項目';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ZenVoyage AI 助手'),
        backgroundColor: const Color(0xFF9b59b6),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9b59b6), Color(0xFF8e44ad)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // AI Assistant Info
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFF9b59b6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZenVoyage AI',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2c3e50),
                          ),
                        ),
                        Text(
                          '您的專業旅遊規劃助手',
                          style: TextStyle(
                            color: Color(0xFF7f8c8d),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  '我正在協助您的行程：${widget.trip.name}',
                  style: TextStyle(
                    color: Color(0xFF2c3e50),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Input Area
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '輸入您的需求，例如：我想增加更多景點',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: 3,
                      minLines: 1,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(0xFF9b59b6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['type'] == 'user';
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(0xFF9b59b6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 16,
              ),
            ),
            SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser 
                      ? Color(0xFF9b59b6)
                      : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message['content'],
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                if (message['suggestions'] != null && message['suggestions'].isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF3498db)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '建議方案：',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2c3e50),
                          ),
                        ),
                        SizedBox(height: 8),
                        ...message['suggestions'].map((suggestion) => 
                          Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  _getSuggestionIcon(suggestion['type']),
                                  color: Color(0xFF3498db),
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_getSuggestionTitle(suggestion['action'])}: ${suggestion['details']['description'] ?? '無描述'}',
                                    style: TextStyle(
                                      color: Color(0xFF2c3e50),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).toList(),
                      ],
                    ),
                  ),
                SizedBox(height: 4),
                Text(
                  _formatTime(message['timestamp']),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(0xFF9b59b6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
        }

  Widget _buildTypingIndicator() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(0xFF9b59b6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 16,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(0xFF9b59b6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(0xFF9b59b6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(0xFF9b59b6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
        }

        String _formatTime(dynamic timestamp) {
          if (timestamp == null) return '';
          DateTime time = timestamp is DateTime ? timestamp : DateTime.parse(timestamp);
          return DateFormat('HH:mm').format(time);
        }

        @override
        void dispose() {
          _messageController.dispose();
          _scrollController.dispose();
          super.dispose();
        }
      }