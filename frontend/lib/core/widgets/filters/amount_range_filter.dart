import 'package:flutter/material.dart';

/// Amount range input fields (min/max) for use within filter sheets.
class AmountRangeFilter extends StatelessWidget {
  final TextEditingController minController;
  final TextEditingController maxController;

  const AmountRangeFilter({
    super.key,
    required this.minController,
    required this.maxController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '금액 범위',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: minController,
                decoration: const InputDecoration(
                  labelText: '최소 금액',
                  hintText: '0',
                  suffixText: '원',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('~'),
            ),
            Expanded(
              child: TextField(
                controller: maxController,
                decoration: const InputDecoration(
                  labelText: '최대 금액',
                  hintText: '무제한',
                  suffixText: '원',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
