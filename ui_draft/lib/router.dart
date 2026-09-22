import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'pages/welcome_page.dart';
import 'pages/interests_page.dart';
import 'pages/main_shell.dart';
import 'pages/feed_page.dart';
import 'pages/explore_page.dart';
import 'pages/volunteer_page.dart';
import 'pages/saved_page.dart';
import 'pages/profile_page.dart';

final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  initialLocation: '/welcome',
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomePage(),
    ),
    GoRoute(
      path: '/interests',
      builder: (context, state) => const InterestsPage(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/feed', builder: (context, state) => const FeedPage()),
        GoRoute(path: '/explore', builder: (context, state) => const ExplorePage()),
        GoRoute(path: '/volunteer', builder: (context, state) => const VolunteerPage()),
        GoRoute(path: '/saved', builder: (context, state) => const SavedPage()),
        GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
      ],
    ),
  ],
);
