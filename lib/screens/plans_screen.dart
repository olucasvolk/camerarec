import 'package:flutter/material.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({Key? key}) : super(key: key);

  Widget _buildPlanCard(
    String title,
    String subtitle,
    String price,
    Color accentColor,
    List<String> features,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(0.1),
            Colors.black.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            price,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: accentColor, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      feature,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () {
                // Implementar assinatura
              },
              child: const Text(
                'Assinar Agora',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF000000),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPlanCard(
            'Plano Pro',
            'Recursos avançados para atletas',
            'R\$ 19,90/mês',
            const Color(0xFFE50914),
            [
              'Gravação em Full HD',
              'Sem marca d\'água',
              'Exportação em diversos formatos',
              'Suporte prioritário',
            ],
          ),
          const SizedBox(height: 16),
          _buildPlanCard(
            'Plano Elite',
            'Para times e profissionais',
            'R\$ 49,90/mês',
            const Color(0xFF1DB954),
            [
              'Gravação em 4K',
              'Múltiplos usuários',
              'Armazenamento em nuvem',
              'Análise de desempenho',
              'Suporte 24/7',
            ],
          ),
        ],
      ),
    );
  }
}
