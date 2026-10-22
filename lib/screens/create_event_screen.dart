import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/location_picker_modal.dart';
import '../models/event_model.dart';
import '../services/api_service.dart';
import '../services/media_helper.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
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
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  double _latitude = -1.286389; // Nairobi, Kenya
  double _longitude = 36.817223;
  String? _selectedCity = 'Nairobi';
  String? _formattedAddress;
  bool _isFeatured = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();
    _venueController = TextEditingController();
    _tablesController = TextEditingController();
    _seatsController = TextEditingController();
  }

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
      initialTime: _startTime ?? const TimeOfDay(hour: 18, minute: 0),
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
      initialTime: _endTime ?? const TimeOfDay(hour: 21, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _endTimeController.text = _formatTime(picked);
      });
    }
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
          'Create event',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text(
              'Save draft',
              style: TextStyle(
                color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel(text: 'NEW EVENT'),
                Text(
                  'Set the scene. Add your event details, then invite your guests to the table.',
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
                if (_bannerImagePath == null)
                  InkWell(
                    onTap: () async {
                      final path = await MediaHelper.pickAndCropImage(
                        context,
                        cropType: CropPresetType.eventBanner,
                      );
                      if (path != null) {
                        setState(() => _bannerImagePath = path);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkCard
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.accentLime.withValues(alpha: 0.35)
                              : AppTheme.primaryPurple.withValues(alpha: 0.30),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.accentLime.withValues(alpha: 0.15)
                                  : AppTheme.primaryPurple.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 32,
                              color: isDark
                                  ? AppTheme.accentLime
                                  : AppTheme.primaryPurple,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Upload Event Cover Image',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to choose a photo from gallery or camera',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? AppTheme.darkTextTertiary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E212D)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.darkCardBorder
                                    : AppTheme.borderLight,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.file_upload_outlined,
                                  size: 14,
                                  color: isDark
                                      ? AppTheme.accentLime
                                      : AppTheme.primaryPurple,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Browse image',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppTheme.accentLime
                                        : AppTheme.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SafeNetworkImage(
                          imageUrl: _bannerImagePath!,
                          width: double.infinity,
                          height: 180,
                          borderRadius: BorderRadius.circular(16),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() => _bannerImagePath = null);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_outline,
                                        size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'Remove',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
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
                                      color: Colors.black.withAlpha(isDark ? 60 : 20),
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
                                      'Change image',
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
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                Text(
                  _bannerImagePath != null
                      ? 'Custom cover image selected'
                      : 'No image selected · tap to upload an event banner',
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
                  decoration: const InputDecoration(
                    hintText: 'Enter event name (e.g. Kenya Tech Summit)',
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
                  decoration: InputDecoration(
                    hintText: 'Help guests know what your event is about...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextTertiary
                          : const Color(0xFF94A3B8),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                    alignLabelWithHint: true,
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
                      readOnly: true,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Start/End Time
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
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 18:00',
                                  suffixIcon: Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: isDark
                                        ? AppTheme.accentLime
                                        : AppTheme.primaryPurple,
                                  ),
                                ),
                                readOnly: true,
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
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 21:00',
                                  suffixIcon: Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: isDark
                                        ? AppTheme.accentLime
                                        : AppTheme.primaryPurple,
                                  ),
                                ),
                                readOnly: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Venue
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
                    hintText: 'Enter venue or pick on Kenya map (e.g. KICC, Nairobi)',
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.map_outlined,
                        size: 20,
                        color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                      ),
                      tooltip: 'Pick location on Kenya map',
                      onPressed: () async {
                        final result = await LocationPickerModal.show(
                          context,
                          initialLatitude: _latitude,
                          initialLongitude: _longitude,
                          initialAddress: _venueController.text.isNotEmpty
                              ? _venueController.text
                              : 'Nairobi, Kenya',
                        );
                        if (result != null) {
                          setState(() {
                            _venueController.text = result.address;
                            _latitude = result.latitude;
                            _longitude = result.longitude;
                            _formattedAddress = result.address;
                            if (result.city != null && result.city!.isNotEmpty) {
                              _selectedCity = result.city;
                            }
                          });
                        }
                      },
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
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
                        _venueController.text.trim().isNotEmpty
                            ? 'Venue: ${_venueController.text.trim()} · Lat: ${_latitude.toStringAsFixed(4)}, Lon: ${_longitude.toStringAsFixed(4)}'
                            : 'Kenya map focus (${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)})',
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
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 10',
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
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 8',
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
                  text: _totalSeats > 0
                      ? '$_totalSeats total seats / passes'
                      : 'Capacity not configured',
                  subtext: _totalSeats > 0
                      ? '$_totalSeats available when the event is created'
                      : 'Enter tables and seats above to calculate capacity',
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
                const SizedBox(height: 28),

                // Create Button
                SizedBox(
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
                      final tables = int.tryParse(_tablesController.text) ?? 1;
                      final seats = int.tryParse(_seatsController.text) ?? 1;
                      final venue = _venueController.text.trim().isNotEmpty
                          ? _venueController.text.trim()
                          : 'Nairobi Venue TBA';
                      final venueAddress = _formattedAddress ??
                          (_venueController.text.trim().isNotEmpty
                              ? _venueController.text.trim()
                              : 'Nairobi, Kenya');
                      final newEvent = EventModel(
                        id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        venue: venue,
                        venueAddress: venueAddress,
                        collection: 'KENYA & REGIONAL EVENTS',
                        description: _descriptionController.text.trim(),
                        date: _selectedDate,
                        startTime: _startTimeController.text.isNotEmpty
                            ? _startTimeController.text
                            : '18:00',
                        endTime: _endTimeController.text.isNotEmpty
                            ? _endTimeController.text
                            : '21:00',
                        doorsOpenTime: '17:30',
                        tables: tables,
                        seatsPerTable: seats,
                        totalCapacity: tables * seats,
                        passesIssued: 0,
                        checkedIn: 0,
                        status: EventStatus.upcoming,
                        isPaid: false,
                        priceBadge: 'Free',
                        imageUrl: _bannerImagePath ?? 'assets/images/event_keynote_stage.jpg',
                        latitude: _latitude,
                        longitude: _longitude,
                        geoNode: 'KE-Nairobi-Central',
                        city: _selectedCity ?? 'Nairobi',
                        isFeatured: _isFeatured,
                      );

                      await ApiService.instance.createEvent(newEvent);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Created "${newEvent.name}" successfully!'),
                            backgroundColor: AppTheme.accentLime,
                          ),
                        );
                        Navigator.pop(context, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? AppTheme.accentLime : AppTheme.primaryBlack,
                      foregroundColor:
                          isDark ? AppTheme.primaryBlack : Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create event'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Invitations are only sent when you choose to share.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.darkTextTertiary
                              : AppTheme.textSecondary,
                        ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
