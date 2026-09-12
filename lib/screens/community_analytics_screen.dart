import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/topluluk.dart';
import '../models/auth_user_model.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';

class CommunityAnalyticsScreen extends StatefulWidget {
  final Topluluk topluluk;
  final AuthUser currentUser;
  const CommunityAnalyticsScreen({super.key, required this.topluluk, required this.currentUser});

  @override
  State<CommunityAnalyticsScreen> createState() => _CommunityAnalyticsScreenState();
}

class _CommunityAnalyticsScreenState extends State<CommunityAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final _svc = SupabaseDataService();

  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _memberTrend = [];
  List<Map<String, dynamic>> _postActivity = [];
  List<Map<String, dynamic>> _topMembers = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _svc.getCommunityStats(widget.topluluk.id),
        _svc.getMemberGrowthTrend(widget.topluluk.id),
        _svc.getPostActivityTrend(widget.topluluk.id),
        _svc.getTopActiveMembers(widget.topluluk.id, limit: 10),
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _memberTrend = results[1] as List<Map<String, dynamic>>;
          _postActivity = results[2] as List<Map<String, dynamic>>;
          _topMembers = results[3] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analitik verileri yüklenemedi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return AnimatedThemeBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: theme.surface.withValues(alpha: 0.4),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text('Analitik', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 17)),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh, color: theme.primary),
                  onPressed: _loadAnalytics,
                  tooltip: 'Yenile',
                ),
              ],
            ),
            body: _loading
                ? Center(child: CircularProgressIndicator(color: theme.primary))
                : RefreshIndicator(
                    onRefresh: _loadAnalytics,
                    color: theme.primary,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Title
                        Text(
                          widget.topluluk.ad,
                          style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Topluluk performansı ve üye etkileşimi',
                          style: TextStyle(color: theme.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 20),

                        // Key Metrics
                        _buildMetricsGrid(theme),
                        const SizedBox(height: 24),

                        // Member Growth Chart
                        _buildSectionTitle(theme, 'Üye Büyüme Trendi (30 gün)'),
                        const SizedBox(height: 12),
                        _buildMemberTrendChart(theme),
                        const SizedBox(height: 24),

                        // Post Activity Chart
                        _buildSectionTitle(theme, 'Gönderi Aktivitesi (7 gün)'),
                        const SizedBox(height: 12),
                        _buildPostActivityChart(theme),
                        const SizedBox(height: 24),

                        // Top Active Members
                        _buildSectionTitle(theme, 'En Aktif Üyeler'),
                        const SizedBox(height: 12),
                        _buildTopMembers(theme),
                        const SizedBox(height: 24),

                        // Engagement Summary
                        _buildSectionTitle(theme, 'Etkileşim Özeti'),
                        const SizedBox(height: 12),
                        _buildEngagementSummary(theme),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildMetricsGrid(AppTheme theme) {
    final metricCards = [
      _MetricCard(
        theme: theme,
        icon: Icons.people_alt_rounded,
        label: 'Toplam Üye',
        value: _stats['total_members']?.toString() ?? '0',
        color: theme.primary,
      ),
      _MetricCard(
        theme: theme,
        icon: Icons.article_rounded,
        label: 'Toplam Gönderi',
        value: _stats['total_posts']?.toString() ?? '0',
        color: theme.secondary,
      ),
      _MetricCard(
        theme: theme,
        icon: Icons.thumb_up_rounded,
        label: 'Toplam Destek',
        value: _stats['total_support']?.toString() ?? '0',
        color: theme.warning,
      ),
      _MetricCard(
        theme: theme,
        icon: Icons.star_rounded,
        label: 'Ortalama Puan',
        value: (_stats['avg_rating'] as num? ?? 0).toStringAsFixed(1),
        color: Colors.amber,
      ),
      _MetricCard(
        theme: theme,
        icon: Icons.event_rounded,
        label: 'Etkinlik',
        value: _stats['total_events']?.toString() ?? '0',
        color: Colors.purple,
      ),
      _MetricCard(
        theme: theme,
        icon: Icons.trending_up_rounded,
        label: 'Aktif Üye %',
        value: '${((_stats['active_member_rate'] as num? ?? 0) * 100).toStringAsFixed(0)}%',
        color: Colors.teal,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: metricCards.length,
      itemBuilder: (context, index) => metricCards[index],
    );
  }

  Widget _buildSectionTitle(AppTheme theme, String title) {
    return Text(
      title,
      style: TextStyle(color: theme.textColor, fontSize: 15, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildMemberTrendChart(AppTheme theme) {
    if (_memberTrend.isEmpty) {
      return _emptyChart(theme);
    }

    final spots = _memberTrend.asMap().entries.map((e) {
      final d = e.value;
      final count = (d['count'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), count);
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.textMuted.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: theme.textMuted, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: theme.primary,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                color: theme.primary.withValues(alpha: 0.2),
              ),
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostActivityChart(AppTheme theme) {
    if (_postActivity.isEmpty) {
      return _emptyChart(theme);
    }

    final bars = _postActivity.map((d) {
      final count = (d['count'] as num?)?.toDouble() ?? 0;
      return count;
    }).toList();

    final maxY = bars.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.textMuted.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: theme.textMuted, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= _postActivity.length) return const Text('');
                  final label = _postActivity[idx]['label'] as String? ?? '';
                  return Text(label, style: TextStyle(color: theme.textMuted, fontSize: 9));
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: bars.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value,
                  color: theme.secondary,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _emptyChart(AppTheme theme) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Text('Veri yok', style: TextStyle(color: theme.textMuted)),
      ),
    );
  }

  Widget _buildTopMembers(AppTheme theme) {
    if (_topMembers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
        ),
        child: Center(child: Text('Henüz aktif üye yok', style: TextStyle(color: theme.textMuted))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topMembers.length,
        separatorBuilder: (_, index) => Divider(
          color: theme.primary.withValues(alpha: 0.1),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final m = _topMembers[index];
          final profile = m['profile'] as Map<String, dynamic>? ?? {};
          final name = profile['name'] as String? ?? 'Bilinmeyen';
          final photo = profile['profile_photo'] as String?;
          final postCount = (m['post_count'] as num?)?.toInt() ?? 0;
          final supportCount = (m['support_count'] as num?)?.toInt() ?? 0;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.primary.withValues(alpha: 0.2),
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null ? Icon(Icons.person, color: theme.primary) : null,
            ),
            title: Text(name, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('$postCount gönderi · $supportCount destek',
                style: TextStyle(color: theme.textMuted, fontSize: 11)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('#${index + 1}', style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEngagementSummary(AppTheme theme) {
    final totalMembers = (_stats['total_members'] as num? ?? 0).toInt();
    final activeMembers = (_stats['active_members'] as num? ?? 0).toInt();
    final totalPosts = (_stats['total_posts'] as num? ?? 0).toInt();
    final totalSupport = (_stats['total_support'] as num? ?? 0).toInt();

    final postsPerMember = totalMembers > 0 ? totalPosts / totalMembers : 0.0;
    final supportPerPost = totalPosts > 0 ? totalSupport / totalPosts : 0.0;
    final activeRate = totalMembers > 0 ? activeMembers / totalMembers : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _EngagementRow(
            theme: theme,
            label: 'Üye başına gönderi',
            value: postsPerMember.toStringAsFixed(2),
            percentage: postsPerMember * 100,
          ),
          const SizedBox(height: 12),
          _EngagementRow(
            theme: theme,
            label: 'Gönderi başına destek',
            value: supportPerPost.toStringAsFixed(1),
            percentage: supportPerPost * 10,
          ),
          const SizedBox(height: 12),
          _EngagementRow(
            theme: theme,
            label: 'Aktif üye oranı',
            value: '${(activeRate * 100).toStringAsFixed(1)}%',
            percentage: activeRate * 100,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _EngagementRow extends StatelessWidget {
  final AppTheme theme;
  final String label;
  final String value;
  final double percentage;

  const _EngagementRow({
    required this.theme,
    required this.label,
    required this.value,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: theme.textColor, fontSize: 13, fontWeight: FontWeight.w500)),
            Text(value, style: TextStyle(color: theme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percentage.clamp(0.0, 100.0) / 100.0,
          backgroundColor: theme.primary.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
          minHeight: 6,
        ),
      ],
    );
  }
}