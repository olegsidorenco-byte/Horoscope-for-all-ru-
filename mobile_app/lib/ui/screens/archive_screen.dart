import 'package:flutter/material.dart';
import '../../models/horoscope_model.dart';
import '../../services/horoscope_sync_service.dart';
import '../theme/cosmic_theme.dart';
import '../widgets/cosmic_background.dart';
import '../widgets/greeting_header.dart';
import '../widgets/topic_card.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<ArchiveIndexItem> _archiveList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  Future<void> _loadArchive() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await HoroscopeSyncService.fetchArchiveIndex();
      if (mounted) {
        setState(() {
          _archiveList = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось загрузить архив: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _openArchiveDay(ArchiveIndexItem item) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ArchiveDayViewer(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Архив гороскопов по дням'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CosmicTheme.cyanAccent),
            tooltip: 'Обновить архив',
            onPressed: _loadArchive,
          ),
        ],
      ),
      body: CosmicBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: CosmicTheme.goldAccent),
      );
    }

    if (_error != null && _archiveList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: CosmicTheme.roseGlow, size: 50),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CosmicTheme.textPrimary),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadArchive,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_archiveList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, color: CosmicTheme.goldSoft, size: 54),
            SizedBox(height: 16),
            Text(
              'В архиве пока нет сохраненных дней.',
              style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _archiveList.length,
      itemBuilder: (context, index) {
        final item = _archiveList[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: CosmicTheme.backgroundCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CosmicTheme.goldAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CosmicTheme.goldAccent.withOpacity(0.3)),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.calendar_today_rounded, color: CosmicTheme.goldAccent, size: 22),
            ),
            title: Text(
              'Гороскоп на ${item.date}',
              style: const TextStyle(
                color: CosmicTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                item.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 12.5),
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: CosmicTheme.textMuted, size: 16),
            onTap: () => _openArchiveDay(item),
          ),
        );
      },
    );
  }
}

class _ArchiveDayViewer extends StatefulWidget {
  final ArchiveIndexItem item;

  const _ArchiveDayViewer({required this.item});

  @override
  State<_ArchiveDayViewer> createState() => _ArchiveDayViewerState();
}

class _ArchiveDayViewerState extends State<_ArchiveDayViewer> {
  HoroscopeDay? _day;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  Future<void> _loadDay() async {
    try {
      final d = await HoroscopeSyncService.fetchArchiveDay(widget.item.isoDate, widget.item.date);
      if (mounted) {
        setState(() {
          _day = d;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: CosmicTheme.backgroundDeep,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Архив: ${widget.item.date}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: CosmicTheme.goldSoft,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: CosmicTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Expanded(
                child: _buildContent(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController controller) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: CosmicTheme.goldAccent),
      );
    }

    if (_error != null || _day == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error ?? 'Ошибка загрузки архивного дня',
            textAlign: TextAlign.center,
            style: const TextStyle(color: CosmicTheme.roseGlow),
          ),
        ),
      );
    }

    return ListView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      children: [
        GreetingHeader(
          greetingText: _day!.greeting,
          dateStr: _day!.date,
          isLoading: false,
          onRefresh: _loadDay,
        ),
        ..._day!.topics.asMap().entries.map((entry) {
          return TopicCard(
            topic: entry.value,
            index: entry.key,
          );
        }),
        const SizedBox(height: 32),
      ],
    );
  }
}
