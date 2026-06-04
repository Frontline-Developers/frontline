import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();

const GDELT_API = "https://api.gdeltproject.org/api/v2/doc/doc";

const UKRAINE_LOCATIONS = [
  "kyiv",
  "kharkiv",
  "odesa",
  "zaporizhzhia",
  "lviv",
  "mariupol",
  "donetsk",
  "luhansk",
  "kherson",
  "mykolaiv",
  "dnipro",
  "sumy",
  "chernihiv",
  "kramatorsk",
  "bakhmut",
  "avdiivka",
  "bucha",
  "irpin",
  "melitopol",
  "crimea",
  "donbas",
  "ukraine",
];

const THEME_KEYWORDS: Record<string, string[]> = {
  combat: [
    "attack",
    "strike",
    "missile",
    "bomb",
    "shell",
    "killed",
    "wounded",
    "troops",
    "battle",
    "offensive",
    "drone",
    "explosion",
    "artillery",
    "shelling",
    "fire",
  ],
  aid: [
    "humanitarian",
    "aid",
    "relief",
    "food",
    "medical",
    "corridor",
    "supplies",
  ],
  alert: ["warning", "alert", "emergency", "evacuation"],
  displaced: ["displaced", "refugee", "fleeing", "civilians"],
  infra: [
    "power",
    "electricity",
    "grid",
    "bridge",
    "railway",
    "infrastructure",
    "blackout",
    "plant",
  ],
};

const NEGATIVE_WORDS = [
  "killed",
  "dead",
  "wounded",
  "destroyed",
  "attack",
  "bomb",
  "strike",
  "death",
  "casualties",
  "shelling",
  "explosion",
  "massacre",
];
const POSITIVE_WORDS = [
  "aid",
  "relief",
  "peace",
  "ceasefire",
  "rescued",
  "liberated",
  "victory",
  "restored",
  "freed",
];

const SOURCE_NAMES: Record<string, string> = {
  "reuters.com": "Reuters",
  "bbc.com": "BBC",
  "bbc.co.uk": "BBC",
  "apnews.com": "AP News",
  "theguardian.com": "The Guardian",
  "aljazeera.com": "Al Jazeera",
  "nytimes.com": "New York Times",
  "washingtonpost.com": "Washington Post",
  "cnn.com": "CNN",
  "kyivindependent.com": "Kyiv Independent",
  "pravda.com.ua": "Ukrainska Pravda",
  "ukrinform.net": "Ukrinform",
  "rferl.org": "Radio Free Europe",
  "axios.com": "Axios",
};

// Higher = preferred when deduplicating same-title articles.
const SOURCE_PRIORITY: Record<string, number> = {
  "reuters.com": 10,
  "apnews.com": 10,
  "bbc.com": 9,
  "bbc.co.uk": 9,
  "kyivindependent.com": 9,
  "theguardian.com": 8,
  "aljazeera.com": 8,
  "nytimes.com": 8,
  "pravda.com.ua": 8,
  "ukrinform.net": 8,
  "rferl.org": 8,
  "washingtonpost.com": 7,
  "cnn.com": 7,
  "axios.com": 7,
};

function sourcePriority(domain: string): number {
  return SOURCE_PRIORITY[domain] ?? 1;
}

// Normalise a title to a short key for deduplication — strips punctuation,
// lowercases, and takes the first 60 chars so minor wording differences still match.
function normaliseTitle(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 60);
}

// Keep only the highest-priority source when multiple articles share a title.
function deduplicateByTitle(articles: GdeltArticle[]): GdeltArticle[] {
  const best = new Map<string, GdeltArticle>();
  for (const article of articles) {
    const key = normaliseTitle(article.title);
    const existing = best.get(key);
    if (
      !existing ||
      sourcePriority(article.domain) > sourcePriority(existing.domain)
    ) {
      best.set(key, article);
    }
  }
  return [...best.values()];
}

interface GdeltArticle {
  url: string;
  title: string;
  seendate: string; // YYYYMMDDTHHMMSSZ
  domain: string;
  language: string;
  sourcecountry: string;
}

interface GdeltResponse {
  articles?: GdeltArticle[];
}

function extractLocations(text: string): string[] {
  const lower = text.toLowerCase();
  return UKRAINE_LOCATIONS.filter((loc) => lower.includes(loc));
}

function extractThemes(text: string): string[] {
  const lower = text.toLowerCase();
  return Object.entries(THEME_KEYWORDS)
    .filter(([, keywords]) => keywords.some((k) => lower.includes(k)))
    .map(([theme]) => theme);
}

function computeTone(text: string): number {
  const lower = text.toLowerCase();
  const words = lower.split(/\W+/);
  const neg = words.filter((w) => NEGATIVE_WORDS.includes(w)).length;
  const pos = words.filter((w) => POSITIVE_WORDS.includes(w)).length;
  if (neg + pos === 0) return 0;
  return Math.round(((pos - neg) / (pos + neg)) * 100);
}

function parseSeenDate(seendate: string): Date {
  const y = seendate.slice(0, 4);
  const mo = seendate.slice(4, 6);
  const d = seendate.slice(6, 8);
  const h = seendate.slice(9, 11);
  const mi = seendate.slice(11, 13);
  const s = seendate.slice(13, 15);
  return new Date(`${y}-${mo}-${d}T${h}:${mi}:${s}Z`);
}

// Stable doc ID from URL for deduplication — base64 then trim to 20 chars.
function urlToDocId(url: string): string {
  return Buffer.from(url).toString("base64").replace(/[/+=]/g, "").slice(0, 20);
}

// Fetch the og:image meta tag from an article URL. Returns null on any failure.
async function fetchOgImage(url: string): Promise<string | null> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 3000);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: {"User-Agent": "Frontline-NewsAggregator/1.0"},
    });
    if (!res.ok) return null;
    const html = await res.text();
    // Match both attribute orders: property then content, or content then property
    const match =
      html.match(
        /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i,
      ) ??
      html.match(
        /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i,
      );
    const raw = match?.[1];
    if (!raw) return null;
    try {
      return new URL(raw, url).toString();
    } catch {
      return raw;
    }
  } catch {
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

// Fetch og:images for a batch of URLs with limited concurrency.
async function fetchOgImages(urls: string[]): Promise<(string | null)[]> {
  const results: (string | null)[] = new Array(urls.length).fill(null);
  const concurrency = 8;
  for (let i = 0; i < urls.length; i += concurrency) {
    const slice = urls.slice(i, i + concurrency);
    const fetched = await Promise.all(slice.map(fetchOgImage));
    fetched.forEach((img, j) => {
      results[i + j] = img;
    });
  }
  return results;
}

export const fetchGdeltNews = onSchedule(
  {schedule: "every 30 minutes", region: "asia-southeast1"},
  async () => {
    const params = new URLSearchParams({
      query: "Ukraine conflict sourcelang:english",
      mode: "ArtList",
      maxrecords: "50",
      format: "json",
      sortby: "datedesc",
    });

    const headers = {"User-Agent": "Frontline-NewsAggregator/1.0"};

    let articles: GdeltArticle[] = [];
    try {
      let res = await fetch(`${GDELT_API}?${params}`, {headers});

      // GDELT returns HTTP 200 with a plain-text rate limit message instead of JSON.
      // Detect this by checking Content-Type, and retry after 6s if hit.
      const contentType = res.headers.get("content-type") ?? "";
      if (!contentType.includes("json")) {
        const body = await res.text();
        logger.warn(
          "fetchGdeltNews: non-JSON response (likely rate limit), retrying in 6s:",
          body.slice(0, 120),
        );
        await new Promise((r) => setTimeout(r, 6000));
        res = await fetch(`${GDELT_API}?${params}`, {headers});
      }

      if (!res.ok) {
        logger.error("fetchGdeltNews: GDELT API returned", res.status);
        return;
      }

      const ct2 = res.headers.get("content-type") ?? "";
      if (!ct2.includes("json")) {
        const body = await res.text();
        logger.error(
          "fetchGdeltNews: still non-JSON after retry:",
          body.slice(0, 120),
        );
        return;
      }

      const data = (await res.json()) as GdeltResponse;
      articles = data.articles ?? [];
      logger.info(
        `fetchGdeltNews: GDELT returned ${articles.length} total articles`,
      );
    } catch (err) {
      logger.error("fetchGdeltNews: fetch failed", err);
      return;
    }

    if (articles.length > 0) {
      logger.info(
        "fetchGdeltNews: sample language values:",
        articles.slice(0, 3).map((a) => a.language),
      );
    }
    const english = articles.filter(
      (a) => !a.language || a.language.toLowerCase() === "english",
    );
    if (english.length === 0) {
      logger.info(
        "fetchGdeltNews: no English articles — languages seen:",
        [...new Set(articles.map((a) => a.language))].join(", "),
      );
      return;
    }

    // Drop articles that are the same story syndicated across many sources.
    const unique = deduplicateByTitle(english);
    logger.info(
      `fetchGdeltNews: ${english.length} English → ${unique.length} unique stories after dedup`,
    );

    // Fetch og:images in parallel (capped concurrency) before writing to Firestore.
    const imageUrls = await fetchOgImages(unique.map((a) => a.url));

    const db = admin.firestore();
    const batch = db.batch();
    let written = 0;

    for (let i = 0; i < unique.length; i++) {
      const article = unique[i];
      const text = article.title;
      const docId = urlToDocId(article.url);
      const ref = db.collection("wire_news").doc(docId);

      // New article — write full document.
      const doc: Record<string, unknown> = {
        title: text,
        url: article.url,
        source: "wire",
        sourceName: SOURCE_NAMES[article.domain] ?? article.domain,
        sourceDomain: article.domain,
        locations: extractLocations(text),
        themes: extractThemes(text),
        tone: computeTone(text),
        publishedAt: admin.firestore.Timestamp.fromDate(
          parseSeenDate(article.seendate),
        ),
      };
      if (imageUrls[i]) doc["imageUrl"] = imageUrls[i];

      // merge:true — updates the provided fields without deleting unspecified ones.
      // Note: existing values for provided fields can still be overwritten.
      batch.set(ref, doc, {merge: true});
      written++;
    }

    await batch.commit();
    const withImages = imageUrls.filter(Boolean).length;
    logger.info(
      `fetchGdeltNews: wrote ${written} unique articles (${withImages} with images)`,
    );
  },
);
