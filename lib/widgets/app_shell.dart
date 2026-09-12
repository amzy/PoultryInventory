import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/poultry_provider.dart';

class AppNavItem {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  const AppNavItem(this.label, this.subtitle, this.icon, this.color);
}

const poultryNavItems = <AppNavItem>[
  AppNavItem('Dashboard', 'Overview & reports', Icons.dashboard_outlined, Color(0xFF16A34A)),
  AppNavItem('Reports', 'Production & financial analytics', Icons.bar_chart_outlined, Color(0xFF0E9F6E)),
  AppNavItem('Daily Log', 'Track daily flock data', Icons.calendar_month_outlined, Color(0xFF2563EB)),
  AppNavItem('Medical', 'Record medical expenses', Icons.medical_services_outlined, Color(0xFFEF4444)),
  AppNavItem('Feed', 'Track feed purchases', Icons.inventory_2_outlined, Color(0xFFF59E0B)),
  AppNavItem('Grit', 'Track grit purchases', Icons.scatter_plot_outlined, Color(0xFF9A6B22)),
  AppNavItem('Tray', 'Track tray purchases', Icons.inventory_2_outlined, Color(0xFF0EA5A4)),
  AppNavItem('Other Expenses', 'Record other expenses', Icons.folder_outlined, Color(0xFF7C3AED)),
  AppNavItem('Egg Sales', 'Track egg sales', Icons.egg_alt_outlined, Color(0xFFF97316)),
  AppNavItem('Suppliers', 'Supplier directory', Icons.local_shipping_outlined, Color(0xFF0EA5A4)),
  AppNavItem('Admin', 'Farm administration', Icons.admin_panel_settings_outlined, Color(0xFF64748B)),
  AppNavItem('Standards Calendar', 'BV300 daily benchmarks', Icons.event_note_outlined, Color(0xFF0891B2)),
  AppNavItem('My Profile', 'Personal account information', Icons.person_outline, Color(0xFF7C3AED)),
];

class PoultryAppShell extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final void Function(int index)? onNavigate;
  final Widget? trailing;
  final Widget? headerOverride;

  const PoultryAppShell({
    super.key,
    required this.child,
    this.selectedIndex = 0,
    this.title = 'Poultry Inventory',
    this.subtitle = '',
    this.onBack,
    this.onNavigate,
    this.trailing,
    this.headerOverride,
  });

  List<int> _visibleIndices(PoultryProvider provider) {
    if (provider.isAdmin) return List<int>.generate(poultryNavItems.length, (i) => i).where((i) => i != 11 && i != 12).toList();
    final result = <int>[0, 2];
    const gated = <int, String>{
      1: 'reports',
      3: 'medical',
      4: 'feed',
      5: 'grit',
      6: 'tray',
      7: 'otherExpenses',
      8: 'eggSales',
      9: 'suppliers',
    };
    for (final entry in gated.entries) {
      if (provider.hasFeature(entry.value)) result.add(entry.key);
    }
    return result..sort();
  }

  bool _isMobileOrTablet(BuildContext context) => MediaQuery.sizeOf(context).width < 1024;

  int _mobileTabIndex() {
    switch (selectedIndex) {
      case 0:
        return 0;
      case 2:
        return 1;
      case 1:
        return 2;
      case 10:
      case 12:
        return 3;
      default:
        return 3;
    }
  }

  void _navigateMobileTab(BuildContext context, int tab) {
    const mapping = <int, int>{0: 0, 1: 2, 2: 1, 3: 10};
    final index = mapping[tab];
    if (index != null) onNavigate?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PoultryProvider>(builder: (context, provider, _) {
      final visibleIndices = _visibleIndices(provider);
      final compact = _isMobileOrTablet(context);

      return Scaffold(
        backgroundColor: const Color(0xFFF3F7F4),
        bottomNavigationBar: compact && onNavigate != null
            ? Builder(
                builder: (scaffoldContext) => _MobileBottomNavigation(
                  selectedIndex: _mobileTabIndex(),
                  onSelected: (tab) => _navigateMobileTab(scaffoldContext, tab),
                ),
              )
            : null,
        body: Row(
          children: [
            if (!compact)
              _DesktopSidebar(
                selectedIndex: selectedIndex,
                onNavigate: onNavigate,
                visibleIndices: visibleIndices,
              ),
            Expanded(
              child: Column(
                children: [
                  if (compact)
                    headerOverride ??
                        _MobileHeader(
                          title: title,
                          subtitle: subtitle,
                          onBack: onBack,
                          trailing: trailing,
                        )
                  else
                    headerOverride ??
                        _DesktopHeader(
                          title: title,
                          subtitle: subtitle,
                          onBack: onBack,
                          trailing: trailing,
                        ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _MobileBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _MobileBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _items = <({IconData icon, IconData activeIcon, String label})>[
    (icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Home'),
    (icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Daily'),
    (icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Reports'),
    (icon: Icons.admin_panel_settings_outlined, activeIcon: Icons.admin_panel_settings, label: 'Admin'),
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      height: 68,
      elevation: 10,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFD7F3E7),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (final item in _items)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: item.label,
          ),
      ],
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int)? onNavigate;
  final List<int> visibleIndices;
  const _DesktopSidebar({required this.selectedIndex, required this.onNavigate, required this.visibleIndices});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF075E42), Color(0xFF063D30)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/app_icons/app_logo.png', width: 70, height: 70, fit: BoxFit.cover)),
            const SizedBox(height: 8),
            const Text('Poultry Inventory', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: visibleIndices.length,
                itemBuilder: (context, index) {
                  final itemIndex = visibleIndices[index];
                  final item = poultryNavItems[itemIndex];
                  return _NavTile(item: item, selected: itemIndex == selectedIndex, compact: true, onTap: onNavigate == null ? null : () => onNavigate!(itemIndex));
                },
              ),
            ),
            const Divider(color: Colors.white24, indent: 16, endIndent: 16),
            const _LogoutTile(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile();

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime with your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (shouldLogout != true || !context.mounted) return;
    await context.read<PoultryProvider>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
      title: const Text('Sign out', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () => _logout(context),
    );
  }
}



class _NavTile extends StatelessWidget {
  final AppNavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;
  const _NavTile({required this.item, required this.selected, this.compact = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withOpacity(.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        minLeadingWidth: 0,
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: selected ? Colors.white.withOpacity(.16) : item.color.withOpacity(.16), borderRadius: BorderRadius.circular(9)),
          child: Icon(item.icon, color: selected ? Colors.white : item.color, size: 19),
        ),
        title: Text(item.label, style: TextStyle(color: Colors.white, fontSize: compact ? 12 : 14, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
        subtitle: compact ? null : Text(item.subtitle, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        trailing: compact ? null : const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      ),
    );
  }
}

class DashboardHeader extends StatelessWidget {
  final String flockName;
  final DateTime startDate;
  final int age;

  const DashboardHeader({
    super.key,
    required this.flockName,
    required this.startDate,
    required this.age,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 1024;
    final start = DateFormat('dd MMM yyyy').format(startDate);
    final ageText = '$age days old';

    final content = Container(
      height: mobile ? 78 : 86,
      padding: EdgeInsets.fromLTRB(mobile ? 4 : 24, 8, mobile ? 14 : 24, 8),
      child: Row(
        children: [
          SizedBox(
            width: mobile ? 44 : 58,
            height: mobile ? 44 : 58,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(mobile ? 11 : 14),
              child: Image.asset(
                'assets/app_icons/app_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: mobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  flockName.isEmpty ? 'No active flock' : flockName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF0B3D2E),
                    fontSize: mobile ? 17 : 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  mobile ? 'Age $ageText' : 'Started $start  •  Age $ageText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF527064),
                    fontSize: mobile ? 10 : 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return mobile ? SafeArea(bottom: false, child: content) : content;
  }
}

class _DesktopHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  const _DesktopHeader({required this.title, required this.subtitle, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: Color(0xFF0B3D2E)))
          else
            const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, style: const TextStyle(color: Color(0xFF0B3D2E), fontSize: 25, fontWeight: FontWeight.w800)),
            if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: Color(0xFF527064), fontSize: 12)),
          ])),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  const _MobileHeader({required this.title, required this.subtitle, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: const BoxDecoration(color: Color(0xFF075E42)),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (onBack != null) IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: Colors.white)) else const SizedBox(width: 8),
            SizedBox(
              width: 38,
              height: 38,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/app_icons/playstore.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)), if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 10))])),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderRadiusGeometry radius;
  final Border? border;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.radius = const BorderRadius.all(Radius.circular(16)), this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: radius,
        border: border ?? Border.all(color: const Color(0xFFE3EBE6)),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 5))],
      ),
      child: child,
    );
  }
}
