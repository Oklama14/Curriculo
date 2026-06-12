import 'package:flutter/material.dart';
import '../theme.dart';
import '../providers/app_state.dart';
import '../services/auth_service.dart';
import 'dashboard_view.dart';
import 'tailor_view.dart';
import 'resume_view.dart';
import 'history_view.dart';
import 'jobs_view.dart';
import 'profile_view.dart';
import 'apply_view.dart';

class MainLayout extends StatefulWidget {
  final AppState state;

  const MainLayout({super.key, required this.state});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Carrega os dados iniciais ao iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.state.loadAll();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final List<Widget> views = [
      DashboardView(state: state),
      TailorView(state: state),
      ResumeView(state: state),
      HistoryView(state: state),
      JobsView(state: state),
      ProfileView(state: state),
      ApplyView(state: state),
    ];

    final List<Map<String, dynamic>> menuItems = [
      {'icon': Icons.space_dashboard_outlined, 'label': 'Painel Principal'},
      {'icon': Icons.psychology_outlined, 'label': 'Resume Tailoring'},
      {'icon': Icons.upload_file_rounded, 'label': 'Meu Currículo'},
      {'icon': Icons.history_edu_outlined, 'label': 'Histórico'},
      {'icon': Icons.work_outline_outlined, 'label': 'Vagas Coletadas'},
      {'icon': Icons.person_outline, 'label': 'Meu Perfil'},
      {'icon': Icons.send_rounded, 'label': 'Candidatar-se'},
    ];

    if (isDesktop) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AmethystTheme.bgGradient,
          ),
          child: Row(
            children: [
              // Sidebar
              _buildSidebar(state, menuItems),
              // Conteúdo Principal
              Expanded(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                    child: views[state.currentTabIndex],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Layout Mobile / Tablet Pequeno
    return Scaffold(
      appBar: AppBar(
        title: Text(
          menuItems[state.currentTabIndex]['label'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AmethystTheme.bgSecondary,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: Container(
          color: AmethystTheme.bgPrimary,
          child: Column(
            children: [
              _buildSidebarHeader(),
              const Divider(color: Color(0x22A855F7)),
              Expanded(
                child: ListView.builder(
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    final isSelected = state.currentTabIndex == index;
                    return ListTile(
                      leading: Icon(
                        item['icon'],
                        color: isSelected ? AmethystTheme.accentAmethyst : AmethystTheme.textSecondary,
                      ),
                      title: Text(
                        item['label'],
                        style: TextStyle(
                          color: isSelected ? AmethystTheme.textPrimary : AmethystTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: AmethystTheme.accentAmethyst.withOpacity(0.1),
                      onTap: () {
                        state.setTab(index);
                        Navigator.pop(context); // Fecha o drawer
                      },
                    );
                  },
                ),
              ),
              _buildSidebarFooter(),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AmethystTheme.bgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: views[state.currentTabIndex],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(AppState state, List<Map<String, dynamic>> menuItems) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF07040E),
        border: Border(
          right: BorderSide(color: Color(0x1FA855F7), width: 1.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarHeader(),
          const SizedBox(height: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: ListView.builder(
                itemCount: menuItems.length,
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  final isSelected = state.currentTabIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () => state.setTab(index),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    AmethystTheme.accentAmethyst.withOpacity(0.15),
                                    AmethystTheme.accentIndigo.withOpacity(0.05),
                                  ],
                                )
                              : null,
                          border: isSelected
                              ? Border.all(color: AmethystTheme.accentAmethyst.withOpacity(0.3))
                              : Border.all(color: Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item['icon'],
                              color: isSelected ? AmethystTheme.accentAmethyst : AmethystTheme.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              item['label'],
                              style: TextStyle(
                                color: isSelected ? AmethystTheme.textPrimary : AmethystTheme.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            if (isSelected) ...[
                              const Spacer(),
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AmethystTheme.accentAmethyst,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: AmethystTheme.glowShadow(AmethystTheme.accentAmethyst, radius: 4.0),
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    final state = widget.state;
    return Container(
      padding: const EdgeInsets.only(top: 40, left: 24, bottom: 20, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AmethystTheme.accentAmethyst.withOpacity(0.2),
                backgroundImage: state.photoUrl != null && state.photoUrl!.isNotEmpty
                    ? NetworkImage(state.photoUrl!)
                    : null,
                child: state.photoUrl == null || state.photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 20, color: AmethystTheme.accentAmethyst)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.profileName ?? 'Usuário',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      state.profileEmail ?? '',
                      style: const TextStyle(
                        color: AmethystTheme.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter() {
    final isOnline = widget.state.jobsError == null && widget.state.historyError == null;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                     width: 8,
                     height: 8,
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       color: isOnline ? AmethystTheme.neonCyan : AmethystTheme.neonRed,
                       boxShadow: [
                         BoxShadow(
                           color: (isOnline ? AmethystTheme.neonCyan : AmethystTheme.neonRed)
                               .withOpacity(0.6 * _pulseController.value),
                           blurRadius: 8.0 * _pulseController.value + 2.0,
                           spreadRadius: 2.0 * _pulseController.value,
                         ),
                       ],
                     ),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(
                isOnline ? 'CONECTADO À API' : 'API DESCONECTADA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isOnline ? AmethystTheme.neonCyan : AmethystTheme.neonRed,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0x11A855F7), height: 1),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: AmethystTheme.neonRed, size: 20),
            title: const Text(
              'Sair da Conta',
              style: TextStyle(color: AmethystTheme.neonRed, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              AuthService().signOut();
            },
          ),
        ],
      ),
    );
  }
}
