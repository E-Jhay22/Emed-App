import 'package:flutter/material.dart';
import '../../../../models/announcement.dart';
import '../../../../services/announcement_service.dart';

class AnnouncementEditPage extends StatefulWidget {
  final Announcement? announcement;
  const AnnouncementEditPage({super.key, this.announcement});

  @override
  State<AnnouncementEditPage> createState() => _AnnouncementEditPageState();
}

class _AnnouncementEditPageState extends State<AnnouncementEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtl;
  late TextEditingController _bodyCtl;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final a = widget.announcement;
    _titleCtl = TextEditingController(text: a?.title ?? '');
    _bodyCtl = TextEditingController(text: a?.body ?? '');
    _startsAt = a?.startsAt;
    _endsAt = a?.endsAt;
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _bodyCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final title = _titleCtl.text.trim();
      final body = _bodyCtl.text.trim();
      if (widget.announcement == null) {
        final a = Announcement(
          id: 'local-temp',
          title: title,
          body: body,
          startsAt: _startsAt,
          endsAt: _endsAt,
          createdBy: '',
        );
        await AnnouncementService.instance.createAnnouncement(a);
        if (!mounted) return;
        Navigator.of(context).pop(a);
      } else {
        final changes = {
          'title': title,
          'body': body,
          'starts_at': _startsAt?.toIso8601String(),
          'ends_at': _endsAt?.toIso8601String(),
        };
        await AnnouncementService.instance.updateAnnouncement(
          widget.announcement!.id,
          changes,
        );
        final updated = Announcement(
          id: widget.announcement!.id,
          title: title,
          body: body,
          startsAt: _startsAt,
          endsAt: _endsAt,
          createdBy: widget.announcement!.createdBy,
        );
        if (!mounted) return;
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.announcement != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Announcement' : 'Create Announcement'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleCtl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _bodyCtl,
                decoration: const InputDecoration(labelText: 'Body'),
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final dt = await showDatePicker(
                        context: context,
                        initialDate: _startsAt ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (dt != null) setState(() => _startsAt = dt);
                    },
                    child: const Text('Set Start'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final dt = await showDatePicker(
                        context: context,
                        initialDate: _endsAt ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (dt != null) setState(() => _endsAt = dt);
                    },
                    child: const Text('Set End'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _save,
                      child: Text(isEdit ? 'Save' : 'Create'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
