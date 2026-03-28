import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class SharedFundScreen extends StatefulWidget {
  final String tripId;
  
  const SharedFundScreen({super.key, required this.tripId});

  @override
  State<SharedFundScreen> createState() => _SharedFundScreenState();
}

class _SharedFundScreenState extends State<SharedFundScreen> {
  List<dynamic> _splits = [];
  bool _isLoading = true;
  bool _showCreateDialog = false;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<String> _selectedParticipants = [];

  @override
  void initState() {
    super.initState();
    _fetchSplits();
  }

  Future<void> _fetchSplits() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('/api/trips/${widget.tripId}/splits'),
        headers: {
          'Content-Type': 'application/json',
          // Add authentication header if needed
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _splits = data['splits'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法載入拆帳列表')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('網路錯誤: $e')),
      );
    }
  }

  Future<void> _createSplit() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請填寫拆帳名稱')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('/api/trips/${widget.tripId}/splits'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': _nameController.text,
          'description': _descriptionController.text,
          'participants': _selectedParticipants,
        }),
      );

      if (response.statusCode == 201) {
        Navigator.pop(context);
        _fetchSplits();
        _nameController.clear();
        _descriptionController.clear();
        _selectedParticipants.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('創建拆帳失敗')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('網路錯誤: $e')),
      );
    }
  }

  Future<void> _addItem(String splitId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加費用項目'),
        content: StatefulBuilder(
          builder: (context, setState) {
            final amountController = TextEditingController();
            final descriptionController = TextEditingController();
            final categoryController = TextEditingController();
            
            return Form(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: '金額'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '請輸入金額';
                      }
                      if (double.tryParse(value) == null || double.parse(value) <= 0) {
                        return '請輸入有效的金額';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: '描述'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '請輸入描述';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: '類別 (可選)'),
                    initialValue: '飲食',
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final form = Form.of(context);
              if (form!.validate()) {
                try {
                  final response = await http.post(
                    Uri.parse('/api/trips/${widget.tripId}/splits/$splitId/items'),
                    headers: {
                      'Content-Type': 'application/json',
                    },
                    body: json.encode({
                      'amount': double.parse(amountController.text),
                      'description': descriptionController.text,
                      'category': categoryController.text.isNotEmpty ? categoryController.text : null,
                    }),
                  );

                  if (response.statusCode == 201) {
                    Navigator.pop(context);
                    _fetchSplits();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('費用項目已添加')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('添加失敗')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('網路錯誤: $e')),
                  );
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitCard(dynamic split) {
    final totalAmount = split['total_amount'] ?? 0;
    final isSettled = split['is_settled'] ?? false;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    split['name'] ?? '未知拆帳',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSettled ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isSettled ? '已結清' : '進行中',
                    style: TextStyle(
                      color: isSettled ? Colors.green.shade700 : Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (split['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  split['description'],
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '總金額: ¥${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '項目數: ${split['items']?.length ?? 0}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addItem(split['id']),
                    icon: const Icon(Icons.add),
                    label: const Text('添加費用'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSplitDetails(split),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('查看詳情'),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isSettled)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _settleSplit(split['id']),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('結清'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27AE60),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSplitDetails(dynamic split) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${split['name']} 詳情'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('總金額: ¥${split['total_amount']}'),
              const SizedBox(height: 8),
              Text('已付金額: ¥${split['total_paid']}'),
              const SizedBox(height: 8),
              Text('應付金額: ¥${split['total_owed']}'),
              const SizedBox(height: 16),
              const Text('參與者:'),
              const SizedBox(height: 8),
              ...(split['participants'] as List).map((participant) {
                return Text('• ${participant['user_id]}: ¥${participant['amount_owed']} (已付: ¥${participant['amount_paid']})');
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('共同基金拆帳'),
        backgroundColor: const Color(0xFF4ECDC4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF4ECDC4).withOpacity(0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '行程拆帳管理',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '行程ID: ${widget.tripId}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Create button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: _showCreateSplitDialog,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('創建新拆帳'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Splits list
                Expanded(
                  child: _splits.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '暫無拆帳記錄',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '點擊上方按鈕創建第一個拆帳',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _splits.length,
                          itemBuilder: (context, index) {
                            return _buildSplitCard(_splits[index]);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSplitDialog,
        backgroundColor: const Color(0xFF4ECDC4),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showCreateSplitDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final tempNameController = TextEditingController();
          final tempDescriptionController = TextEditingController();
          List<String> tempSelectedParticipants = List.from(_selectedParticipants);
          
          return AlertDialog(
            title: const Text('創建新拆帳'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tempNameController,
                    decoration: const InputDecoration(labelText: '拆帳名稱 *'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tempDescriptionController,
                    decoration: const InputDecoration(labelText: '描述 (可選)'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  const Text('選擇參與者 *', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      // Add demo participants (in real app, fetch from trip collaborators)
                      ['user1', 'user2', 'user3', 'user4', 'user5'].map((userId) {
                        final isSelected = tempSelectedParticipants.contains(userId);
                        return FilterChip(
                          label: Text('使用者 $userId'),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                tempSelectedParticipants.add(userId);
                              } else {
                                tempSelectedParticipants.remove(userId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ],
                  ),
                  if (tempSelectedParticipants.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '請至少選擇一個參與者',
                        style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (tempNameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請填寫拆帳名稱')),
                    );
                    return;
                  }
                  if (tempSelectedParticipants.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請選擇參與者')),
                    );
                    return;
                  }

                  setState(() {
                    _nameController.text = tempNameController.text;
                    _descriptionController.text = tempDescriptionController.text;
                    _selectedParticipants = tempSelectedParticipants;
                    _showCreateDialog = false;
                    _createSplit();
                  });
                },
                child: const Text('創建'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _settleSplit(String splitId) async {
    try {
      final response = await http.post(
        Uri.parse('/api/trips/${widget.tripId}/splits/$splitId/settle'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _fetchSplits();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('拆帳已結清')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('結清失敗')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('網路錯誤: $e')),
      );
    }
  }
}