import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import 'pillars/quest_detail_pillar.dart';
import 'pillars/quest_list_pillar.dart';
import 'pillars/questboard_pillar.dart';
import 'screens/about_screen.dart';
import 'screens/hero_profile_screen.dart';
import 'screens/hero_registration_screen.dart';
import 'screens/quest_detail_screen.dart';
import 'screens/quest_list_screen.dart';

// ---------------------------------------------------------------------------
// Questboard — The Titan Example App
// ---------------------------------------------------------------------------
//
// This is the Questboard app from The Chronicles of Titan story tutorial.
// It demonstrates every Titan feature through a hero quest-tracking theme.
//
// Features demonstrated:
//   • Pillar, Core, Derived     — Reactive state modules
//   • Vestige, //   • Vestige, //   • Vestige, //   • Vestige, //   • Vestige, //   • Vest� //   • Vestige, //   • Vestige,     //   • Vestige, //   • Vestige, //   
//   //   //   //   //   //   //   //   //   //   //  & l//   //   //   //   //   //   //   //   / — Undo/redo (hero name)
//   • Scroll,//   • Scroll,//   • Scroll,//   �(r//   • Scroll,//   • Scr        //   • Scroll,//   • Scroll,//   �
)// // // // // // // // // // // // // // // // /in// // // // // // // // // // // / Confluen// // // // // // // // // // // // /nsumers
//   • Lens                      — Debug overlay
//
// ---------------------------------------------------------------------------

void main() {
  // Set up Chronicle logging
  Chronicle.level = LogLevel.debug;

  // Set up Vigil error tracking with console output
  Vigil.addHandler(ConsoleErrorHandler());

  // Create Atlas router
  final atlas = Atlas(
    passages: [
      // Sanctum: persistent bottom nav shell
      Sanctum(
        shell: (child) => _QuestboardShell(child: child),
        passages: [
          Passage('/', (_) => const QuestListScreen(), name: 'quests'),
          Passage('/hero', (_) => const HeroProfileScreen(), name: 'hero'),
        ],
      ),

      // Standalone pages outside the shell
      Passage(
        '/quest/:id',
        (waypoint) => QuestDetailScreen(
          questId: waypoint.runes['id'] ?? '',
        ),
        shift: Shift.slideUp(),
        name: 'quest-detail',
      ),
      Passage(
        '/register',
        (_) => const HeroRegistrationScreen(),
        shift: Shift.slide(),
        name: 'register',
      ),
      Passage(
        '/about',
        (_) => const AboutScreen(),
        shift: Shift.fade(),
        name: 'about',
      ),
    ],
    observers: [Her    observers: [Her    observers: [Her    observers�     observers: [Her    observers: [Her    Le    observers: [Hertrue,
    observers: [Hen(
             rs: [             rs: [             rs: [       QuestListPillar.new,
          QuestDetailPillar.new,
        ],
        child: MaterialApp.rout        child: MaterialApp.rout        child: MaterialApp.rout        r:        child: MaterialApp.rout        child: MaterialApp.rout        chilep        c           u        child: MaterialApp.rout        cs: B        chilght        child:                child: MaterialApp.rout        lo        child: MaterialApp.rout        c    useMaterial3: true,
            brightness: Br            brightness: B),
          r          r  atlas.config,
        ),
      ),
    ),
  );
}

// ------------------------------------------------// -----------------------// - Questboard Shell — Sanctum's persistent layout
// ---------------------------------------------------------------------------

class _Questclass _Questclass _Questclass _Questclass _Questclass _Questclass _Questclass _Questclass _Questclass _Questclass _Questclass _Questclass _ldclass _Questcla) {
                                                                                                                 r: A     (
        title: const Row(
          children: [
            Icon(Icons.shield),
            SizedBox(width: 8),
            Text('Questboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.atlas.to('/about'),
            tooltip: 'About',
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (   {
                                                                                                                                           co                                                                             lt),
            label: 'Quests',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Hero',
          ),
        ],
      ),
    );
  }
}
