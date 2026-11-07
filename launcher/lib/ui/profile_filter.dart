import 'package:flutter/material.dart';

class ProfileFilter extends StatelessWidget {
  const ProfileFilter({
    super.key,
    required this.profile,
    required this.onProfile,
    required this.onlyInstalled,
    required this.onOnlyInstalled,
  });

  static const profiles = ['todos', 'minimal', 'dev', 'full'];

  final String profile;
  final ValueChanged<String> onProfile;
  final bool onlyInstalled;
  final ValueChanged<bool> onOnlyInstalled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final p in profiles)
              ButtonSegment(value: p, label: Text(p == 'todos' ? 'Todos' : p)),
          ],
          selected: {profile},
          onSelectionChanged: (s) => onProfile(s.first),
        ),
        FilterChip(
          label: const Text('Só instalados'),
          selected: onlyInstalled,
          onSelected: onOnlyInstalled,
        ),
      ],
    );
  }
}
