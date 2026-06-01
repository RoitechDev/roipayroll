import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/auth_service.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/widgets/modern/index.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

enum _NotificationFilter { all, unread, approvals, finance, people, attendance, general }

class _FilterConfig {
  final _NotificationFilter filter;
  final String label;
  const _FilterConfig({required this.filter, required this.label});
}

class _NotificationSection {
  final String title;
  final List<AppNotification> items;
  const _NotificationSection({required this.title, required this.items});
}

class _NotificationRoleContext {
  final String title;
  final String subtitle;
  final bool canViewApprovals;
  final bool canViewFinance;
  final bool canViewPeople;
  final bool canViewAttendance;

  const _NotificationRoleContext({
    required this.title,
    required this.subtitle,
    required this.canViewApprovals,
    required this.canViewFinance,
    required this.canViewPeople,
    required this.canViewAttendance,
  });
}

class _SummaryCardData {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color bg;
  final Color fg;
  final bool dark;
  final bool dot;

  const _SummaryCardData({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.bg,
    required this.fg,
    this.dark = false,
    this.dot = false,
  });
}

class _BadgeData {
  final String label;
  final Color bg;
  final Color fg;
  const _BadgeData({required this.label, required this.bg, required this.fg});
}

class _RouteAction {
  final String label;
  final String route;
  const _RouteAction({required this.label, required this.route});
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _notificationService = NotificationService();
  final _authService = AuthService();
  _NotificationFilter _activeFilter = _NotificationFilter.all;

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid;
    final profileAsync = ref.watch(currentUserProvider);

    if (userId == null) {
      return AppScaffold(
        title: 'Notifications',
        showSearch: true,
        headerActions: const SizedBox.shrink(),
        child: const Center(
          child: ModernEmptyState(
            icon: Icons.lock_outline,
            title: 'Please login to view notifications',
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Notifications',
      showSearch: true,
      scrollable: false,
      padding: EdgeInsets.zero,
      headerActions: const SizedBox.shrink(),
      child: profileAsync.when(
        loading: () => const Center(
          child: ModernLoadingState(message: 'Loading notifications...'),
        ),
        error: (error, _) => Center(
          child: ModernErrorState(
            message: 'Failed to load notifications',
            subtitle: error.toString(),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: ModernEmptyState(
                icon: Icons.person_off_outlined,
                title: 'User profile unavailable',
                subtitle: 'Please sign in again to load your action center.',
              ),
            );
          }

          final roleContext = _roleContextFor(profile);
          final filters = _filtersForContext(roleContext);
          final activeFilter = filters.any((f) => f.filter == _activeFilter)
              ? _activeFilter
              : filters.first.filter;

          return StreamBuilder<List<AppNotification>>(
            stream: _notificationService.getUserNotificationsStream(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: ModernLoadingState(
                    message: 'Loading notification activity...',
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: ModernErrorState(
                    message: 'Failed to load notifications',
                    subtitle: snapshot.error.toString(),
                  ),
                );
              }

              final notifications = snapshot.data ?? const <AppNotification>[];
              final filtered = _applyFilter(notifications, activeFilter, roleContext);

              return _buildDashboard(
                profile: profile,
                userId: userId,
                notifications: notifications,
                filtered: filtered,
                roleContext: roleContext,
                filters: filters,
                activeFilter: activeFilter,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDashboard({
    required AppUser profile,
    required String userId,
    required List<AppNotification> notifications,
    required List<AppNotification> filtered,
    required _NotificationRoleContext roleContext,
    required List<_FilterConfig> filters,
    required _NotificationFilter activeFilter,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 1120;
        final padding = constraints.maxWidth >= 1400 ? 32.0 : constraints.maxWidth >= 900 ? 24.0 : 16.0;
        final maxWidth = constraints.maxWidth >= 1500 ? 1380.0 : 1280.0;
        final unread = notifications.where((n) => !n.isRead).length;
        final summaryCards = _buildSummaryCards(notifications, roleContext);

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(padding, 24, padding, 28),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(roleContext, unread, userId),
                    const SizedBox(height: 22),
                    if (split)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 280,
                            child: Column(
                              children: [
                                ...summaryCards.map((card) => Padding(
                                      padding: const EdgeInsets.only(bottom: 14),
                                      child: _buildSummaryCard(card),
                                    )),
                                _buildSecurityCard(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 22),
                          Expanded(
                            child: _buildFeed(
                              profile: profile,
                              notifications: notifications,
                              filtered: filtered,
                              filters: filters,
                              activeFilter: activeFilter,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      ...summaryCards.map((card) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildSummaryCard(card),
                          )),
                      _buildSecurityCard(),
                      const SizedBox(height: 18),
                      _buildFeed(
                        profile: profile,
                        notifications: notifications,
                        filtered: filtered,
                        filters: filters,
                        activeFilter: activeFilter,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    _NotificationRoleContext roleContext,
    int unreadCount,
    String userId,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        final titleSize = constraints.maxWidth < 720 ? 30.0 : 36.0;
        final button = SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: unreadCount == 0
                ? null
                : () async {
                    await _notificationService.markAllAsRead(userId);
                    if (!mounted) return;
                    NotificationHelper.showSuccess(
                      this.context,
                      'All notifications marked as read.',
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF071A34),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFB9C4D4),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: Text(
              unreadCount == 0 ? 'All caught up' : 'Mark all as read',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                roleContext.title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0A1730),
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                roleContext.subtitle,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              button,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleContext.title,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0A1730),
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    roleContext.subtitle,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            button,
          ],
        );
      },
    );
  }

  Widget _buildFeed({
    required AppUser profile,
    required List<AppNotification> notifications,
    required List<AppNotification> filtered,
    required List<_FilterConfig> filters,
    required _NotificationFilter activeFilter,
  }) {
    final sections = _groupNotifications(filtered);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterTabs(filters, activeFilter),
        const SizedBox(height: 18),
        if (notifications.isEmpty)
          _buildEmptyFeed(
            icon: Icons.notifications_none_rounded,
            title: 'No notifications yet',
            subtitle:
                'System events, approvals, and company updates will appear here as they happen.',
          )
        else if (filtered.isEmpty)
          _buildEmptyFeed(
            icon: Icons.filter_alt_off_rounded,
            title: 'No signals for this view',
            subtitle: 'Try another filter to see more recent activity.',
          )
        else
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: _buildSection(profile, section),
            ),
          ),
        const SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              const Text(
                'END OF RECENT UPDATES',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: Color(0xFF93A4BC),
                ),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () {
                  NotificationHelper.showInfo(
                    context,
                    'Archived notifications are not available yet.',
                  );
                },
                icon: const Icon(Icons.history_rounded),
                label: const Text('Load archived notifications'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs(
    List<_FilterConfig> filters,
    _NotificationFilter activeFilter,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filters.map((filter) {
          final selected = activeFilter == filter.filter;
          return InkWell(
            onTap: () => setState(() => _activeFilter = filter.filter),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0A1730).withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                filter.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? const Color(0xFF0A1730)
                      : const Color(0xFF3E4E64),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSection(AppUser profile, _NotificationSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: Color(0xFF8EA1BB),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Divider(thickness: 1, color: Color(0xFFE2E8F0)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...section.items.map(
          (notification) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildNotificationCard(profile, notification),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(AppUser profile, AppNotification notification) {
    final badge = _badgeFor(notification);
    final action = _routeActionFor(profile, notification);
    final accent = _notificationColor(notification.type);
    final unread = !notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        await _notificationService.deleteNotification(notification.id);
        if (!mounted) return;
        NotificationHelper.showSuccess(context, 'Notification deleted');
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            if (notification.isRead) return;
            await _notificationService.markAsRead(notification.id);
          },
          child: Ink(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: unread ? Colors.white : const Color(0xFFFCFDFE),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: unread
                    ? const Color(0xFFE7EDF6)
                    : const Color(0xFFF0F4F8),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A1730).withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 780;
                final main = _buildNotificationMain(
                  notification: notification,
                  accent: accent,
                  badge: badge,
                  unread: unread,
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      main,
                      if (action != null) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _openNotificationRoute(
                              notification,
                              action.route,
                            ),
                            child: Text(action.label),
                          ),
                        ),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: main),
                    if (action != null) ...[
                      const SizedBox(width: 18),
                      Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: TextButton(
                          onPressed: () => _openNotificationRoute(
                            notification,
                            action.route,
                          ),
                          child: Text(action.label),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationMain({
    required AppNotification notification,
    required Color accent,
    required _BadgeData badge,
    required bool unread,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(_notificationIcon(notification.type), color: accent, size: 28),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                        color: const Color(0xFF0A1730),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: badge.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: badge.fg,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                notification.message,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF334155),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _meta(Icons.schedule_rounded, timeago.format(notification.createdAt)),
                  _meta(_categoryIcon(notification.type), _categoryLabel(notification.type)),
                  if (unread)
                    _meta(Icons.fiber_manual_record, 'Unread', color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _meta(IconData icon, String label, {Color color = const Color(0xFF8B9BB2)}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(_SummaryCardData card) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: card.bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: card.dark ? Colors.transparent : const Color(0xFFE7EDF6),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1730).withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: card.dark
                        ? Colors.white.withValues(alpha: 0.72)
                        : const Color(0xFF8DA0BB),
                  ),
                ),
              ),
              if (card.dot) const Icon(Icons.circle, size: 10, color: AppColors.error),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: card.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : card.fg.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(card.icon, color: card.fg, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  card.value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: card.dark ? Colors.white : const Color(0xFF0A1730),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            card.detail,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: card.dark
                  ? Colors.white.withValues(alpha: 0.78)
                  : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFDDE7FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF1D4F9B)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Secure Environment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C3A63),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'All notifications and actions are encrypted. Your data integrity is monitored by the active company security controls.',
            style: TextStyle(
              fontSize: 14,
              height: 1.65,
              color: Color(0xFF34537F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFeed({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EDF6)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FB),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 34, color: const Color(0xFF48658C)),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A1730),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  List<_SummaryCardData> _buildSummaryCards(
    List<AppNotification> notifications,
    _NotificationRoleContext roleContext,
  ) {
    final unread = notifications.where((n) => !n.isRead);
    final unreadCount = unread.length;
    final approvals = notifications.where((n) => _isApprovalType(n.type)).length;
    final unreadApprovals = unread.where((n) => _isApprovalType(n.type)).length;
    final finance = notifications.where((n) => _isFinanceType(n.type)).length;
    final people = notifications.where((n) => _isPeopleType(n.type)).length;
    final attendance = notifications.where((n) => n.type == NotificationType.attendance).length;

    String thirdLabel;
    String thirdValue;
    String thirdDetail;
    IconData thirdIcon;
    Color thirdColor;

    if (roleContext.canViewApprovals) {
      thirdLabel = 'PENDING APPROVALS';
      thirdValue = approvals.toString().padLeft(2, '0');
      thirdDetail = unreadApprovals == 0
          ? 'No approval items require review right now.'
          : '$unreadApprovals approval item${unreadApprovals == 1 ? '' : 's'} still need attention.';
      thirdIcon = Icons.fact_check_outlined;
      thirdColor = const Color(0xFF316AFF);
    } else if (roleContext.canViewFinance) {
      thirdLabel = 'FINANCE SIGNALS';
      thirdValue = finance.toString().padLeft(2, '0');
      thirdDetail = finance == 0
          ? 'No finance updates are waiting in your feed.'
          : '$finance finance update${finance == 1 ? '' : 's'} are available in this feed.';
      thirdIcon = Icons.account_balance_wallet_outlined;
      thirdColor = AppColors.success;
    } else if (roleContext.canViewPeople) {
      thirdLabel = 'PEOPLE EVENTS';
      thirdValue = people.toString().padLeft(2, '0');
      thirdDetail = people == 0
          ? 'No new people or lifecycle events were detected.'
          : '$people people update${people == 1 ? '' : 's'} are available to review.';
      thirdIcon = Icons.groups_2_outlined;
      thirdColor = AppColors.info;
    } else {
      thirdLabel = 'ATTENDANCE ALERTS';
      thirdValue = attendance.toString().padLeft(2, '0');
      thirdDetail = attendance == 0
          ? 'No attendance-related alerts are waiting for you.'
          : '$attendance attendance alert${attendance == 1 ? '' : 's'} are in the current feed.';
      thirdIcon = Icons.access_time_rounded;
      thirdColor = AppColors.warning;
    }

    return [
      _SummaryCardData(
        label: 'TOTAL SIGNALS',
        value: notifications.length.toString(),
        detail: _monthlyTrendLabel(notifications),
        icon: Icons.notifications_active_outlined,
        bg: Colors.white,
        fg: const Color(0xFF35548A),
      ),
      _SummaryCardData(
        label: 'UNREAD ALERTS',
        value: unreadCount.toString(),
        detail: unreadCount == 0
            ? 'You are fully caught up right now.'
            : '$unreadCount item${unreadCount == 1 ? '' : 's'} require immediate attention.',
        icon: Icons.mark_email_unread_outlined,
        bg: const Color(0xFF071A34),
        fg: Colors.white,
        dark: true,
        dot: unreadCount > 0,
      ),
      _SummaryCardData(
        label: thirdLabel,
        value: thirdValue,
        detail: thirdDetail,
        icon: thirdIcon,
        bg: Colors.white,
        fg: thirdColor,
      ),
    ];
  }

  String _monthlyTrendLabel(List<AppNotification> notifications) {
    final now = DateTime.now();
    final currentMonthCount = notifications
        .where(
          (n) => n.createdAt.year == now.year && n.createdAt.month == now.month,
        )
        .length;
    final previousMonth = now.month == 1
        ? DateTime(now.year - 1, 12)
        : DateTime(now.year, now.month - 1);
    final previousMonthCount = notifications
        .where(
          (n) =>
              n.createdAt.year == previousMonth.year &&
              n.createdAt.month == previousMonth.month,
        )
        .length;

    if (previousMonthCount == 0) {
      if (currentMonthCount == 0) {
        return 'No new signals were generated this month.';
      }
      return '$currentMonthCount new signal${currentMonthCount == 1 ? '' : 's'} this month.';
    }

    final delta = currentMonthCount - previousMonthCount;
    final percent = (delta / previousMonthCount) * 100;
    final prefix = delta >= 0 ? '+' : '';
    return '$prefix${percent.toStringAsFixed(0)}% compared with last month.';
  }

  List<_NotificationSection> _groupNotifications(List<AppNotification> notifications) {
    final now = DateTime.now();
    final currentWeek = <AppNotification>[];
    final earlierThisMonth = <AppNotification>[];
    final older = <AppNotification>[];

    for (final notification in notifications) {
      final createdAt = notification.createdAt;
      final daysAgo = now.difference(createdAt).inDays;
      final sameMonth = createdAt.year == now.year && createdAt.month == now.month;

      if (daysAgo < 7) {
        currentWeek.add(notification);
      } else if (sameMonth) {
        earlierThisMonth.add(notification);
      } else {
        older.add(notification);
      }
    }

    return [
      if (currentWeek.isNotEmpty)
        _NotificationSection(title: 'CURRENT WEEK', items: currentWeek),
      if (earlierThisMonth.isNotEmpty)
        _NotificationSection(
          title: 'EARLIER THIS MONTH',
          items: earlierThisMonth,
        ),
      if (older.isNotEmpty)
        _NotificationSection(title: 'OLDER UPDATES', items: older),
    ];
  }

  List<_FilterConfig> _filtersForContext(_NotificationRoleContext context) {
    final filters = <_FilterConfig>[
      const _FilterConfig(filter: _NotificationFilter.all, label: 'All'),
      const _FilterConfig(filter: _NotificationFilter.unread, label: 'Unread'),
    ];
    if (context.canViewApprovals) {
      filters.add(
        const _FilterConfig(
          filter: _NotificationFilter.approvals,
          label: 'Approvals',
        ),
      );
    }
    if (context.canViewFinance) {
      filters.add(
        const _FilterConfig(filter: _NotificationFilter.finance, label: 'Finance'),
      );
    }
    if (context.canViewPeople) {
      filters.add(
        const _FilterConfig(filter: _NotificationFilter.people, label: 'People'),
      );
    }
    if (context.canViewAttendance) {
      filters.add(
        const _FilterConfig(
          filter: _NotificationFilter.attendance,
          label: 'Attendance',
        ),
      );
    }
    filters.add(
      const _FilterConfig(filter: _NotificationFilter.general, label: 'General'),
    );
    return filters;
  }

  List<AppNotification> _applyFilter(
    List<AppNotification> notifications,
    _NotificationFilter filter,
    _NotificationRoleContext roleContext,
  ) {
    switch (filter) {
      case _NotificationFilter.all:
        return notifications;
      case _NotificationFilter.unread:
        return notifications.where((n) => !n.isRead).toList();
      case _NotificationFilter.approvals:
        if (!roleContext.canViewApprovals) return const [];
        return notifications.where((n) => _isApprovalType(n.type)).toList();
      case _NotificationFilter.finance:
        if (!roleContext.canViewFinance) return const [];
        return notifications.where((n) => _isFinanceType(n.type)).toList();
      case _NotificationFilter.people:
        if (!roleContext.canViewPeople) return const [];
        return notifications.where((n) => _isPeopleType(n.type)).toList();
      case _NotificationFilter.attendance:
        if (!roleContext.canViewAttendance) return const [];
        return notifications
            .where((n) => n.type == NotificationType.attendance)
            .toList();
      case _NotificationFilter.general:
        return notifications
            .where((n) => n.type == NotificationType.general)
            .toList();
    }
  }

  _NotificationRoleContext _roleContextFor(AppUser user) {
    final canViewApprovals =
        PermissionService.hasPermission(user, Permission.approveLeave) ||
        PermissionService.hasPermission(user, Permission.approveLoan) ||
        PermissionService.hasPermission(user, Permission.approveSalaryAdvance) ||
        PermissionService.hasPermission(user, Permission.approveExpenses) ||
        PermissionService.hasPermission(user, Permission.approveExitManagement);
    final canViewFinance =
        PermissionService.hasPermission(user, Permission.viewPayroll) ||
        PermissionService.hasPermission(user, Permission.processPayroll) ||
        PermissionService.hasPermission(user, Permission.viewReports);
    final canViewPeople =
        PermissionService.hasPermission(user, Permission.viewEmployees) ||
        PermissionService.hasPermission(user, Permission.manageProbation) ||
        PermissionService.hasPermission(user, Permission.approveContract);
    final canViewAttendance =
        PermissionService.hasPermission(user, Permission.viewAttendance);

    if (PermissionService.hasPermission(user, Permission.manageUsers)) {
      return _NotificationRoleContext(
        title: 'Company Action Center',
        subtitle:
            'Oversee approvals, critical alerts, and company signals across all departments.',
        canViewApprovals: canViewApprovals,
        canViewFinance: canViewFinance,
        canViewPeople: canViewPeople,
        canViewAttendance: canViewAttendance,
      );
    }
    if (PermissionService.hasPermission(user, Permission.approveLeave) ||
        PermissionService.hasPermission(user, Permission.viewEmployees)) {
      return _NotificationRoleContext(
        title: 'HR Action Center',
        subtitle:
            'Monitor requests, workforce changes, and people operations that need attention.',
        canViewApprovals: canViewApprovals,
        canViewFinance: canViewFinance,
        canViewPeople: canViewPeople,
        canViewAttendance: canViewAttendance,
      );
    }
    if (PermissionService.hasPermission(user, Permission.processPayroll) ||
        PermissionService.hasPermission(user, Permission.viewPayroll)) {
      return _NotificationRoleContext(
        title: 'Finance Signal Center',
        subtitle:
            'Track approvals, payroll events, and settlement updates tied to finance operations.',
        canViewApprovals: canViewApprovals,
        canViewFinance: canViewFinance,
        canViewPeople: canViewPeople,
        canViewAttendance: canViewAttendance,
      );
    }
    return _NotificationRoleContext(
      title: 'My Action Center',
      subtitle:
          'Keep up with your approvals, attendance changes, and general company updates.',
      canViewApprovals: canViewApprovals,
      canViewFinance: canViewFinance,
      canViewPeople: canViewPeople,
      canViewAttendance: canViewAttendance,
    );
  }

  _BadgeData _badgeFor(AppNotification notification) {
    switch (notification.type) {
      case NotificationType.loanRequest:
      case NotificationType.salaryAdvanceRequest:
      case NotificationType.expenseRequest:
        return const _BadgeData(
          label: 'ACTION REQUIRED',
          bg: Color(0xFFFFE9E5),
          fg: AppColors.error,
        );
      case NotificationType.loanApproved:
      case NotificationType.salaryAdvanceApproved:
      case NotificationType.expenseApproved:
        return const _BadgeData(
          label: 'COMPLETED',
          bg: Color(0xFFE5F0FF),
          fg: Color(0xFF245FC2),
        );
      case NotificationType.loanRejected:
      case NotificationType.salaryAdvanceRejected:
      case NotificationType.expenseRejected:
        return const _BadgeData(
          label: 'REJECTED',
          bg: Color(0xFFFFE6E6),
          fg: AppColors.error,
        );
      case NotificationType.attendance:
        return const _BadgeData(
          label: 'ATTENDANCE',
          bg: Color(0xFFFFF3D6),
          fg: Color(0xFF9A6700),
        );
      case NotificationType.contract:
      case NotificationType.probation:
        return const _BadgeData(
          label: 'WORKFLOW',
          bg: Color(0xFFEAF0F8),
          fg: Color(0xFF667A96),
        );
      case NotificationType.general:
        return const _BadgeData(
          label: 'INFORMATION',
          bg: Color(0xFFF0F4F8),
          fg: Color(0xFF8A9AAF),
        );
    }
  }

  _RouteAction? _routeActionFor(AppUser user, AppNotification notification) {
    switch (notification.type) {
      case NotificationType.expenseRequest:
      case NotificationType.expenseApproved:
      case NotificationType.expenseRejected:
        if (PermissionService.hasPermission(user, Permission.viewExpenses)) {
          return const _RouteAction(
            label: 'Open Expenses',
            route: AppRoutes.expenseReimbursements,
          );
        }
      case NotificationType.loanRequest:
      case NotificationType.loanApproved:
      case NotificationType.loanRejected:
        if (PermissionService.hasPermission(user, Permission.viewLoans)) {
          return const _RouteAction(
            label: 'Open Loans',
            route: AppRoutes.loansList,
          );
        }
      case NotificationType.salaryAdvanceRequest:
      case NotificationType.salaryAdvanceApproved:
      case NotificationType.salaryAdvanceRejected:
        if (PermissionService.hasPermission(user, Permission.viewSalaryAdvance)) {
          return const _RouteAction(
            label: 'Open Salary Advances',
            route: AppRoutes.salaryAdvances,
          );
        }
      case NotificationType.attendance:
        if (PermissionService.hasPermission(user, Permission.viewAttendance)) {
          return const _RouteAction(
            label: 'Open Attendance',
            route: AppRoutes.attendanceList,
          );
        }
      case NotificationType.contract:
      case NotificationType.probation:
        if (PermissionService.hasPermission(user, Permission.viewEmployees)) {
          return const _RouteAction(
            label: 'Open Employees',
            route: AppRoutes.employeeList,
          );
        }
      case NotificationType.general:
        if (PermissionService.hasPermission(user, Permission.viewDashboard)) {
          return const _RouteAction(
            label: 'Open Dashboard',
            route: AppRoutes.dashboard,
          );
        }
    }
    return null;
  }

  Future<void> _openNotificationRoute(
    AppNotification notification,
    String route,
  ) async {
    if (!notification.isRead) {
      await _notificationService.markAsRead(notification.id);
    }
    if (!mounted) return;
    Navigator.pushNamed(context, route);
  }

  bool _isApprovalType(NotificationType type) {
    return type == NotificationType.loanRequest ||
        type == NotificationType.salaryAdvanceRequest ||
        type == NotificationType.expenseRequest;
  }

  bool _isFinanceType(NotificationType type) {
    return type == NotificationType.loanApproved ||
        type == NotificationType.loanRejected ||
        type == NotificationType.salaryAdvanceApproved ||
        type == NotificationType.salaryAdvanceRejected ||
        type == NotificationType.expenseApproved ||
        type == NotificationType.expenseRejected;
  }

  bool _isPeopleType(NotificationType type) {
    return type == NotificationType.contract ||
        type == NotificationType.probation;
  }

  IconData _notificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.loanRequest:
        return Icons.account_balance_wallet_outlined;
      case NotificationType.loanApproved:
        return Icons.verified_rounded;
      case NotificationType.loanRejected:
        return Icons.highlight_off_rounded;
      case NotificationType.salaryAdvanceRequest:
        return Icons.payments_outlined;
      case NotificationType.salaryAdvanceApproved:
        return Icons.task_alt_rounded;
      case NotificationType.salaryAdvanceRejected:
        return Icons.cancel_outlined;
      case NotificationType.expenseRequest:
        return Icons.receipt_long_outlined;
      case NotificationType.expenseApproved:
        return Icons.inventory_2_outlined;
      case NotificationType.expenseRejected:
        return Icons.receipt_long_outlined;
      case NotificationType.attendance:
        return Icons.calendar_month_outlined;
      case NotificationType.contract:
        return Icons.description_outlined;
      case NotificationType.probation:
        return Icons.group_add_outlined;
      case NotificationType.general:
        return Icons.notifications_none_rounded;
    }
  }

  Color _notificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.loanRequest:
      case NotificationType.salaryAdvanceRequest:
      case NotificationType.expenseRequest:
        return AppColors.error;
      case NotificationType.loanApproved:
      case NotificationType.salaryAdvanceApproved:
      case NotificationType.expenseApproved:
        return const Color(0xFF245FC2);
      case NotificationType.loanRejected:
      case NotificationType.salaryAdvanceRejected:
      case NotificationType.expenseRejected:
        return AppColors.error;
      case NotificationType.attendance:
        return const Color(0xFF4B6584);
      case NotificationType.contract:
      case NotificationType.probation:
        return const Color(0xFF6B7F99);
      case NotificationType.general:
        return const Color(0xFF94A3B8);
    }
  }

  String _categoryLabel(NotificationType type) {
    switch (type) {
      case NotificationType.loanRequest:
      case NotificationType.loanApproved:
      case NotificationType.loanRejected:
        return 'Loans';
      case NotificationType.salaryAdvanceRequest:
      case NotificationType.salaryAdvanceApproved:
      case NotificationType.salaryAdvanceRejected:
        return 'Salary Advance';
      case NotificationType.expenseRequest:
      case NotificationType.expenseApproved:
      case NotificationType.expenseRejected:
        return 'Expenses';
      case NotificationType.attendance:
        return 'Attendance';
      case NotificationType.contract:
      case NotificationType.probation:
        return 'People';
      case NotificationType.general:
        return 'General';
    }
  }

  IconData _categoryIcon(NotificationType type) {
    switch (type) {
      case NotificationType.loanRequest:
      case NotificationType.loanApproved:
      case NotificationType.loanRejected:
        return Icons.account_balance_wallet_outlined;
      case NotificationType.salaryAdvanceRequest:
      case NotificationType.salaryAdvanceApproved:
      case NotificationType.salaryAdvanceRejected:
        return Icons.payments_outlined;
      case NotificationType.expenseRequest:
      case NotificationType.expenseApproved:
      case NotificationType.expenseRejected:
        return Icons.folder_open_outlined;
      case NotificationType.attendance:
        return Icons.schedule_rounded;
      case NotificationType.contract:
      case NotificationType.probation:
        return Icons.groups_2_outlined;
      case NotificationType.general:
        return Icons.info_outline_rounded;
    }
  }
}
