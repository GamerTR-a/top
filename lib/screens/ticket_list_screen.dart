import 'package:flutter/material.dart';
import '../models/ticket_model.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_widget.dart';
import 'ticket_create_screen.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final _dataService = SupabaseDataService();
  List<UserTicket> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tickets = await _dataService.getMyTickets();
      if (mounted) {
        setState(() {
          _tickets = tickets;
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
    final theme = themeNotifier.value;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Geri',
        ),
        title: Text(
          'Taleplerim ve Şikayetlerim',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.primary),
            onPressed: _loadTickets,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _buildBody(theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TicketCreateScreen()),
          );
          if (created == true && mounted) {
            _loadTickets();
          }
        },
        backgroundColor: theme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Talep'),
      ),
    );
  }

  Widget _buildBody(AppTheme theme) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: theme.primary),
      );
    }

    if (_error != null) {
      return _buildErrorState(theme);
    }

    if (_tickets.isEmpty) {
      return _buildEmptyState(theme);
    }

    return RefreshIndicator(
      onRefresh: _loadTickets,
      color: theme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final ticket = _tickets[index];
          return _buildTicketCard(ticket, theme);
        },
      ),
    );
  }

  Widget _buildEmptyState(AppTheme theme) {
    return EmptyStateWidget(
      icon: Icons.assignment_outlined,
      title: 'Henüz talep veya şikayet yok',
      message: 'Uygulama içi soru, istek veya şikayetlerinizi buradan iletebilirsiniz.',
      actionLabel: 'Yeni Talep Oluştur',
      onActionPressed: () async {
        final created = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TicketCreateScreen()),
        );
        if (created == true && mounted) {
          _loadTickets();
        }
      },
    );
  }

  Widget _buildErrorState(AppTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: theme.error),
            const SizedBox(height: 16),
            Text(
              'Talepler yüklenemedi',
              style: TextStyle(color: theme.error, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: theme.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadTickets,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(UserTicket ticket, AppTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Type badge + status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ticket.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ticket.typeIcon, size: 14, color: ticket.statusColor),
                      const SizedBox(width: 4),
                      Text(
                        ticket.typeDisplayName,
                        style: TextStyle(
                          color: ticket.statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ticket.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ticket.statusDisplayName,
                    style: TextStyle(
                      color: ticket.statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Subject
            Text(
              ticket.subject,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            // Description (truncated)
            Text(
              ticket.description,
              style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Date and admin notes indicator
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: theme.textMuted),
                const SizedBox(width: 6),
                Text(
                  _formatDate(ticket.createdAt),
                  style: TextStyle(color: theme.textMuted, fontSize: 11),
                ),
                if (ticket.adminNotes != null && ticket.adminNotes!.isNotEmpty) ...[
                  const Spacer(),
                  Icon(Icons.admin_panel_settings, size: 14, color: theme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Yönetici yanıtı var',
                    style: TextStyle(color: theme.primary, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
            if (ticket.adminNotes != null && ticket.adminNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_pin_circle, size: 16, color: theme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Yönetici Notu',
                          style: TextStyle(
                            color: theme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ticket.adminNotes!,
                      style: TextStyle(color: theme.textColor, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Güncelleme: ${_formatDate(ticket.updatedAt)}',
                      style: TextStyle(color: theme.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) {
      return '${diff.inDays} gün önce';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} saat önce';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} dakika önce';
    }
    return 'Az önce';
  }
}