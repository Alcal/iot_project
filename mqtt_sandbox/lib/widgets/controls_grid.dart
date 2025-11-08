import 'package:flutter/material.dart';

import 'control_button.dart';

class ControlsGrid extends StatelessWidget {
  static const Map<String, int> keyMap = {
    'RIGHT': 0,
    'LEFT': 1,
    'UP': 2,
    'DOWN': 3,
    'A': 4,
    'B': 5,
    'SELECT': 6,
    'START': 7,
  };

  const ControlsGrid({
    super.key,
    required this.onKeyDown,
    required this.onKeyUp,
  });

  final void Function(int key) onKeyDown;
  final void Function(int key) onKeyUp;

  void _onKeyDown(String key) {
    onKeyDown(keyMap[key]!);
  }

  void _onKeyUp(String key) {
    onKeyUp(keyMap[key]!);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        final clusterGap = isWide ? 32.0 : 20.0;
        final rowPadding = isWide ? 8.0 : 6.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // D-Pad cluster (left)
                _buildDpad(),
                SizedBox(width: clusterGap),
                // A/B cluster (right)
                _buildABCluster(),
              ],
            ),
            SizedBox(height: rowPadding * 2),
            // Start / Select centered beneath clusters, like Game Boy
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ControlButton(
                  label: 'SELECT',
                  onDown: () => _onKeyDown('SELECT'),
                  onUp: () => _onKeyUp('SELECT'),
                ),
                const SizedBox(width: 12),
                ControlButton(
                  label: 'START',
                  onDown: () => _onKeyDown('START'),
                  onUp: () => _onKeyUp('START'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // --- Clusters ---
  Widget _buildDpad() {
    // Classic cross layout: Up on top, Left/Right middle, Down on bottom
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Up
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 48),
            DButton(
              icon: Icons.keyboard_arrow_up,
              onDown: () => _onKeyDown('UP'),
              onUp: () => _onKeyUp('UP'),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 8),
        // Left - (center gap) - Right
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DButton(
              icon: Icons.keyboard_arrow_left,
              onDown: () => _onKeyDown('LEFT'),
              onUp: () => _onKeyUp('LEFT'),
            ),
            const SizedBox(width: 12),
            // center spacer to imply the pivot of the D-pad
            const SizedBox(width: 24, height: 24),
            const SizedBox(width: 12),
            DButton(
              icon: Icons.keyboard_arrow_right,
              onDown: () => _onKeyDown('RIGHT'),
              onUp: () => _onKeyUp('RIGHT'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Down
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 48),
            DButton(
              icon: Icons.keyboard_arrow_down,
              onDown: () => _onKeyDown('DOWN'),
              onUp: () => _onKeyUp('DOWN'),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ],
    );
  }

  Widget _buildABCluster() {
    // A/B diagonally offset (B upper-left, A lower-right) like the original
    return SizedBox(
      width: 160,
      height: 120,
      child: Stack(
        children: [
          // B (upper-left)
          Positioned(
            left: 16,
            bottom: 8,
            child: ActionButton(
              label: 'B',
              diameter: 64,
              onDown: () => _onKeyDown('B'),
              onUp: () => _onKeyUp('B'),
            ),
          ),
          // A (lower-right)
          Positioned(
            right: 16,
            top: 8,
            child: ActionButton(
              label: 'A',
              diameter: 64,
              onDown: () => _onKeyDown('A'),
              onUp: () => _onKeyUp('A'),
            ),
          ),
        ],
      ),
    );
  }
}
