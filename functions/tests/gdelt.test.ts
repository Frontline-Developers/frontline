import * as admin from 'firebase-admin';
import {
  fetchGdeltNewsHandler,
  deduplicateByTitle,
  deduplicateByUrl,
  deduplicateByImageUrl,
  normaliseTitle,
  titleToDocId,
  sourcePriority,
} from '../src/gdelt';

const originalFetch = global.fetch;
const originalAdminFirestore = admin.firestore;
const GDELT_URL = 'https://api.gdeltproject.org/api/v2/doc/doc';

function makeJsonResponse(data: unknown) {
  return {
    ok: true,
    status: 200,
    headers: {get: (header: string) => (header.toLowerCase() === 'content-type' ? 'application/json' : null)},
    json: async () => data,
    text: async () => JSON.stringify(data),
  };
}

function makeTextResponse(text: string) {
  return {
    ok: true,
    status: 200,
    headers: {get: (header: string) => (header.toLowerCase() === 'content-type' ? 'text/plain' : null)},
    json: async () => { throw new Error('unexpected json parse'); },
    text: async () => text,
  };
}

function makeHtmlResponse(html: string) {
  return {
    ok: true,
    status: 200,
    headers: {get: (header: string) => (header.toLowerCase() === 'content-type' ? 'text/html' : null)},
    json: async () => { throw new Error('unexpected json parse'); },
    text: async () => html,
  };
}

type MetaData = {
  lastFetchedAt?: admin.firestore.Timestamp;
  fetchIntervalHours?: number;
};

type MockMetaRef = {
  get: jest.Mock<Promise<{exists: boolean; data: () => MetaData | undefined}>, []>;
  set: jest.Mock<Promise<void>, [unknown, unknown?]>;
};

type MockFirestoreState = {
  mockFirestore: {
    collection: (path: string) => {doc: (id: string) => MockMetaRef} | {doc: (id: string) => {id: string}};
    batch: jest.Mock<{set: (ref: {id: string}, doc: unknown, opts: unknown) => void; commit: Promise<void>}, []>;
  };
  metaRef: MockMetaRef;
  batchSet: jest.Mock<void, [{id: string}, unknown, unknown]>;
  commit: jest.Mock<Promise<void>, []>;
  wireWrites: Array<{id: string; doc: unknown; opts: unknown}>;
};

function createMockFirestore(metaData?: MetaData): MockFirestoreState {
  const metaRef = {
    get: jest.fn().mockResolvedValue({exists: metaData !== undefined, data: () => metaData}),
    set: jest.fn().mockResolvedValue(undefined),
  };
  const wireWrites: Array<{id: string; doc: unknown; opts: unknown}> = [];
  const batchSet = jest.fn((ref: {id: string}, doc: unknown, opts: unknown) => {
    wireWrites.push({id: ref.id, doc, opts});
  });
  const commit = jest.fn().mockResolvedValue(undefined);
  const mockFirestore = {
    collection: (path: string) => {
      if (path === 'metadata') {
        return {doc: () => metaRef};
      }
      if (path === 'wire_news') {
        return {
          doc: (id: string) => ({id}),
        };
      }
      throw new Error(`Unexpected collection: ${path}`);
    },
    batch: jest.fn(() => ({set: batchSet, commit})),
  };
  return {mockFirestore, metaRef, batchSet, commit, wireWrites};
}

function mockAdminFirestore(firestoreState: MockFirestoreState) {
  const spy = jest.spyOn(admin, 'firestore').mockImplementation(
    () => firestoreState.mockFirestore as unknown as admin.firestore.Firestore,
  );
  Object.assign(spy, {Timestamp: originalAdminFirestore.Timestamp});
}

describe('GDELT news API integration', () => {
  let fetchMock: jest.Mock;
  let firestoreState: MockFirestoreState;

  beforeEach(() => {
    fetchMock = jest.fn();
    Object.defineProperty(global, 'fetch', {
      configurable: true,
      value: fetchMock,
    });
    firestoreState = createMockFirestore();
    mockAdminFirestore(firestoreState);
    jest.useRealTimers();
  });

  afterEach(() => {
    jest.restoreAllMocks();
    Object.defineProperty(global, 'fetch', {
      configurable: true,
      value: originalFetch,
    });
  });

  test('skips fetch when metadata interval has not elapsed', async () => {
    const lastFetched = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60 * 60 * 1000));
    firestoreState = createMockFirestore({lastFetchedAt: lastFetched, fetchIntervalHours: 24});
    mockAdminFirestore(firestoreState);

    await fetchGdeltNewsHandler();

    expect(fetchMock).not.toHaveBeenCalled();
    expect(firestoreState.metaRef.set).not.toHaveBeenCalled();
  });

  test('stores metadata and skips writing wire_news when no English articles are returned', async () => {
    firestoreState = createMockFirestore();
    mockAdminFirestore(firestoreState);
    fetchMock.mockResolvedValue(makeJsonResponse({articles: [
      {
        url: 'https://example.com/spanish',
        title: 'Ataque en Ucrania',
        seendate: '20240101T120000Z',
        domain: 'example.com',
        language: 'spanish',
        sourcecountry: 'ES',
      },
    ]}));

    await fetchGdeltNewsHandler();

    expect(firestoreState.metaRef.set).toHaveBeenCalledTimes(1);
    expect(firestoreState.batchSet).not.toHaveBeenCalled();
    const metaWrite = firestoreState.metaRef.set.mock.calls[0][0];
    expect(metaWrite.fetchIntervalHours).toBe(24);
    expect(metaWrite.lastFetchedAt).toBeDefined();
    expect(metaWrite.updatedAt).toBeDefined();
  });

  test('deduplicates same-story articles and writes exactly one wire_news document with imageUrl', async () => {
    firestoreState = createMockFirestore();
    mockAdminFirestore(firestoreState);

    fetchMock.mockImplementation(async (url: string) => {
      const requestUrl = String(url);
      if (requestUrl.startsWith(GDELT_URL)) {
        return makeJsonResponse({articles: [
          {
            url: 'https://example.com/article-a',
            title: 'Ukraine forces repel attack near city',
            seendate: '20240101T120000Z',
            domain: 'cnn.com',
            language: 'english',
            sourcecountry: 'US',
          },
          {
            url: 'https://example.com/article-b',
            title: 'Ukraine forces repel attack near city',
            seendate: '20240101T120500Z',
            domain: 'reuters.com',
            language: 'english',
            sourcecountry: 'US',
          },
        ]});
      }
      return makeHtmlResponse('<meta property="og:image" content="https://example.com/image.jpg">');
    });

    await fetchGdeltNewsHandler();

    expect(firestoreState.batchSet).toHaveBeenCalledTimes(1);
    expect(firestoreState.commit).toHaveBeenCalledTimes(1);
    expect(firestoreState.wireWrites).toHaveLength(1);
    expect(firestoreState.wireWrites[0].doc.sourcePriority).toBeGreaterThan(0);
    expect(firestoreState.wireWrites[0].doc.storyKey).toBe(normaliseTitle('Ukraine forces repel attack near city'));
    expect(firestoreState.wireWrites[0].doc.imageUrl).toBe('https://example.com/image.jpg');
    expect(firestoreState.metaRef.set).toHaveBeenCalledTimes(1);
    expect(firestoreState.metaRef.set.mock.calls[0][0].sourceDomains).toEqual(['reuters.com']);
  });

  test('retries after a non-json GDELT response and then succeeds', async () => {
    firestoreState = createMockFirestore();
    mockAdminFirestore(firestoreState);
    jest.useFakeTimers();

    fetchMock
      .mockResolvedValueOnce(makeTextResponse('rate limit'))
      .mockImplementation(async (url: string) => {
        if (String(url).startsWith(GDELT_URL)) {
          return makeJsonResponse({articles: [
            {
              url: 'https://example.com/article',
              title: 'Ukraine convoy advances',
              seendate: '20240101T120000Z',
              domain: 'reuters.com',
              language: 'english',
              sourcecountry: 'US',
            },
          ]});
        }
        return makeHtmlResponse('<meta property="og:image" content="https://example.com/image.jpg">');
      });

    const promise = fetchGdeltNewsHandler();
    await jest.advanceTimersByTimeAsync(6000);
    await promise;

    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(firestoreState.batchSet).toHaveBeenCalledTimes(1);
    expect(firestoreState.metaRef.set).toHaveBeenCalledTimes(1);
  });
});

describe('GDELT helper behavior', () => {
  test('normaliseTitle strips punctuation, whitespace, and lowercases', () => {
    const title = 'Ukraine: Attack, Evacuation — Reuters!';
    expect(normaliseTitle(title)).toBe('ukraine attack evacuation reuters');
  });

  test('titleToDocId is stable for the same normalized story title', () => {
    const titleA = 'Ukraine attack kills dozens in eastern city';
    const titleB = 'Ukraine attack kills dozens in eastern city.';
    expect(titleToDocId(titleA)).toBe(titleToDocId(titleB));
    expect(titleToDocId(titleA).length).toBeGreaterThanOrEqual(1);
  });

  test('deduplicateByTitle keeps only the highest-priority source for the same story', () => {
    const articleA = {
      url: 'https://example.com/article-a',
      title: 'Ukraine forces repel attack near city',
      seendate: '20240101T120000Z',
      domain: 'cnn.com',
      language: 'english',
      sourcecountry: 'US',
    };
    const articleB = {
      url: 'https://example.com/article-b',
      title: 'Ukraine forces repel attack near city',
      seendate: '20240101T120500Z',
      domain: 'reuters.com',
      language: 'english',
      sourcecountry: 'US',
    };

    const result = deduplicateByTitle([articleA, articleB]);
    expect(result).toHaveLength(1);
    expect(result[0].domain).toBe('reuters.com');
  });

  test('deduplicateByTitle treats slightly different punctuation as the same story', () => {
    const articleA = {
      url: 'https://example.com/a',
      title: 'Ukraine forces repel attack near city',
      seendate: '20240101T121000Z',
      domain: 'bbc.com',
      language: 'english',
      sourcecountry: 'GB',
    };
    const articleB = {
      url: 'https://example.com/b',
      title: 'Ukraine forces repel attack near city.',
      seendate: '20240101T121500Z',
      domain: 'kyivindependent.com',
      language: 'english',
      sourcecountry: 'UA',
    };

    const result = deduplicateByTitle([articleA, articleB]);
    expect(result).toHaveLength(1);
    expect(titleToDocId(result[0].title)).toBe(titleToDocId(articleA.title));
  });

  test('sourcePriority prefers higher-ranked sources for duplicate titles', () => {
    expect(sourcePriority('reuters.com')).toBeGreaterThan(sourcePriority('cnn.com'));
    expect(sourcePriority('unknown.com')).toBe(1);
  });

  test('deduplicateByUrl removes exact URL duplicates, keeping first occurrence', () => {
    const a = {url: 'https://reuters.com/story', title: 'A', seendate: '20240101T120000Z', domain: 'reuters.com', language: 'english', sourcecountry: 'US'};
    const b = {url: 'https://reuters.com/story', title: 'A (updated)', seendate: '20240101T121000Z', domain: 'reuters.com', language: 'english', sourcecountry: 'US'};
    const c = {url: 'https://bbc.com/story', title: 'B', seendate: '20240101T122000Z', domain: 'bbc.com', language: 'english', sourcecountry: 'GB'};
    const result = deduplicateByUrl([a, b, c]);
    expect(result).toHaveLength(2);
    expect(result[0].url).toBe('https://reuters.com/story');
    expect(result[1].url).toBe('https://bbc.com/story');
  });

  test('deduplicateByImageUrl drops articles with the same og:image, keeping highest-priority (first in sorted input)', () => {
    const articles = [
      {url: 'https://reuters.com/a', title: 'Reuters story', seendate: '20240101T120000Z', domain: 'reuters.com', language: 'english', sourcecountry: 'US'},
      {url: 'https://cnn.com/a', title: 'CNN story', seendate: '20240101T120500Z', domain: 'cnn.com', language: 'english', sourcecountry: 'US'},
    ];
    // Both articles resolved to the same og:image — they're the same story.
    const images: (string | null)[] = ['https://example.com/photo.jpg', 'https://example.com/photo.jpg'];
    const {articles: result, images: resultImages} = deduplicateByImageUrl(articles, images);
    expect(result).toHaveLength(1);
    expect(result[0].domain).toBe('reuters.com');
    expect(resultImages[0]).toBe('https://example.com/photo.jpg');
  });

  test('deduplicateByImageUrl keeps articles whose imageUrl is null even if a previous article had null', () => {
    const articles = [
      {url: 'https://reuters.com/a', title: 'A', seendate: '20240101T120000Z', domain: 'reuters.com', language: 'english', sourcecountry: 'US'},
      {url: 'https://bbc.com/b', title: 'B', seendate: '20240101T121000Z', domain: 'bbc.com', language: 'english', sourcecountry: 'GB'},
    ];
    const images: (string | null)[] = [null, null];
    const {articles: result} = deduplicateByImageUrl(articles, images);
    // null imageUrl is not a signal — both articles are kept
    expect(result).toHaveLength(2);
  });
});
