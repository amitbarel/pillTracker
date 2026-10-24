import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../describe.dart';
import '../instructions.dart';
import '../l10n.dart';
import '../models.dart';
import '../ocr.dart';
import '../scope.dart';
import '../theme.dart';
import 'common.dart';

class EditMedicineScreen extends StatefulWidget {
  const EditMedicineScreen({super.key, this.medicine});

  /// Null when adding a new one.
  final Medicine? medicine;

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _dose;
  late final TextEditingController _notes;
  late Set<Anchor> _anchors;
  late FoodRelation _food;
  DateTime? _endDate;
  String? _photoPath;

  /// Photos taken in this screen that end up unused get deleted.
  final _newPhotos = <String>[];

  bool _reading = false;
  bool _readingSticker = false;
  List<String>? _candidates;
  bool _showAnchorError = false;

  /// How many times a day, from "How often?". The times chosen must match it.
  late int _perDay;

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    _name = TextEditingController(text: m?.name ?? '');
    _dose = TextEditingController(text: m?.dose ?? '');
    _notes = TextEditingController(text: m?.notes ?? '');
    _anchors = {...?m?.anchors};
    if (m == null) _anchors = {...Preset.twice.anchors};
    _perDay = _anchors.isEmpty ? 1 : _anchors.length;
    _food = m?.food ?? FoodRelation.after;
    _endDate = m?.endDate;
    _photoPath = m?.photoPath;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.medicine == null && _dose.text.isEmpty) {
      _dose.text = S.of(context)['defaultDose'];
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final photos = Directory('${dir.path}/photos');
    await photos.create(recursive: true);
    final path = '${photos.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(path);
    _newPhotos.add(path);
    setState(() {
      _photoPath = path;
      _reading = true;
      _candidates = null;
    });
    var names = const <String>[];
    try {
      names = nameCandidates(await readLabel(path));
    } catch (e) {
      debugPrint('Label reading failed: $e');
    }
    try {
      if (!mounted) return;
      if (names.isEmpty) {
        // Back to the camera button, so trying again is one tap.
        setState(() => _candidates = null);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(S.of(context)['unreadable'])));
        return;
      }
      // The best guess goes straight into the name; the rest stay as chips.
      _name.text = names.first;
      setState(() => _candidates = names.length > 1 ? names : null);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  /// Photographs the pharmacy sticker and fills in how to take the medicine.
  /// The sticker photo itself isn't kept.
  Future<void> _readSticker() async {
    final s = S.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _readingSticker = true);
    var found = const Instructions();
    try {
      final lines = await readLabel(picked.path);
      found = parseInstructions(lines.map((l) => l.text).join('\n'));
    } catch (e) {
      debugPrint('Sticker reading failed: $e');
    } finally {
      _deleteQuietly(picked.path);
    }
    if (!mounted) return;
    setState(() {
      _readingSticker = false;
      if (found.isEmpty) return;
      final times = found.times;
      if (times != null) {
        _anchors = {...times};
        _perDay = times.length;
        _showAnchorError = false;
      }
      // A sticker that doesn't mention food means it doesn't matter.
      if (found.food != null || found.perDay != null) _food = found.food ?? FoodRelation.any;
      if (found.dose case final dose?) _dose.text = dose;
      if (found.days case final days?) {
        final start = dateOnly(widget.medicine?.startDate ?? DateTime.now());
        _endDate = start.add(Duration(days: days - 1));
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(found.isEmpty ? s['unreadable'] : s['stickerRead'])));
  }

  Future<void> _save() async {
    final validName = _form.currentState!.validate();
    final timesOk = _anchors.length == _perDay;
    setState(() => _showAnchorError = !timesOk);
    if (!validName || !timesOk) return;
    final state = Scope.of(context).state;
    final old = widget.medicine;
    final m = Medicine(
      id: old?.id ?? state.newMedicineId(),
      name: _name.text.trim(),
      photoPath: _photoPath,
      dose: _dose.text.trim().isEmpty
          ? S.of(context)['defaultDose']
          : _dose.text.trim(),
      anchors: _anchors,
      food: _food,
      notes: _notes.text.trim(),
      startDate: old?.startDate ?? dateOnly(DateTime.now()),
      endDate: _endDate,
    );
    // Clean up photos replaced while editing.
    for (final p in [..._newPhotos, ?old?.photoPath]) {
      if (p != _photoPath) _deleteQuietly(p);
    }
    _newPhotos.clear();
    await state.saveMedicine(m);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final s = S.of(context);
    final m = widget.medicine!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(s.f('deleteConfirm', {'name': m.name}),
            style: Theme.of(context).textTheme.bodyLarge),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(s['cancel'])),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.of(context).warn),
              onPressed: () => Navigator.pop(c, true),
              child: Text(s['delete'])),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await Scope.read(context).state.deleteMedicine(m);
    if (mounted) Navigator.of(context).pop();
  }

  void _deleteQuietly(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: dateOnly(now),
      lastDate: DateTime(now.year + 2),
      initialDate: _endDate ?? dateOnly(now).add(const Duration(days: 9)),
    );
    if (picked != null) setState(() => _endDate = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final routine = Scope.of(context).state.routine;
    // "At bedtime" and "Once a day" are both one time a day; the chosen times
    // say which one is meant.
    final selectedPreset = Preset.matching(_anchors) ??
        Preset.values.where((p) => p != Preset.bedtime && p.anchors.length == _perDay).firstOrNull;
    final full = _anchors.length >= _perDay;
    final hasMeal = _anchors.any((a) => a.isMeal);
    final text = Theme.of(context).textTheme;
    final field = text.titleMedium!.copyWith(fontWeight: FontWeight.w400);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _newPhotos.forEach(_deleteQuietly);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.medicine == null
              ? s['newMedicine']
              : s['editMedicine']),
          actions: [
            if (widget.medicine != null)
              IconButton(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                tooltip: s['delete'],
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              key: const Key('save'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60)),
              onPressed: _save,
              child: Text(s['save']),
            ),
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _photoSection(s),
              const SizedBox(height: 18),
              TextFormField(
                key: const Key('nameField'),
                controller: _name,
                style: field,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                    labelText: s['name'], hintText: s['nameHint']),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? s['nameRequired']
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dose,
                style: field,
                decoration: InputDecoration(
                    labelText: s['eachTime'], hintText: s['doseHint']),
              ),
              SectionTitle(s['howOften']),
              _readingSticker
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(children: [
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5)),
                        const SizedBox(width: 10),
                        Text(s['readingSticker'], style: text.bodyMedium),
                      ]),
                    )
                  : OutlinedButton.icon(
                      key: const Key('readSticker'),
                      onPressed: _readSticker,
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: Text(s['readSticker']),
                    ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in Preset.values)
                  ChoiceChip(
                    label: Text(presetName(s, p)),
                    selected: selectedPreset == p,
                    onSelected: (_) => setState(() {
                      _anchors = {...p.anchors};
                      _perDay = p.anchors.length;
                      _showAnchorError = false;
                    }),
                  ),
              ]),
              const SizedBox(height: 12),
              Text(
                  _perDay == 1
                      ? s['pickOneTime']
                      : s.f('pickTimes', {'n': _perDay, 'chosen': _anchors.length}),
                  style: text.bodyMedium),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in Anchor.values)
                  FilterChip(
                    key: Key('anchor.${a.name}'),
                    label: Text(anchorName(s, a)),
                    selected: _anchors.contains(a),
                    // Once a day swaps the time; otherwise a time has to be
                    // unticked before another can be picked.
                    onSelected: !_anchors.contains(a) && full && _perDay > 1
                        ? null
                        : (on) => setState(() {
                              if (on && _perDay == 1) {
                                _anchors = {a};
                              } else {
                                _anchors = {..._anchors};
                                on ? _anchors.add(a) : _anchors.remove(a);
                              }
                              _showAnchorError = false;
                            }),
                  ),
              ]),
              if (_showAnchorError)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      _perDay == 1 ? s['pickATime'] : s.f('pickExactly', {'n': _perDay}),
                      style: text.bodyMedium!.copyWith(
                          color: Theme.of(context).colorScheme.error)),
                ),
              if (hasMeal) ...[
                SectionTitle(s['food']),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final f in FoodRelation.values)
                    ChoiceChip(
                      label: Text(foodName(s, f)),
                      selected: _food == f,
                      onSelected: (_) => setState(() => _food = f),
                    ),
                ]),
              ],
              if (_anchors.isNotEmpty) ...[
                const SizedBox(height: 18),
                _preview(s, routine),
              ],
              SectionTitle(s['forHowLong']),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(
                  label: Text(s['noEnd']),
                  selected: _endDate == null,
                  onSelected: (_) => setState(() => _endDate = null),
                ),
                ChoiceChip(
                  label: Text(_endDate == null
                      ? s.f('untilDate', {'date': '…'})
                      : s.f('untilDate', {'date': shortDate(s, _endDate!)})),
                  selected: _endDate != null,
                  onSelected: (_) => _pickEndDate(),
                ),
              ]),
              const SizedBox(height: 18),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                style: text.bodyLarge,
                decoration: InputDecoration(
                    labelText: s['notes'], hintText: s['notesHint']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoSection(S s) {
    final candidates = _candidates;
    final secondary = Theme.of(context).textTheme.bodyMedium;
    final m = widget.medicine;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _pickPhoto(ImageSource.camera),
          child: Stack(alignment: Alignment.center, children: [
            MedicinePhoto(
              path: _photoPath,
              size: 120,
              radius: 16,
              heroTag: m == null ? null : MedicinePhoto.tagFor(m.id),
            ),
            if (_photoPath == null)
              Icon(Icons.photo_camera, size: 40, color: AppColors.of(context).muted),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_reading)
                Row(children: [
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(s['readingLabel'], style: secondary)),
                ])
              else if (candidates != null) ...[
                Text(s['foundOnBox'], style: secondary),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in candidates)
                    ChoiceChip(
                      label: Text(c),
                      selected: _name.text.trim() == c,
                      onSelected: (_) => setState(() => _name.text = c),
                    ),
                ]),
              ] else ...[
                FilledButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: Text(_photoPath == null
                      ? s['takePhoto']
                      : s['retakePhoto']),
                ),
              ],
              TextButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(s['fromGallery']),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// "Reminders will ring at: Weekdays 7:00 and 19:30 …"
  Widget _preview(S s, Routine routine) {
    String times(DayRoutine day) {
      final list = [
        for (final a in Anchor.values)
          if (_anchors.contains(a)) _at(day, a),
      ];
      if (list.length == 1) return list.first;
      final and = s.isHebrew ? s['and'] : '${s['and']} ';
      return '${list.sublist(0, list.length - 1).join(', ')} $and${list.last}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s['remindersAt'], style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            _previewRow(s['weekdays'], times(routine.weekday)),
            const SizedBox(height: 4),
            _previewRow(s['weekends'], times(routine.weekend)),
          ],
        ),
      ),
    );
  }

  String _at(DayRoutine day, Anchor a) {
    final base = day[a];
    final offset = a.isMeal ? _food.offsetMinutes : 0;
    final t = DateTime(2000, 1, 1, base.hour, base.minute)
        .add(Duration(minutes: offset));
    return clock(t);
  }

  Widget _previewRow(String label, String value) {
    final body = Theme.of(context).textTheme.bodyLarge!;
    return Row(children: [
      Expanded(child: Text(label, style: body)),
      Flexible(
        child: Text(value,
            textAlign: TextAlign.end,
            style: body.copyWith(fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}
