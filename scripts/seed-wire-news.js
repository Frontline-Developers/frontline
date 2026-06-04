#!/usr/bin/env node
// Seeds the Firestore emulator with wire news articles for testing Compare.
// Run while emulators are active: node scripts/seed-wire-news.js

process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';

// Use firebase-admin from the functions package
const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp({ projectId: 'frontline-549fb' });

const db = admin.firestore();
const Timestamp = admin.firestore.Timestamp;

const now = Date.now();
const hr = 3600 * 1000;

const articles = [
  {
    title: 'Russia launches missile strike on Kharkiv residential district',
    url: 'https://reuters.com/world/europe/kharkiv-strike-2026',
    sourceName: 'Reuters',
    sourceDomain: 'reuters.com',
    locations: ['kharkiv', 'ukraine'],
    themes: ['combat'],
    tone: -80,
    publishedAt: Timestamp.fromMillis(now - 2 * hr),
  },
  {
    title: 'Ukrainian forces repel attack near Kharkiv, officials say',
    url: 'https://bbc.com/news/world-europe-kharkiv-2026',
    sourceName: 'BBC',
    sourceDomain: 'bbc.com',
    locations: ['kharkiv', 'ukraine'],
    themes: ['combat'],
    tone: -40,
    publishedAt: Timestamp.fromMillis(now - 1.5 * hr),
  },
  {
    title: 'Kharkiv power grid damaged in overnight shelling, blackouts reported',
    url: 'https://kyivindependent.com/kharkiv-power-grid-2026',
    sourceName: 'Kyiv Independent',
    sourceDomain: 'kyivindependent.com',
    locations: ['kharkiv', 'ukraine'],
    themes: ['combat', 'infra'],
    tone: -70,
    publishedAt: Timestamp.fromMillis(now - 1 * hr),
  },
  {
    title: 'Humanitarian aid convoy reaches Kharkiv amid ongoing attacks',
    url: 'https://apnews.com/kharkiv-aid-2026',
    sourceName: 'AP News',
    sourceDomain: 'apnews.com',
    locations: ['kharkiv', 'ukraine'],
    themes: ['aid'],
    tone: 20,
    publishedAt: Timestamp.fromMillis(now - 0.5 * hr),
  },
  {
    title: 'Artillery fire reported in Donetsk region as front line shifts',
    url: 'https://reuters.com/donetsk-front-2026',
    sourceName: 'Reuters',
    sourceDomain: 'reuters.com',
    locations: ['donetsk', 'donbas', 'ukraine'],
    themes: ['combat'],
    tone: -60,
    publishedAt: Timestamp.fromMillis(now - 4 * hr),
  },
  {
    title: 'Kyiv reports drone strike intercepted over city centre',
    url: 'https://theguardian.com/kyiv-drone-2026',
    sourceName: 'The Guardian',
    sourceDomain: 'theguardian.com',
    locations: ['kyiv', 'ukraine'],
    themes: ['combat', 'alert'],
    tone: -50,
    publishedAt: Timestamp.fromMillis(now - 3 * hr),
  },
  {
    title: 'Zaporizhzhia nuclear plant operator reports external power restored',
    url: 'https://ukrinform.net/zaporizhzhia-power-2026',
    sourceName: 'Ukrinform',
    sourceDomain: 'ukrinform.net',
    locations: ['zaporizhzhia', 'ukraine'],
    themes: ['infra'],
    tone: 30,
    publishedAt: Timestamp.fromMillis(now - 5 * hr),
  },
  {
    title: 'Thousands displaced as fighting intensifies in Luhansk region',
    url: 'https://aljazeera.com/luhansk-displaced-2026',
    sourceName: 'Al Jazeera',
    sourceDomain: 'aljazeera.com',
    locations: ['luhansk', 'donbas', 'ukraine'],
    themes: ['displaced', 'combat'],
    tone: -75,
    publishedAt: Timestamp.fromMillis(now - 6 * hr),
  },
];

async function seed() {
  const batch = db.batch();
  for (const article of articles) {
    const docId = Buffer.from(article.url).toString('base64').replace(/[/+=]/g, '').slice(0, 20);
    batch.set(db.collection('wire_news').doc(docId), { ...article, source: 'wire' });
  }
  await batch.commit();
  console.log(`✓ Seeded ${articles.length} wire_news articles into emulator Firestore.`);
}

seed().catch(err => { console.error(err); process.exit(1); });
