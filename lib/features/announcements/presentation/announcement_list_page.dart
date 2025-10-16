import 'package:flutter/material.dart';
import '../../../../services/announcement_service.dart';
import '../../../../models/announcement.dart';
import 'announcement_detail_page.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/utils/nav.dart';

class AnnouncementListPage extends StatefulWidget {
  const AnnouncementListPage({super.key});

  @override
  State<AnnouncementListPage> createState() => _AnnouncementListPageState();
}

class _AnnouncementListPageState extends State<AnnouncementListPage> {
  late Stream<List<Announcement>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = AnnouncementService.instance.streamAnnouncements();
  }

  Future<void> _refresh() async {
    setState(() {
      _stream = AnnouncementService.instance.streamAnnouncements();
    });
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Announcements',
      currentLabel: 'Announcements',
      body: StreamBuilder<List<Announcement>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 64),
                children: const [Center(child: Text('No announcements'))],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final a = items[index];
                final posted = a.createdAt?.toLocal().toString().substring(
                  0,
                  16,
                );
                final color = Theme.of(context).colorScheme.primary;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Nav.pushWithRole(
                    context,
                    AnnouncementDetailPage(announcement: a),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.campaign, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                a.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (posted != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              posted,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      // keep fab
    );
  }
}

/* Original FAB preserved for reference
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final created = await Navigator.of(context).push<Announcement?>(
            MaterialPageRoute(builder: (_) => const AnnouncementEditPage()),
          );
          if (created != null) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Announcement created')),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
*/
