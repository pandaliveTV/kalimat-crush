import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/themes.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';

/// Background themes, unlocked by reaching levels.
class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StorageService>();
    return Scaffold(
      appBar: AppBar(title: const Text('الخلفيات')),
      body: GradientBackground(
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.8,
          ),
          itemCount: gameThemes.length,
          itemBuilder: (context, i) {
            final t = gameThemes[i];
            final unlocked = isThemeUnlocked(t, s.level);
            final selected = s.theme == t.id;
            return GestureDetector(
              onTap: unlocked
                  ? () => s.selectTheme(t.id)
                  : () => showToast(
                      context,
                      'تُفتح عند الوصول إلى المستوى ${t.unlockLevel}',
                    ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: t.colors,
                  ),
                  border: Border.all(
                    color: selected ? t.accent : Colors.white24,
                    width: selected ? 4 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            unlocked
                                ? (selected
                                      ? Icons.check_circle
                                      : Icons.palette)
                                : Icons.lock,
                            size: 40,
                            color: unlocked ? t.accent : Colors.white54,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            t.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (!unlocked)
                            Text(
                              'المستوى ${t.unlockLevel}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
