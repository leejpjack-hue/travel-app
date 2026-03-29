import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';
import 'package:flutter/foundation.dart';

class TimelineScreen extends StatefulWidget {
  final String tripId;
  
  const TimelineScreen({Key? key, required this.tripId}) : super(key: key);

  @override
  _TimelineScreenState createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<dynamic> timelineItems = [];
  List<dynamic> conflicts = [];
  List<dynamic> travelTimes = [];
  int totalWalkingDistance = 0;
  bool isLoading = true;
  bool isReordering = false;
  String? error;
  int? draggedItemIndex;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
    _loadTravelTimes();
  }

  Future<void> _loadTimeline() async {
    try {
      final response = await http.get(
        Uri.parse('/api/trips/${widget.tripId}/timeline'),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          timelineItems = data['timeline_items'] ?? [];
          conflicts = data['business_hours_conflicts'] ?? [];
          totalWalkingDistance = data['total_walking_distance'] ?? 0;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load timeline: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error loading timeline: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _loadTravelTimes() async {
    try {
      final response = await http.get(
        Uri.parse('/api/trips/${widget.tripId}/travel-times'),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          travelTimes = data['travel_times'] ?? [];
        });
      }
    } catch (e) {
      // Travel times are optional, don't show error
      if (kDebugMode) {
        print('Error loading travel times: $e');
      }
    }
  }

  Future<void> _addTimelineItem() async {
    final nameController = TextEditingController();
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();
    final typeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Timeline Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
              textCapitalization: TextCapitalization.sentences,
            ),
            TextField(
              controller: typeController,
              decoration: const InputDecoration(labelText: 'Type (destination/meal/activity/rest)'),
              textCapitalization: TextCapitalization.sentences,
            ),
            TextField(
              controller: startTimeController,
              decoration: const InputDecoration(labelText: 'Start Time (YYYY-MM-DD HH:MM)'),
              keyboardType: TextInputType.datetime,
            ),
            TextField(
              controller: endTimeController,
              decoration: const InputDecoration(labelText: 'End Time (YYYY-MM-DD HH:MM)'),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Duration (minutes, optional)',
                hintText: 'Leave empty to calculate from times',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty || 
                  typeController.text.isEmpty ||
                  startTimeController.text.isEmpty || 
                  endTimeController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all required fields')),
                );
                return;
              }

              try {
                final response = await http.post(
                  Uri.parse('/api/trips/${widget.tripId}/timeline'),
                  headers: await _authHeaders(),
                  body: json.encode({
                    'name': nameController.text,
                    'type': typeController.text,
                    'start_time': startTimeController.text,
                    'end_time': endTimeController.text,
                    'duration_minutes': (int.tryParse(endTimeController.text.split(' ')[1].split(':')[0]) ?? 0) -
                                      (int.tryParse(startTimeController.text.split(' ')[1].split(':')[0]) ?? 0),
                  }),
                );

                if (response.statusCode == 201) {
                  Navigator.pop(context);
                  _loadTimeline();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Timeline item added successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add item: ${response.statusCode}')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkConflicts() async {
    try {
      final response = await http.get(
        Uri.parse('/api/trips/${widget.tripId}/timeline/conflicts'),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          conflicts = data['business_hours_conflicts'] ?? [];
        });
        
        if (conflicts.isNotEmpty) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Timeline Conflicts Found'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: conflicts.length,
                  itemBuilder: (context, index) {
                    final conflict = conflicts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(conflict['name'] ?? 'Unknown Item'),
                        subtitle: Text(conflict['business_hours_start'] != null && conflict['business_hours_end'] != null
                            ? 'Business hours: ${conflict['business_hours_start']} - ${conflict['business_hours_end']}'
                            : 'Time overlap detected'),
                        leading: const Icon(Icons.warning, color: Colors.orange),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('No Conflicts'),
              content: const Text('No timeline conflicts found. Your schedule looks good!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking conflicts: ${e.toString()}')),
      );
    }
  }

  Future<void> _reorderTimelineItems(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final reorderedItems = List<dynamic>.from(timelineItems);
    final movedItem = reorderedItems.removeAt(oldIndex);
    reorderedItems.insert(newIndex, movedItem);

    // Update order indices
    final itemOrders = reorderedItems.asMap().entries.map((entry) => {
      'item_id': entry.value['id'],
      'new_index': entry.key,
    }).toList();

    try {
      final response = await http.put(
        Uri.parse('/api/trips/${widget.tripId}/timeline/reorder'),
        headers: await _authHeaders(),
        body: json.encode({'item_orders': itemOrders}),
      );

      if (response.statusCode == 200) {
        setState(() {
          timelineItems = reorderedItems;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timeline reordered successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reorder: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reordering: ${e.toString()}')),
      );
    }
  }

  Future<void> _lockTimelineItem(String itemId, bool isLocked) async {
    try {
      final response = await http.put(
        Uri.parse('/api/trips/${widget.tripId}/timeline/$itemId'),
        headers: await _authHeaders(),
        body: json.encode({'locked': isLocked}),
      );

      if (response.statusCode == 200) {
        _loadTimeline();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item ${isLocked ? 'locked' : 'unlocked'} successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating item: ${e.toString()}')),
      );
    }
  }

  void _showItemOptions(int index) {
    final item = timelineItems[index];
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Item'),
            onTap: () {
              Navigator.pop(context);
              _editTimelineItem(index);
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text(item['locked'] == true ? 'Unlock Item' : 'Lock Item'),
            onTap: () {
              Navigator.pop(context);
              _lockTimelineItem(item['id'], !(item['locked'] == true));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Item'),
            onTap: () {
              Navigator.pop(context);
              _deleteTimelineItem(index);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editTimelineItem(int index) async {
    final item = timelineItems[index];
    final nameController = TextEditingController(text: item['name']);
    final startTimeController = TextEditingController(text: item['start_time']);
    final endTimeController = TextEditingController(text: item['end_time']);
    final durationController = TextEditingController(
      text: (item['duration_minutes'] ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Timeline Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            TextField(
              controller: startTimeController,
              decoration: const InputDecoration(labelText: 'Start Time (YYYY-MM-DD HH:MM)'),
              keyboardType: TextInputType.datetime,
            ),
            TextField(
              controller: endTimeController,
              decoration: const InputDecoration(labelText: 'End Time (YYYY-MM-DD HH:MM)'),
              keyboardType: TextInputType.datetime,
            ),
            TextField(
              controller: durationController,
              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final response = await http.put(
                  Uri.parse('/api/trips/${widget.tripId}/timeline/${item['id']}'),
                  headers: await _authHeaders(),
                  body: json.encode({
                    'name': nameController.text,
                    'start_time': startTimeController.text,
                    'end_time': endTimeController.text,
                    'duration_minutes': int.tryParse(durationController.text),
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  _loadTimeline();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item updated successfully')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTimelineItem(int index) async {
    final item = timelineItems[index];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final response = await http.delete(
                  Uri.parse('/api/trips/${widget.tripId}/timeline/${item['id']}'),
                  headers: await _authHeaders(),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  _loadTimeline();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item deleted successfully')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting item: ${e.toString()}')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }


  Future<Map<String, String>> _authHeaders() async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer \$token',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline Management'),
        backgroundColor: const Color(0xFF2563eb),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTimelineItem,
          ),
          IconButton(
            icon: const Icon(Icons.warning),
            onPressed: _checkConflicts,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTimeline,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTimeline,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary card
                    Card(
                      margin: const EdgeInsets.all(16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Timeline Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text('${timelineItems.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    const Text('Total Items'),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('${totalWalkingDistance}m', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    const Text('Walking Distance'),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('${conflicts.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    const Text('Conflicts'),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Timeline items list with drag and drop
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: timelineItems.length,
                        onReorder: _reorderTimelineItems,
                        itemBuilder: (context, index) {
                          final item = timelineItems[index];
                          final hasConflict = conflicts.any((c) => c['name'] == item['name']);
                          final isLocked = item['locked'] == true;

                          return Card(
                            key: ValueKey(item['id']),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 4.0,
                            ),
                            color: hasConflict ? Colors.red.shade50 : null,
                            elevation: hasConflict ? 2 : 1,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: ReorderableDragStartListener(
                                index: index,
                                child: Icon(
                                  isLocked ? Icons.lock : Icons.drag_handle,
                                  color: isLocked ? Colors.orange : Colors.grey,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['name'] ?? 'Unknown Item',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: hasConflict ? Colors.red.shade700 : null,
                                      ),
                                    ),
                                  ),
                                  if (item['type'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getTypeColor(item['type']),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        item['type']?.toString().toUpperCase() ?? '',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 16),
                                      const SizedBox(width: 4),
                                      Text(_formatTime(item['start_time'])),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.schedule, size: 16),
                                      const SizedBox(width: 4),
                                      Text(_formatTime(item['end_time'])),
                                      if (item['duration_minutes'] != null)
                                        Text(' • ${item['duration_minutes']} min'),
                                    ],
                                  ),
                                  if (item['walking_distance_meters'] != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.directions_walk, size: 16),
                                        const SizedBox(width: 4),
                                        Text('${item['walking_distance_meters']}m'),
                                      ],
                                    ),
                                  ],
                                  if (isLocked) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.lock, size: 16, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text('Locked', style: TextStyle(color: Colors.orange)),
                                      ],
                                    ),
                                  ],
                                  if (hasConflict) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.warning, size: 16, color: Colors.red),
                                        const SizedBox(width: 4),
                                        Text('Business hours conflict', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      _editTimelineItem(index);
                                      break;
                                    case 'lock':
                                      _lockTimelineItem(item['id'], !isLocked);
                                      break;
                                    case 'delete':
                                      _deleteTimelineItem(index);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'lock',
                                    child: Row(
                                      children: [
                                        Icon(isLocked ? Icons.lock_open : Icons.lock),
                                        SizedBox(width: 8),
                                        Text(isLocked ? 'Unlock' : 'Lock'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onLongPress: () => _showItemOptions(index),
                            ),
                          );
                        },
                      ),
                    ),

                    // Smart fill button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Smart Fill Gaps'),
                        onPressed: _smartFillGaps,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10b981),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Color _getTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'destination':
        return Colors.blue;
      case 'meal':
        return Colors.green;
      case 'activity':
        return Colors.purple;
      case 'rest':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _formatTime(String? time) {
    if (time == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(time);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return time;
    }
  }

  Future<void> _smartFillGaps() async {
    if (timelineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add timeline items first to identify gaps')),
      );
      return;
    }

    // Find gaps between timeline items
    final gaps = [];
    for (int i = 0; i < timelineItems.length - 1; i++) {
      final current = timelineItems[i];
      final next = timelineItems[i + 1];
      
      try {
        final currentEnd = DateTime.parse(current['end_time']);
        final nextStart = DateTime.parse(next['start_time']);
        final gapDuration = nextStart.difference(currentEnd).inMinutes;
        
        if (gapDuration > 30) { // Only fill gaps longer than 30 minutes
          gaps.add({
            'start': current['end_time'],
            'end': next['start_time'],
            'duration': gapDuration,
            'index': i,
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing time for gap detection: $e');
        }
      }
    }

    if (gaps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No significant gaps found to fill')),
      );
      return;
    }

    // Show gap selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smart Fill Options'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: gaps.length,
            itemBuilder: (context, index) {
              final gap = gaps[index];
              return Card(
                child: ListTile(
                  title: Text('Gap ${index + 1}'),
                  subtitle: Text('${gap['duration']} minutes'),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () {
                    Navigator.pop(context);
                    _fillGap(gap['start'], gap['end']);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _fillGap(String gapStart, String gapEnd) async {
    try {
      final response = await http.post(
        Uri.parse('/api/trips/${widget.tripId}/timeline/smart-fill'),
        headers: await _authHeaders(),
        body: json.encode({
          'gap_start': gapStart,
          'gap_end': gapEnd,
          'preferences': {'pace': 'moderate', 'transport': 'public'},
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _loadTimeline();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${data['added_items'].length} items to fill gaps')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fill gaps: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error filling gaps: ${e.toString()}')),
      );
    }
  }
}