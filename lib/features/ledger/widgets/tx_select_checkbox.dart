import 'package:flutter/material.dart';

class TxSelectCheckbox extends StatelessWidget {
  const TxSelectCheckbox({
    super.key,
    required this.selected,
  });

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: -4,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Checkbox(
          value: selected,
          onChanged: (_) {}, // 保持 enabled（避免 disabled 变灰）
          fillColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const Color(0xFF22C55E); // 绿色方块
            }
            return Colors.transparent;
          }),
          checkColor: Colors.black, // 黑色对勾
          side: const BorderSide(color: Colors.black, width: 1.5),
        ),
      ),
    );
  }
}