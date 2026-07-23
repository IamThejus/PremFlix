import 'package:flutter/widgets.dart';

/// Height of the shell's top navigation bar content (excluding the status
/// bar). Shared so pages without a full-bleed hero can inset their
/// content beneath the floating bar.
const double kPremFlixNavBarHeight = 60;

/// Top inset a scrolling page should reserve so its first row clears the
/// floating navigation bar. Accounts for the status-bar / notch padding.
double premFlixContentTopInset(BuildContext context) =>
    MediaQuery.paddingOf(context).top + kPremFlixNavBarHeight;
