import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/verdict.dart';
import '../providers/parking_providers.dart';
import 'status_style.dart';

/// The result panel shown under the map after a tap.
class VerdictSheet extends ConsumerWidget {
  const VerdictSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pin = ref.watch(pinProvider);
    if (pin == null) return const SizedBox.shrink();

    final verdict = ref.watch(verdictProvider);
    return Material(
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: verdict.when(
            loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _Message(icon: Icons.cloud_off, text: 'Could not check this spot.\n$e'),
            data: (v) => v == null
                ? const SizedBox.shrink()
                : v.isAmbiguous
                    ? _PickSide(verdict: v, pin: pin)
                    : _Answer(verdict: v),
          ),
        ),
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.verdict});
  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = verdict.status;
    final curb = verdict.curb;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(s.icon, color: s.color, size: 32),
          const SizedBox(width: 12),
          Text(s.label, style: theme.textTheme.headlineSmall?.copyWith(color: s.color)),
        ]),
        if (curb?.streetName != null) ...[
          const SizedBox(height: 4),
          Text('${curb!.streetName} · ${curb.side}', style: theme.textTheme.bodySmall),
        ],
        if (verdict.reason != null) ...[
          const SizedBox(height: 8),
          Text(verdict.reason!, style: theme.textTheme.bodyLarge),
        ],
        if (verdict.validUntil != null) ...[
          const SizedBox(height: 4),
          Text('Until ${TimeOfDay.fromDateTime(verdict.validUntil!.toLocal()).format(context)}'),
        ],
        if (verdict.disclaimer != null) ...[
          const SizedBox(height: 8),
          Text(verdict.disclaimer!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// Tap landed between two sides of the street: let the user pick.
class _PickSide extends ConsumerWidget {
  const _PickSide({required this.verdict, required this.pin});
  final Verdict verdict;
  final PinQuery pin;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Which side of the street?', style: Theme.of(context).textTheme.titleMedium),
          for (final c in verdict.candidates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.streetName ?? 'Segment ${c.segmentId}'),
              subtitle: Text('${c.side} · ${c.distanceM} m'),
              onTap: () => ref.read(pinProvider.notifier).set(
                    PinQuery(lat: pin.lat, lon: pin.lon, mode: pin.mode, segmentId: c.segmentId),
                  ),
            ),
        ],
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) =>
      Row(children: [Icon(icon), const SizedBox(width: 12), Expanded(child: Text(text))]);
}
