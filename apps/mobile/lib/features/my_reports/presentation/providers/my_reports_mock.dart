import '../../domain/entities/my_report.dart';
import 'my_reports_provider.dart';

// ── Mock data ─────────────────────────────────────────────────────────────────
// Totals: 557 confirms · 11,032 views · 2 verified · 3 pending · 1 disputed

final kMockMyReports = <MyReport>[
  MyReport(
    id: 'rpt_001',
    title:
        'Strike on substation, Saltivka district — power out across 4 blocks',
    body:
        'Heard the impact at 03:42. Transformer building on Akademika Pavlova is on fire. Two ambulances on scene now.\n\nI\'m staying in the area and can see emergency crews still working. Will update if the situation changes. Posting anonymously through Frontline so this can\'t be traced back to me.',
    snippet:
        'Heard the impact at 03:42. Transformer building on Akademika Pavlova is on fire....',
    category: 'infra',
    location: 'Kharkiv · Saltivka',
    photos: [],
    status: 'verified',
    confirms: 412,
    flags: 2,
    views: 8421,
    token: 'r7g2-k4mn-vddt-zyxi',
    submittedAt: DateTime(2025, 3, 18, 3, 46),
    commentCount: 8,
    previewCommentToken: 'token #h8m2',
    previewCommentContent:
        'I\'m two streets over on Heroiv Pratsi. Confirmed power cut, can see the fire from my balcony. Ambulances heading toward Pavlova.',
    previewCommentAt: DateTime(2025, 3, 18, 3, 50),
  ),
  MyReport(
    id: 'rpt_002',
    title:
        'Aid convoy arriving at school No. 142 — water and bread distribution',
    body:
        'Five trucks marked Red Cross unloading now. Line of ~200 people. Mostly elderly.\n\nDistribution organised by local volunteers. Bread, water, and canned goods. They say they\'ll be here until supplies run out.',
    snippet:
        'Five trucks marked Red Cross unloading now. Line of ~200 people. Mostly elderly.',
    category: 'aid',
    location: 'Kherson · Korabelnyi',
    photos: [],
    status: 'pending',
    confirms: 12,
    flags: 0,
    views: 287,
    token: 'm4p9-bxq3-foxt-ddph',
    submittedAt: DateTime(2025, 3, 20, 13, 11),
    commentCount: 2,
    previewCommentToken: 'token #a3f1',
    previewCommentContent:
        'Can confirm — I was in the line. Very orderly, staff were helpful.',
    previewCommentAt: DateTime(2025, 3, 20, 13, 40),
  ),
  MyReport(
    id: 'rpt_003',
    title: 'Counter-claim: residential building, not military depot',
    body:
        'Neighbours confirm no military presence in building 31b. Civilians only — three families including elderly residents.\n\nCould this be a controlled demolition? No confirmation this is a strike. Community is disputing the original claim.',
    snippet:
        'Neighbours confirm no military presence in building 31b. Civilians only.',
    category: 'combat',
    location: 'Kharkiv · Industrialnyi',
    photos: [],
    status: 'disputed',
    confirms: 67,
    flags: 89,
    views: 1244,
    token: 'tk2n-9hxa-cdkv-dkc2',
    submittedAt: DateTime(2025, 3, 22, 6, 48),
    commentCount: 28,
    previewCommentToken: 'token #z9q4',
    previewCommentContent:
        'I live next door — this building has been civilian housing for 10 years. No military activity observed.',
    previewCommentAt: DateTime(2025, 3, 22, 7, 15),
  ),
  MyReport(
    id: 'rpt_004',
    title: 'Curfew restored after siren — all clear at 21:47',
    body:
        'Curfew started 20:14. Family went to shelter at 20:18. No impacts here in Novobavarskyi. Heard two distant bangs at 21:03 — direction unclear. All clear sounded at 21:47.',
    snippet:
        'Curfew started 20:14. Heard two distant bangs at 21:03. All clear at 21:47.',
    category: 'alert',
    location: 'Kharkiv · Novobavarskyi',
    photos: [],
    status: 'pending',
    confirms: 47,
    flags: 2,
    views: 612,
    token: 'trvk-3cwc-tdkv-rybt',
    submittedAt: DateTime(2025, 3, 21, 21, 52),
    commentCount: 7,
    previewCommentToken: 'token #b2w7',
    previewCommentContent:
        'Same here on Hvardiytsiv Shyrokokhyvtsiv. All clear confirmed.',
    previewCommentAt: DateTime(2025, 3, 21, 22, 1),
  ),
  MyReport(
    id: 'rpt_005',
    title: 'Water pressure dropped — pumping station may be offline',
    body:
        'Whole apartment block lost water at 14:35. Building manager says pumping station on Akademika Pavlova may have been hit. No official update yet.\n\nNeighbouring buildings also affected according to residents in the courtyard.',
    snippet:
        'Whole apartment block lost water at 14:35. Pumping station on Akademika Pavlova offline.',
    category: 'infra',
    location: 'Kharkiv · Centralnyi',
    photos: [],
    status: 'pending',
    confirms: 14,
    flags: 22,
    views: 380,
    token: 'plmx-9wqr-nnbs-cotz',
    submittedAt: DateTime(2025, 3, 22, 14, 40),
    commentCount: 3,
    previewCommentToken: 'token #f5k9',
    previewCommentContent:
        'Same on our street. No water since afternoon. Building management not responding.',
    previewCommentAt: DateTime(2025, 3, 22, 15, 10),
  ),
  MyReport(
    id: 'rpt_006',
    title: 'Roughly 30 people sheltering in metro station',
    body:
        'Mostly from Pavlove Pole neighbourhood. Families with children, several elderly. Brought food for two days. Station staff present and helpful.',
    snippet:
        'Mostly from Pavlove Pole neighbourhood. Families with children, several elderly.',
    category: 'displaced',
    location: 'Kharkiv · Metro station',
    photos: [],
    status: 'pending',
    confirms: 5,
    flags: 0,
    views: 88,
    token: 'grkt-bwdi-ztyk-plcx',
    submittedAt: DateTime(2025, 3, 19, 9, 5),
    commentCount: 1,
    previewCommentToken: 'token #r3m2',
    previewCommentContent:
        'I saw them arriving — there were actually closer to 40 people.',
    previewCommentAt: DateTime(2025, 3, 19, 9, 30),
  ),
];

// ── Fake notifier ─────────────────────────────────────────────────────────────

class FakeMyReportsNotifier extends MyReportsNotifier {
  @override
  MyReportsState build() {
    return MyReportsState(reports: kMockMyReports, isLoading: false);
  }
}
