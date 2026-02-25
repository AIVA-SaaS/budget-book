import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Login Page - TODO')),
      ),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Home Page - TODO')),
      ),
    ),
  ],
);
