import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iot_gameboy/services/mqtt_services.dart';

class TallyGraph extends StatelessWidget {
  const TallyGraph({super.key});

  static const List<String> _indexToLabel = <String>[
    'RIGHT',
    'LEFT',
    'UP',
    'DOWN',
    'A',
    'B',
    'SELECT',
    'START',
  ];

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MqttService>();
    return StreamBuilder<List<int>>(
      stream: svc.tallyStream,
      builder: (context, snapshot) {
        final tally = snapshot.data ?? const <int>[];
        return _TallyBar(tally: tally);
      },
    );
  }
}

class _TallyBar extends StatelessWidget {
  const _TallyBar({required this.tally});

  final List<int> tally;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tally.isEmpty || tally.every((v) => v == 0)) {
      return Container(
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black26),
        ),
        alignment: Alignment.center,
        child: const Text(
          'No votes yet',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    // Build list of (index, count), sort by count desc then index asc
    final indexed = <(int, int)>[];
    for (var i = 0; i < tally.length; i++) {
      indexed.add((i, tally[i]));
    }
    indexed.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });

    final top1 = indexed[0];
    final top2 = indexed.length > 1 ? indexed[1] : (top1.$1, 0);
    final others = indexed.skip(2).fold<int>(0, (sum, e) => sum + e.$2);
    final sum = (top1.$2 + top2.$2 + others).clamp(1, 0x7fffffff);

    // Fractions
    final f1 = top1.$2 / sum;
    final f2 = top2.$2 / sum;
    final fo = others / sum;

    final label1 = TallyGraph._indexToLabel.elementAt(
      top1.$1.clamp(0, TallyGraph._indexToLabel.length - 1),
    );
    final label2 = top2.$2 > 0
        ? TallyGraph._indexToLabel.elementAt(
            top2.$1.clamp(0, TallyGraph._indexToLabel.length - 1),
          )
        : null;

    // Colors
    final color1 = theme.colorScheme.primary;
    final color2 = theme.colorScheme.secondary;
    final colorOthers = Colors.black26;

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black26),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          if (f1 > 0)
            _Segment(fraction: f1, color: color1, label: '$label1 ${_pct(f1)}'),
          if (f2 > 0)
            _Segment(fraction: f2, color: color2, label: '$label2 ${_pct(f2)}'),
          if (fo > 0)
            _Segment(
              fraction: fo,
              color: colorOthers,
              label: fo >= 0.15 ? 'Others ${_pct(fo)}' : null,
            ),
        ],
      ),
    );
  }

  String _pct(double f) => '${(f * 100).round()}%';
}

class _Segment extends StatelessWidget {
  const _Segment({required this.fraction, required this.color, this.label});

  final double fraction;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: (fraction * 1000).round().clamp(1, 1000000),
      child: Container(
        color: color,
        alignment: Alignment.center,
        child: label == null
            ? const SizedBox.shrink()
            : Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  shadows: [Shadow(blurRadius: 2, color: Colors.black38)],
                ),
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}
