import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/horoscope_model.dart';
import '../../models/user_profile.dart';
import '../../services/horoscope_sync_service.dart';
import '../../services/storage_service.dart';
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
  UserProfile _userProfile = UserProfile.defaultProfile();

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
      final profile = await StorageService.loadProfile();
      if (mounted) {
        setState(() {
          _archiveList = items;
          _userProfile = profile;
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.archiveScreenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CosmicTheme.cyanAccent),
            tooltip: l10n.refreshArchiveTooltip,
            onPressed: _loadArchive,
          ),
        ],
      ),
      body: CosmicBackground(
        child: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
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
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_archiveList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, color: CosmicTheme.goldSoft, size: 54),
            const SizedBox(height: 16),
            Text(
              l10n.archiveEmpty,
              style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 15),
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
              l10n.forecastForDate(item.date),
              style: const TextStyle(
                color: CosmicTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _formatArchivePreview(item.preview, _userProfile, l10n.langCode),
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

  String _formatArchivePreview(String rawPreview, UserProfile profile, String langCode) {
    if (!profile.isRegistered) return rawPreview;
    return profile.formatGreeting(rawPreview, langCode: langCode);
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
  UserProfile _userProfile = UserProfile.defaultProfile();

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  Future<void> _loadDay() async {
    try {
      final d = await HoroscopeSyncService.fetchArchiveDay(widget.item.isoDate, widget.item.date);
      final profile = await StorageService.loadProfile();
      if (mounted) {
        setState(() {
          _day = d;
          _userProfile = profile;
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
    final l10n = AppLocalizations.of(context);
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
                      l10n.archiveForDate(widget.item.date),
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
                child: _buildContent(scrollController, l10n),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController controller, AppLocalizations l10n) {
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
            _error ?? l10n.archiveError,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CosmicTheme.roseGlow),
          ),
        ),
      );
    }

    final langCode = AppLocalizations.of(context).langCode;
    return ListView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      children: [
        GreetingHeader(
          greetingText: _userProfile.formatGreeting(_day!.greeting, langCode: langCode),
          dateStr: _day!.date,
          isLoading: false,
          onRefresh: _loadDay,
        ),
        ..._day!.topics.asMap().entries.map((entry) {
          final personalizedTopic = HoroscopeTopic(
            title: entry.value.title,
            content: _userProfile.formatTopicContent(entry.value.content, langCode: langCode),
            icon: entry.value.icon,
          );
          return TopicCard(
            topic: personalizedTopic,
            index: entry.key,
          );
        }),
        const SizedBox(height: 32),
      ],
    );
  }
}
