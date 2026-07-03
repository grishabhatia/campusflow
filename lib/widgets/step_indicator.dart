import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(totalSteps, (index) {
            final isCompleted = index < currentStep;
            final isActive = index == currentStep;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      decoration: BoxDecoration(
                        color: isCompleted || isActive
                            ? Colors.blue
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (index < totalSteps - 1) const SizedBox(width: 4),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Step ${currentStep + 1} of $totalSteps',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}