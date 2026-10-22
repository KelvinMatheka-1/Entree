import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/event_model.dart';
import '../services/api_service.dart';
import '../services/media_helper.dart';
import '../widgets/common_widgets.dart';
import '../widgets/location_picker_modal.dart';

class EditEventScreen extends StatefulWidget {
  final EventModel event;

  const EditEventScreen({super.key, required this.event});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dateController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _venueController;
  late final TextEditingController _tablesController;
  late final TextEditingController _seatsController;

  String? _bannerImagePath;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  double? _latitude;
  double? _longitude;
  String? _formattedAddress;
  String? _city;
  late bool _isFeatured;

  String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _startTimeController.text = _formatTime(picked);
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _endTimeController.text = _formatTime(picked);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _isFeatured = widget.event.isFeatured;
    _selectedDate = widget.event.date;
    final startParts = widget.event.startTime.split(':');
    _startTime = TimeOfDay(
      hour: int.tryParse(startParts[0]) ?? 18,
      minute: startParts.length > 1 ? (int.tryParse(startParts[1]) ?? 0) : 0,
    );
    final endParts = widget.event.endTime.split(':');
    _endTime = TimeOfDay(
      hour: int.tryParse(endParts[0]) ?? 22,
      minute: endParts.length > 1 ? (int.tryParse(endParts[1]) ?? 0) : 0,
    );
    _nameController = TextEditingController(text: widget.event.name);
    _descriptionController =
        TextEditingController(text: widget.event.description);
    _dateController = TextEditingController(text: _formatDate(widget.event.date));
    _startTimeController =
        TextEditingController(text: widget.event.startTime);
    _endTimeController = TextEditingController(text: widget.event.endTime);
    _venueController = TextEditingController(text: widget.event.venue);
    _tablesController =
        TextEditingController(text: '${widget.event.tables}');
    _seatsController =
        TextEditingController(text: '${widget.event.seatsPerTable}');

    _bannerImagePath = widget.event.imageUrl;
    _latitude = widget.event.latitude ?? -1.286389;
    _longitude = widget.event.longitude ?? 36.817223;
    _formattedAddress = widget.event.venueAddress;
    _city = widget.event.city ?? 'Nairobi';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _venueController.dispose();
    _tablesController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  int get _totalSeats {
    final tables = int.tryParse(_tablesController.text) ?? 0;
    final seats = int.tryParse(_seatsController.text) ?? 0;
    return tables * seats;
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.surfaceWhite,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        foregroundColor:
            isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit event',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete Event',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Event'),
                  content: Text('Are you sure you want to delete "${widget.event.name}"? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ApiService.instance.deleteEvent(widget.event.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Event "${widget.event.name}" deleted')),
                  );
                  Navigator.pop(context, 'deleted');
                }
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Published badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.liveGreen.withAlpha(30)
                            : AppTheme.liveGreenBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event.status == EventStatus.live
                            ? 'Published · live'
                            : 'Published',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.liveGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Update ${event.name}. Your ${event.passesIssued} issued passes and table assignments will be kept.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 24),

                    // Event Image
                    Text(
                      'Event image',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SafeNetworkImage(
                            imageUrl: _bannerImagePath ?? event.imageUrl,
                            width: double.infinity,
                            height: 160,
                            borderRadius: BorderRadius.circular(12),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: GestureDetector(
                            onTap: () async {
                              final path = await MediaHelper.pickAndCropImage(
                                context,
                                cropType: CropPresetType.eventBanner,
                              );
                              if (path != null) {
                                setState(() => _bannerImagePath = path);
                              }
                            },
                            child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E212D)
                                  : AppTheme.surfaceWhite,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.darkCardBorder
                                    : AppTheme.borderLight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withAlpha(isDark ? 60 : 20),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  size: 14,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Replace image',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? AppTheme.darkTextPrimary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ai-summit-cover.jpg · Cover image added',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkTextTertiary
                                : AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 24),

                    // Event Name
                    Text(
                      'Event name',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // When & Where
                    const SectionLabel(text: 'WHEN & WHERE'),
                    Text(
                      'Event date',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: IgnorePointer(
                        child: TextField(
                          controller: _dateController,
                          readOnly: true,
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            suffixIcon: Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: isDark
                                  ? AppTheme.accentLime
                                  : AppTheme.primaryPurple,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start time',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _pickStartTime,
                                borderRadius: BorderRadius.circular(10),
                                child: IgnorePointer(
                                  child: TextField(
                                    controller: _startTimeController,
                                    readOnly: true,
                                    style: TextStyle(
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.textPrimary,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      suffixIcon: Icon(
                                        Icons.access_time,
                                        size: 18,
                                        color: isDark
                                            ? AppTheme.accentLime
                                            : AppTheme.primaryPurple,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End time',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _pickEndTime,
                                borderRadius: BorderRadius.circular(10),
                                child: IgnorePointer(
                                  child: TextField(
                                    controller: _endTimeController,
                                    readOnly: true,
                                    style: TextStyle(
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.textPrimary,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      suffixIcon: Icon(
                                        Icons.access_time,
                                        size: 18,
                                        color: isDark
                                            ? AppTheme.accentLime
                                            : AppTheme.primaryPurple,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Venue',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _venueController,
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter venue or pick on map',
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.map_outlined,
                            size: 20,
                            color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                          ),
                          tooltip: 'Pick location on map',
                          onPressed: () async {
                            final result = await LocationPickerModal.show(
                              context,
                              initialLatitude: _latitude,
                              initialLongitude: _longitude,
                              initialAddress: _venueController.text,
                            );
                            if (result != null) {
                              setState(() {
                                _venueController.text = result.address;
                                _latitude = result.latitude;
                                _longitude = result.longitude;
                                _formattedAddress = result.address;
                                if (result.city != null && result.city!.isNotEmpty) {
                                  _city = result.city;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.pin_drop_outlined,
                          size: 13,
                          color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${_formattedAddress ?? widget.event.venueAddress} · (${_latitude?.toStringAsFixed(4) ?? "-1.2864"}, ${_longitude?.toStringAsFixed(4) ?? "36.8172"})',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppTheme.darkTextTertiary
                                      : AppTheme.textSecondary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Seating & Passes
                    const SectionLabel(text: 'SEATING & PASSES'),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tables',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _tablesController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seats per table',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _seatsController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InfoBanner(
                      icon: Icons.event_seat_outlined,
                      text: '$_totalSeats total seats / passes',
                      subtext:
                          '${event.passesIssued} issued · ${_totalSeats - event.passesIssued} still available',
                    ),
                    const SizedBox(height: 20),

                    // Featured Event Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isFeatured
                              ? AppTheme.accentLime.withAlpha(160)
                              : (isDark ? AppTheme.darkCardBorder : AppTheme.borderLight),
                          width: _isFeatured ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Featured Event',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Showcase in the rotating featured banner on Home',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _isFeatured,
                            activeTrackColor: AppTheme.accentLime,
                            onChanged: (val) {
                              setState(() {
                                _isFeatured = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Capacity cannot be lower than ${event.passesIssued} issued passes. Existing guest and table assignments stay unchanged.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkTextTertiary
                                : AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Fixed bottom button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              decoration: BoxDecoration(
                color:
                    isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppTheme.darkCardBorder
                        : AppTheme.borderLight,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 40 : 12),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final name = _nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter an event name')),
                          );
                          return;
                        }
                        final tables = int.tryParse(_tablesController.text) ?? widget.event.tables;
                        final seats = int.tryParse(_seatsController.text) ?? widget.event.seatsPerTable;
                        final updated = widget.event.copyWith(
                          name: name,
                          venue: _venueController.text.trim().isNotEmpty
                              ? _venueController.text.trim()
                              : widget.event.venue,
                          description: _descriptionController.text.trim(),
                          startTime: _startTimeController.text.trim().isNotEmpty
                              ? _startTimeController.text.trim()
                              : widget.event.startTime,
                          endTime: _endTimeController.text.trim().isNotEmpty
                              ? _endTimeController.text.trim()
                              : widget.event.endTime,
                          tables: tables,
                          seatsPerTable: seats,
                          totalCapacity: tables * seats,
                          imageUrl: _bannerImagePath ?? widget.event.imageUrl,
                          latitude: _latitude ?? widget.event.latitude,
                          longitude: _longitude ?? widget.event.longitude,
                          venueAddress: _formattedAddress ??
                              (_venueController.text.trim().isNotEmpty
                                  ? _venueController.text.trim()
                                  : widget.event.venueAddress),
                          city: _city ?? widget.event.city,
                          date: _selectedDate,
                          isFeatured: _isFeatured,
                        );

                        final saved = await ApiService.instance.updateEvent(updated);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Updated "${saved.name}" successfully'),
                              backgroundColor: AppTheme.accentLime,
                            ),
                          );
                          Navigator.pop(context, saved);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.accentLime
                            : AppTheme.primaryBlack,
                        foregroundColor:
                            isDark ? AppTheme.primaryBlack : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save changes'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
