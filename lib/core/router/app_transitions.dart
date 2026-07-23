import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Custom page transitions for PremFlix.
///
/// go_router lets each route supply its own [CustomTransitionPage]; these
/// factories keep every transition consistent while giving each kind of
/// navigation its own character:
///
///  * [fade] — ambient moves (splash → login, tab-level swaps).
///  * [slideUp] — modal-feeling pages (player, settings).
///  * [cinematic] — detail pages: fade + subtle scale + blur, so tapping
///    a poster feels like the page emerges from the artwork.
///
/// All curves are `easeOutCubic` family — fast start, gentle settle —
/// which reads as responsive at high refresh rates.
abstract final class AppTransitions {
  static const Duration _duration = Duration(milliseconds: 380);
  static const Duration _fastDuration = Duration(milliseconds: 260);

  /// Pure cross-fade.
  static CustomTransitionPage<T> fade<T>({
    required LocalKey key,
    required Widget child,
  }) =>
      CustomTransitionPage<T>(
        key: key,
        child: child,
        transitionDuration: _fastDuration,
        reverseTransitionDuration: _fastDuration,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
          opacity: CurveTween(curve: Curves.easeOut).animate(animation),
          child: child,
        ),
      );

  /// Slides in from the bottom with a fade — used for pages that behave
  /// like modals (player, settings) so dismissing them feels natural.
  static CustomTransitionPage<T> slideUp<T>({
    required LocalKey key,
    required Widget child,
  }) =>
      CustomTransitionPage<T>(
        key: key,
        child: child,
        transitionDuration: _duration,
        reverseTransitionDuration: _fastDuration,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );

  /// Detail-page transition: the incoming page fades in while scaling
  /// from 96%, and the outgoing page blurs slightly underneath. Combined
  /// with poster Hero animations this produces the "expand out of the
  /// card" effect without any shared state between pages.
  static CustomTransitionPage<T> cinematic<T>({
    required LocalKey key,
    required Widget child,
  }) =>
      CustomTransitionPage<T>(
        key: key,
        child: child,
        transitionDuration: _duration,
        reverseTransitionDuration: _fastDuration,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          // When another page is pushed on top of this one, recede and
          // blur slightly for depth.
          final receding = CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeInOut,
          );
          return AnimatedBuilder(
            animation: receding,
            builder: (context, page) {
              final blur = receding.value * 6;
              return ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Transform.scale(
                  scale: 1 - receding.value * 0.03,
                  child: page,
                ),
              );
            },
            child: FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                child: child,
              ),
            ),
          );
        },
      );
}
