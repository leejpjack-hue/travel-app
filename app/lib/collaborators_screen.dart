import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class CollaboratorsScreen extends StatefulWidget {
  final String tripId;
  final String tripName;

  const CollaboratorsScreen({
    super.key,
    required this.tripId,
    required this.tripName,
  });

  @override
  State<CollaboratorsScreen> createState() => _CollaboratorsScreenState();
}

class _CollaboratorsScreenState extends State<CollaboratorsScreen> {
  final _emailController = TextEditingController();
  final _roleController = TextEditingController();
  bool _isLoading = false;
  String? _authToken;
  List<dynamic> _collaborators = [];
  bool _showAddDialog = false;

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
    _loadCollaborators();
  }

  Future<void> _loadAuthToken() async {
    final token = await _getStoredToken();
    setState(() {
      _authToken = token;
    });
  }

  Future<String?> _getStoredToken() async {
    try {
      final file = File('/tmp/travel_app_token.txt');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      print('Error loading token: $e');
    }
    return null;
  }

  Future<void> _loadCollaborators() async {
    if (_authToken == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('/api/trips/${widget.tripId}/collaborators');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _collaborators = data['collaborators'] ?? [];
        });
      } else {
        _showErrorDialog('載入協作者失敗');
      }
    } catch (e) {
      _showErrorDialog('網路錯誤: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addCollaborator() async {
    if (!_emailController.text.contains('@')) {
      _showErrorDialog('請輸入有效的 email');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('/api/trips/${widget.tripId}/collaborators');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({
          'collaborator_email': _emailController.text,
          'role': _roleController.text.isNotEmpty ? _roleController.text : 'editor',
        }),
      );

      if (response.statusCode == 201) {
        _showSuccessDialog('協作者已成功添加！');
        _emailController.clear();
        _roleController.clear();
        setState(() {
          _showAddDialog = false;
        });
        _loadCollaborators();
      } else {
        final error = json.decode(response.body)['error'] || '添加協作者失敗';
        _showErrorDialog('錯誤: $error');
      }
    } catch (e) {
      _showErrorDialog('網路錯誤: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeCollaborator(String collaboratorId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('/api/trips/${widget.tripId}/collaborators/$collaboratorId');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        _showSuccessDialog('協作者已移除');
        _loadCollaborators();
      } else {
        _showErrorDialog('移除協作者失敗');
      }
    } catch (e) {
      _showErrorDialog('網路錯誤: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('成功'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('錯誤'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('協作管理 - ${widget.tripName}'),
        backgroundColor: const Color(0xFF4ECDC4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => _showAddDialog = true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCollaborators,
              child: Column(
                children: [
                  // Trip info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4).withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tripName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '管理行程協作者',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Collaborators list
                  Expanded(
                    child: _collaborators.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.group,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '還沒有協作者',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '點擊 + 按鈕添加協作者',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _collaborators.length,
                            itemBuilder: (context, index) {
                              final collaborator = _collaborators[index];
                              return _buildCollaboratorCard(collaborator);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCollaboratorCard(dynamic collaborator) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF4ECDC4).withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.person,
              size: 25,
              color: const Color(0xFF4ECDC4),
            ),
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collaborator['name'] ?? collaborator['email'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  collaborator['email'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(collaborator['role']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRoleText(collaborator['role']),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Remove button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmRemoveCollaborator(collaborator['id']),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'editor':
        return const Color(0xFF4ECDC4);
      case 'viewer':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getRoleText(String? role) {
    switch (role) {
      case 'admin':
        return '管理員';
      case 'editor':
        return '編輯者';
      case 'viewer':
        return '檢視者';
      default:
        return role ?? '未知';
    }
  }

  void _confirmRemoveCollaborator(String collaboratorId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認移除'),
        content: const Text('確定要移除這位協作者嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeCollaborator(collaboratorId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }
}