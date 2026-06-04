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

const METADATA_COLLECTION = "metadata";
const METADATA_DOC = "wire_news";
const DEFAULT_FETCH_INTERVAL_HOURS = 24;

export function sourcePriority(domain: string): number {
  return SOURCE_PRIORITY[domain] ?? 1;
}

// Normalise a title to a short key for deduplication — strips punctuation,
// lowercases, and takes the first 60 chars so minor wording differences still match.
export function normaliseTitle(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 60);
}

export function titleToDocId(title: string): string {
  return Buffer.from(normaliseTitle(title))
    .toString("base64")
    .replace(/[/+=]/g, "")
    .slice(0, 32);
}

// Remove exact URL duplicates that GDELT occasionally returns in one batch.
export function deduplicateByUrl(articles: GdeltArticle[]): GdeltArticle[] {
  const seen = new Set<string>();
  return articles.filter((a) => {
    if (seen.has(a.url)) return false;
    seen.add(a.url);
    return true;
  });
}

// Keep only the highest-priority source when multiple articles share a title.
export function deduplicateByTitle(articles: GdeltArticle[]): GdeltArticle[] {
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

// After og:images are fetched, drop articles that share an imageUrl — two
// articles with identical images are the same story under a different headline.
// Input articles must already be sorted by priority (highest first) so the
// best source is retained.
export function deduplicateByImageUrl(
  articles: GdeltArticle[],
  images: (string | null)[],
): {articles: GdeltArticle[]; images: (string | null)[]} {
  const seen = new Set<string>();
  const keptArticles: GdeltArticle[] = [];
  const keptImages: (string | null)[] = [];
  for (let i = 0; i < articles.length; i++) {
    const img = images[i];
    if (img && seen.has(img)) continue;
    if (img) seen.add(img);
    keptArticles.push(articles[i]);
    keptImages.push(img);
  }
  return {articles: keptArticles, images: keptImages};
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
  // GDELT seendate format: YYYYMMDDTHHMMSSZ — use a regex so format variants
  // (space separator, milliseconds, etc.) produce a clear error rather than
  // silently writing NaN components to Firestore.
  const m = seendate.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})/);
  if (!m) throw new Error(`Unrecognised seendate format: ${seendate}`);
  return new Date(`${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}Z`);
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

export async function fetchGdeltNewsHandler() {
  const db = admin.firestore();
  const metaRef = db.collection(METADATA_COLLECTION).doc(METADATA_DOC);
  const metaSnap = await metaRef.get();
  const metaData = metaSnap.exists ? metaSnap.data() : undefined;
  const intervalHours =
    Number(metaData?.fetchIntervalHours) || DEFAULT_FETCH_INTERVAL_HOURS;
  const lastFetchedAt = metaData?.lastFetchedAt as
    | admin.firestore.Timestamp
    | undefined;
  const now = new Date();

  if (lastFetchedAt) {
    const nextFetch = new Date(
      lastFetchedAt.toDate().getTime() + intervalHours * 3600000,
    );
    if (now < nextFetch) {
      logger.info(
        "fetchGdeltNews: skipping fetch until",
        nextFetch.toISOString(),
        `(${intervalHours}h interval)`,
      );
      return;
    }
  }

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
    await metaRef.set(
      {
        lastFetchedAt: admin.firestore.Timestamp.now(),
        fetchIntervalHours: intervalHours,
        updatedAt: admin.firestore.Timestamp.now(),
      },
      {merge: true},
    );
    return;
  }

  // Three-stage dedup:
  // 1. URL — GDELT occasionally returns the same URL twice in one batch.
  // 2. Title — same story syndicated across sources; keep highest-priority source.
  // 3. ImageUrl — different headlines that share an og:image are the same story.
  const urlDeduped = deduplicateByUrl(english);
  // Sort by priority before title dedup so the Map retains the best source.
  const titleDeduped = deduplicateByTitle(urlDeduped).sort(
    (a, b) => sourcePriority(b.domain) - sourcePriority(a.domain),
  );
  logger.info(
    `fetchGdeltNews: ${english.length} English → ${urlDeduped.length} URL-unique → ${titleDeduped.length} title-unique`,
  );

  // Fetch og:images in parallel (capped concurrency) before writing to Firestore.
  const rawImageUrls = await fetchOgImages(titleDeduped.map((a) => a.url));

  // Stage 3: drop articles that share an og:image (same photo = same story).
  const {articles: unique, images: imageUrls} = deduplicateByImageUrl(
    titleDeduped,
    rawImageUrls,
  );
  logger.info(
    `fetchGdeltNews: ${titleDeduped.length} title-unique → ${unique.length} image-unique`,
  );

  const batch = db.batch();
  let written = 0;

  for (let i = 0; i < unique.length; i++) {
    const article = unique[i];
    const text = article.title;
    const docId = titleToDocId(article.title);
    const ref = db.collection("wire_news").doc(docId);
    const priority = sourcePriority(article.domain);

    const doc: Record<string, unknown> = {
      title: text,
      url: article.url,
      source: "wire",
      sourceName: SOURCE_NAMES[article.domain] ?? article.domain,
      sourceDomain: article.domain,
      sourcePriority: priority,
      storyKey: normaliseTitle(text),
      locations: extractLocations(text),
      themes: extractThemes(text),
      tone: computeTone(text),
      publishedAt: admin.firestore.Timestamp.fromDate(
        parseSeenDate(article.seendate),
      ),
      // Always write imageUrl (or delete stale value from a previous run).
      imageUrl: imageUrls[i] ?? admin.firestore.FieldValue.delete(),
    };

    batch.set(ref, doc, {merge: true});
    written++;
  }

  if (written > 0) {
    await batch.commit();
  }

  const withImages = imageUrls.filter((u) => u != null).length;
  const fetchTime = admin.firestore.Timestamp.now();
  await metaRef.set(
    {
      lastFetchedAt: fetchTime,
      fetchIntervalHours: intervalHours,
      sourceDomains: [...new Set(unique.map((a) => a.domain))],
      updatedAt: fetchTime,
    },
    {merge: true},
  );

  logger.info(
    `fetchGdeltNews: wrote ${written} unique articles (${withImages} with images)`,
  );
}

export const fetchGdeltNews = onSchedule(
  {schedule: "every 60 minutes", region: "asia-southeast1"},
  fetchGdeltNewsHandler,
);
