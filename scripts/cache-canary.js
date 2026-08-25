#!/usr/bin/env node
//
// Prompt-caching canary.
//
// Why this exists. The dominant cost in an agentic loop is not the length of the
// answer, it is resending the history on every tool call. Caching cuts that by
// roughly an order of magnitude: a cache read costs $0.20/1M against $2.00/1M
// for fresh input on Sonnet 5. But caching breaks silently — change one byte in
// the prefix and you pay full price, with no error and no warning.
//
// What it does. Two requests sharing a prefix. The first must WRITE the cache,
// the second must READ it. If the second reads zero, caching is not working and
// this script fails. Both costs come from /api/v1/generation rather than from
// our own arithmetic, so what you see is what the provider actually charged.
//
// Usage: OPENROUTER_API_KEY=... node scripts/cache-canary.js [model]

const API = 'https://openrouter.ai/api';
const MODEL = process.argv[2] || 'anthropic/claude-sonnet-5';
const KEY = process.env.OPENROUTER_API_KEY;

// The minimum cacheable prefix depends on the tier, and the gap is large.
// Measured empirically with this same script, against a pinned Anthropic
// provider:
//
//   Sonnet 5     caches from ~1024 tokens (1828 already worked)
//   Haiku 4.5    caches from ~4096 tokens (3663 did not, 4879 did)
//
// Below the threshold the cache is not created SILENTLY: no error, no warning,
// just full input price on every request. Hence the non-obvious conclusion this
// constant exists to record: on a prefix shorter than 4096 tokens Haiku does not
// cache, and its $1.00/1M input then costs MORE than Sonnet's $0.20/1M cached
// input. Haiku only saves money on a long, stable prefix.
//
// The text must be byte-identical between runs: no dates, no random values, no
// counters. That is exactly the rule this canary is meant to catch violations of
// in real prompts.
const MIN_CACHEABLE_TOKENS = { haiku: 4096, default: 1024 };

function thresholdFor(model) {
  return /haiku/i.test(model)
    ? MIN_CACHEABLE_TOKENS.haiku
    : MIN_CACHEABLE_TOKENS.default;
}

function stablePrefix() {
  const paragraph =
    'Filler context for the caching canary. This paragraph exists only to push ' +
    'the request prefix past the minimum cacheable size while staying ' +
    'byte-identical between runs of the script. ';
  // ~37 tokens per repeat, measured. 128 repeats (~4750) clear even the Haiku
  // threshold with margin. Do not trim this number to "look tidy": at 64
  // repeats the prefix lands at 2383 tokens and Haiku stops caching entirely —
  // which is how this very canary caught the regression when the filler text
  // was translated from Russian to English and got denser per repeat.
  //
  // One canary run costs a fraction of a cent, far less than a day of
  // unnoticed cache misses.
  return paragraph.repeat(128);
}

async function ask(question) {
  const res = await fetch(`${API}/v1/messages`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${KEY}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 16,
      // Provider pinning. Contrary to a common assumption, Anthropic models on
      // OpenRouter are not served by a single provider: haiku-4.5 has eight
      // endpoints (Anthropic, Google, Azure, Bedrock in three variants) and
      // sonnet-5 has nine. Without pinning, two adjacent requests land on
      // different providers and the prefix cache does not survive the move.
      // Verified: unpinned, both requests went to Amazon Bedrock; pinned, both
      // went to Anthropic.
      provider: { order: ['Anthropic'], allow_fallbacks: false },
      // cache_control on the system block: everything up to this point is
      // cached. The variable part (the question) comes AFTER it — otherwise
      // every new question would shift the prefix and void the cache.
      system: [
        {
          type: 'text',
          text: stablePrefix(),
          cache_control: { type: 'ephemeral' },
        },
      ],
      messages: [{ role: 'user', content: question }],
    }),
  });

  const body = await res.json();
  if (body.error) throw new Error(`${MODEL}: ${body.error.message}`);
  return body;
}

// Only the provider knows what a request cost: the cache-read discount and the
// cache-write surcharge are already applied on their side. Computing it here
// from a price list would lie.
async function costOf(id) {
  // Stats appear noticeably later than the response itself, so wait generously:
  // with five attempts at 1.5s the second request consistently came back empty.
  for (let attempt = 0; attempt < 8; attempt++) {
    const res = await fetch(`${API}/v1/generation?id=${encodeURIComponent(id)}`, {
      headers: { Authorization: `Bearer ${KEY}` },
    });
    const body = await res.json();
    if (body.data) return body.data.total_cost;
    await new Promise((r) => setTimeout(r, 2000));
  }
  return null;
}

function report(label, usage, cost) {
  const write = usage.cache_creation_input_tokens ?? 0;
  const read = usage.cache_read_input_tokens ?? 0;
  const money = cost === null ? 'no data' : `$${cost.toFixed(6)}`;
  console.log(
    `${label}: input ${usage.input_tokens}, cache write ${write}, ` +
      `cache read ${read}, cost ${money}`,
  );
  return read;
}

async function main() {
  if (!KEY) {
    console.error('OPENROUTER_API_KEY is required.');
    process.exit(2);
  }

  console.log(`Model: ${MODEL}`);

  // Different questions, identical prefix. This tests the prefix cache
  // specifically, rather than a provider replaying a stored answer to a
  // repeated request.
  const first = await ask('Answer with one word: one.');
  report('Request 1', first.usage, await costOf(first.id));
  const written =
    (first.usage.cache_creation_input_tokens ?? 0) +
    (first.usage.cache_read_input_tokens ?? 0);

  const second = await ask('Answer with one word: two.');
  const secondRead = report('Request 2', second.usage, await costOf(second.id));

  if (secondRead > 0) {
    console.log('\nCaching works: request 2 read the prefix from cache.');
    return;
  }

  // Two distinct diagnoses, and they must not be conflated. Cache never
  // created — the problem is in the request (threshold, prefix contents).
  // Cache created but not read — the problem is routing or lifetime.
  if (written === 0) {
    console.error(
      '\nCache NOT created: request 1 wrote zero tokens to cache, so the whole\n' +
        'prefix was billed as ordinary input at full price.\n' +
        `The threshold for this model is around ${thresholdFor(MODEL)} tokens\n` +
        '(Haiku sits four times higher than Sonnet and Opus).\n' +
        'What to check:\n' +
        '  - the prefix is shorter than this model’s minimum cacheable size;\n' +
        '  - the variable part sits BEFORE cache_control instead of after it;\n' +
        '  - cache_control never reached the provider at all.',
    );
  } else {
    console.error(
      '\nCache created but NOT read: the prefix was written and then lost.\n' +
        'History is still being resent at full price. What to check:\n' +
        '  - the prefix contains something variable (a date, an id, a counter);\n' +
        '  - more than the cache lifetime passed between requests (5 min default);\n' +
        '  - the requests went to different providers. Pin one with\n' +
        '    provider.order and allow_fallbacks: false — this happens even to\n' +
        '    Anthropic models, which have up to nine endpoints on OpenRouter.',
    );
  }
  process.exit(1);
}

main().catch((err) => {
  console.error(`The canary could not complete the check: ${err.message}`);
  process.exit(2);
});
