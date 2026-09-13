import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/utils/password_strength.dart';

/// A four-segment bar plus a verdict, showing how a password is doing.
///
/// Deliberately encouraging rather than punitive: it appears only once the user
/// has started typing, and the checklist says what is still missing instead of
/// only reporting the first failure.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({
    super.key,
    required this.password,
    this.showChecklist = true,
  });

  final String password;

  /// Lists the individual rules and ticks them off as they are met.
  final bool showChecklist;

  static const int _segments = 4;

  Color _strengthColor(BuildContext context, PasswordStrength strength) {
    final colors = context.colors;
    return switch (strength) {
      PasswordStrength.none => colors.mutedBorder,
      PasswordStrength.weak => context.scheme.error,
      PasswordStrength.fair => colors.warning,
      PasswordStrength.good => colors.accent,
      PasswordStrength.strong => colors.success,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strength = evaluatePasswordStrength(password);
    final colors = context.colors;
    final tint = _strengthColor(context, strength);
    final filledSegments = (strength.fraction * _segments).round();

    return AnimatedSize(
      duration: Motion.fast,
      curve: Motion.move,
      alignment: Alignment.topCenter,
      child: password.isEmpty
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              label: 'Password strength: ${strength.label}',
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: Insets.xs,
                    left: Insets.md,
                    right: Insets.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < _segments; i++) ...[
                            Expanded(
                              child: AnimatedContainer(
                                duration: Motion.fast,
                                curve: Motion.move,
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: i < filledSegments
                                      ? tint
                                      : colors.mutedBorder,
                                ),
                              ),
                            ),
                            if (i < _segments - 1)
                              const SizedBox(width: Insets.xxs),
                          ],
                        ],
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        strength.label,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: tint),
                      ),
                      if (showChecklist) ...[
                        const SizedBox(height: Insets.xxs),
                        ...passwordRequirements.map(
                          (requirement) => _RequirementRow(
                            requirement: requirement,
                            isMet: requirement.isSatisfiedBy(password),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.requirement, required this.isMet});

  final PasswordRequirement requirement;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = isMet ? colors.success : colors.subtleText;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 13,
            color: tint,
          ),
          const SizedBox(width: Insets.xxs),
          Flexible(
            child: Text(
              requirement.description,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: tint),
            ),
          ),
        ],
      ),
    );
  }
}
