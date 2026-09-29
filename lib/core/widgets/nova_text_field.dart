import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The Signal form field: a label, a line, and the space around them.
///
/// Every auth field goes through this, which is what makes three things
/// true everywhere at once rather than per screen:
///
/// - **The error is visible.** Material's default `errorStyle` can collapse
///   to nothing and swallow the message; the theme sets a real one and this
///   widget leaves room for it, so a field that rejects input says why.
/// - **`autovalidateMode` is onUserInteraction.** A form that turns red
///   before anyone has typed is scolding; one that only complains on submit
///   makes people hunt. Validating once a field has been touched is the
///   middle, and it is the default here so no screen has to remember.
/// - **Autofill and keyboard actions are set.** A password manager can fill
///   these, and the keyboard's action key moves to the next field rather
///   than dismissing.
class NovaTextField extends StatefulWidget {
  const NovaTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLength,
    this.inputFormatters,
    this.onSubmitted,
    this.onChanged,
    this.prefixIcon,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;

  /// Sits under the field until an error replaces it. Use it for a rule
  /// the person should know before they break it.
  final String? helper;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final List<String>? autofillHints;

  /// Adds the reveal toggle as well as hiding the text.
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final IconData? prefixIcon;

  @override
  State<NovaTextField> createState() => _NovaTextFieldState();
}

class _NovaTextFieldState extends State<NovaTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTypography.label.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          // See the class comment: this is the reason the widget exists.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.enabled ? widget.autofillHints : null,
          obscureText: _hidden,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          onFieldSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          style: AppTypography.body.copyWith(color: colors.textPrimary),
          cursorColor: colors.action,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            counterText: '',
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 32),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    splashRadius: 20,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
