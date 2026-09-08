import 'package:flutter/material.dart';

class AppNavItem {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  const AppNavItem(this.label, this.subtitle, this.icon, this.color);
}

const poultryNavItems = <AppNavItem>[
  AppNavItem('Dashboard', 'Overview & reports', Icons.dashboard_outlined, Color(0xFF16A34A)),
  AppNavItem('Daily Log', 'Track daily flock data', Icons.calendar_month_outlined, Color(0xFF2563EB)),
  AppNavItem('Medical', 'Record medical expenses', Icons.medical_services_outlined, Color(0xFFEF4444)),
  AppNavItem('Feed', 'Track feed purchases', Icons.inventory_2_outlined, Color(0xFFF59E0B)),
  AppNavItem('Grit', 'Track grit purchases', Icons.scatter_plot_outlined, Color(0xFF9A6B22)),
  AppNavItem('Other Expenses', 'Record other expenses', Icons.folder_outlined, Color(0xFF7C3AED)),
  AppNavItem('Egg Sales', 'Track egg sales', Icons.egg_alt_outlined, Color(0xFFF97316)),
  AppNavItem('Settings', 'App preferences', Icons.settings_outlined, Color(0xFF64748B)),
];

class PoultryAppShell extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final void Function(int index)? onNavigate;
  final Widget? trailing;

  const PoultryAppShell({
    super.key,
    required this.child,
    this.selectedIndex = 0,
    this.title = 'Poultry Inventory',
    this.subtitle = '',
    this.onBack,
    this.onNavigate,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F4),
      drawer: _MobileDrawer(selectedIndex: selectedIndex, onNavigate: onNavigate),
      body: Row(
        children: [
          if (MediaQuery.sizeOf(context).width >= 900)
            _DesktopSidebar(selectedIndex: selectedIndex, onNavigate: onNavigate),
          Expanded(
            child: Column(
              children: [
                if (MediaQuery.sizeOf(context).width < 900)
                  _MobileHeader(
                    title: title,
                    subtitle: subtitle,
                    onBack: onBack,
                    trailing: trailing,
                  )
                else
                  _DesktopHeader(title: title, subtitle: subtitle, trailing: trailing),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int)? onNavigate;
  const _DesktopSidebar({required this.selectedIndex, required this.onNavigate});

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
            Image.asset('assets/app_icons/playstore.png', width: 70, height: 70),
            const SizedBox(height: 8),
            const Text('Poultry Inventory', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: poultryNavItems.length,
                itemBuilder: (context, index) => _NavTile(
                  item: poultryNavItems[index],
                  selected: index == selectedIndex,
                  compact: true,
                  onTap: onNavigate == null ? null : () => onNavigate!(index),
                ),
              ),
            ),
            const Divider(color: Colors.white24, indent: 16, endIndent: 16),
            ListTile(
              dense: true,
              leading: const CircleAvatar(radius: 15, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white, size: 17)),
              title: const Text('Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
              subtitle: const Text('Firebase secured', style: TextStyle(color: Colors.white60, fontSize: 10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  final int selectedIndex;
  final void Function(int)? onNavigate;
  const _MobileDrawer({required this.selectedIndex, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF064532),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            Image.asset('assets/app_icons/playstore.png', width: 76, height: 76),
            const SizedBox(height: 8),
            const Text('Poultry Inventory', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: poultryNavItems.length,
                itemBuilder: (context, index) => _NavTile(
                  item: poultryNavItems[index],
                  selected: index == selectedIndex,
                  onTap: onNavigate == null ? null : () { Navigator.pop(context); onNavigate!(index); },
                ),
              ),
            ),
          ],
        ),
      ),
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

class _DesktopHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _DesktopHeader({required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      child: Row(
        children: [
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
            if (onBack != null) IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: Colors.white)) else IconButton(onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu, color: Colors.white)),
            Image.asset('assets/app_icons/playstore.png', width: 38, height: 38),
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
