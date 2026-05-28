import 'package:flutter/material.dart';
import '../theme.dart';
import '../providers/app_state.dart';
import '../widgets/glass_container.dart';
import 'package:intl/intl.dart';

class DashboardView extends StatelessWidget {
  final AppState state;

  const DashboardView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final historyCount = state.history.length;
    final jobsCount = state.jobs.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com saudação e data
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bem-vindo, ${state.profileName ?? "de volta"}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AmethystTheme.textSecondary,
                          fontSize: 14,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Painel de Controle',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
              Text(
                DateFormat('dd/MM/yyyy').format(DateTime.now()),
                style: const TextStyle(
                  color: AmethystTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Grid de Métricas
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800 ? 3 : 1;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: constraints.maxWidth > 800 ? 2.5 : 3.5,
                children: [
                  _buildMetricCard(
                    icon: Icons.psychology_outlined,
                    title: 'Currículos Otimizados',
                    value: '$historyCount',
                    color: AmethystTheme.accentAmethyst,
                  ),
                  _buildMetricCard(
                    icon: Icons.work_outline_outlined,
                    title: 'Vagas Capturadas',
                    value: '$jobsCount',
                    color: AmethystTheme.accentIndigo,
                  ),
                  _buildMetricCard(
                    icon: Icons.auto_awesome,
                    title: 'Motor de Otimização',
                    value: 'Gemini 2.0',
                    color: AmethystTheme.neonCyan,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Ações Rápidas & Logs Recentes
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colona Esquerda: Ações Rápidas
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ações Rápidas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                     _buildQuickActionCard(
                      context,
                      title: 'Otimizar Currículo (Tailoring)',
                      subtitle: 'Reescreva os bullet points e palavras-chave do LaTeX original para uma nova vaga de emprego.',
                      icon: Icons.auto_awesome,
                      gradient: AmethystTheme.accentGradient,
                      onTap: () => state.setTab(1),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActionCard(
                      context,
                      title: 'Capturar Vaga de URL',
                      subtitle: 'Cole links do LinkedIn ou Gupy para extrair automaticamente título, empresa e requisitos da vaga.',
                      icon: Icons.link,
                      gradient: AmethystTheme.energyGradient,
                      onTap: () => state.setTab(3),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActionCard(
                      context,
                      title: 'Configurar Perfil',
                      subtitle: 'Vincule seu LinkedIn e Gupy para candidatar-se às vagas rapidamente.',
                      icon: Icons.person_outline,
                      gradient: const LinearGradient(
                        colors: [AmethystTheme.accentAmethyst, Color(0xFF6B21A8)],
                      ),
                      onTap: () => state.setTab(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Colona Direita: Últimas Execuções
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Execuções Recentes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        TextButton(
                          onPressed: () => state.setTab(2),
                          child: const Text(
                            'Ver todas',
                            style: TextStyle(color: AmethystTheme.accentAmethyst),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildRecentRunsList(context),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderColor: color.withOpacity(0.15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AmethystTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AmethystTheme.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AmethystTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRunsList(BuildContext context) {
    if (state.isLoadingHistory) {
      return const GlassContainer(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(color: AmethystTheme.accentAmethyst),
        ),
      );
    }

    if (state.historyError != null) {
      return GlassContainer(
        height: 220,
        borderColor: AmethystTheme.neonRed.withOpacity(0.2),
        child: Center(
          child: Text(
            'Erro ao carregar execuções: ${state.historyError}',
            style: const TextStyle(color: AmethystTheme.neonRed),
          ),
        ),
      );
    }

    if (state.history.isEmpty) {
      return const GlassContainer(
        height: 220,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off, color: AmethystTheme.textMuted, size: 40),
              SizedBox(height: 12),
              Text(
                'Nenhuma otimização realizada ainda.',
                style: TextStyle(color: AmethystTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final recentList = state.history.take(3).toList();

    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: recentList.map((item) {
          // Extrai um trecho da descrição do cargo ou descrição da vaga
          final excerpt = item.jobDescription.length > 80
              ? '${item.jobDescription.substring(0, 80)}...'
              : item.jobDescription;

          // Formata o timestamp
          String dateStr = '';
          try {
            final dt = DateTime.parse(item.timestamp);
            dateStr = DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
          } catch (_) {
            dateStr = item.timestamp;
          }

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 12, color: AmethystTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(color: AmethystTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AmethystTheme.accentAmethyst,
                ),
                onTap: () {
                  // Navega para aba do histórico
                  state.setTab(2);
                },
              ),
              if (item != recentList.last)
                const Divider(color: Color(0x11A855F7), height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }
}
