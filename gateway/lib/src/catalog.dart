/// The models this gateway will route to, and what they cost.
library;

import 'package:accent_protocol/protocol.dart';

/// Tier names the app selects by. The app never names a provider-specific
/// model string, so swapping the model behind a tier is an edit in one place
/// plus a visible commit — not a silent change in what the user is paying for.
const haikuTier = 'haiku';
const sonnetTier = 'sonnet';
const opusTier = 'opus';

/// Prices are per million tokens, as billed by OpenRouter.
///
/// `minCacheableTokens` is measured, not copied from documentation. Haiku sits
/// four times higher than the other two, and below that threshold it does not
/// cache at all — at which point its cheaper headline price becomes a more
/// expensive bill than Sonnet with a working cache. Anything editing these
/// numbers should re-run `node scripts/cache-canary.js <model>` first.
const modelCatalog = <String, ModelInfo>{
  haikuTier: ModelInfo(
    id: 'anthropic/claude-haiku-4.5',
    displayName: 'Haiku 4.5',
    inputUsdPerMillion: 1.0,
    outputUsdPerMillion: 5.0,
    cacheReadUsdPerMillion: 0.1,
    minCacheableTokens: 4096,
    contextWindow: 200000,
  ),
  sonnetTier: ModelInfo(
    id: 'anthropic/claude-sonnet-5',
    displayName: 'Sonnet 5',
    inputUsdPerMillion: 2.0,
    outputUsdPerMillion: 10.0,
    cacheReadUsdPerMillion: 0.2,
    minCacheableTokens: 1024,
    contextWindow: 1000000,
  ),
  opusTier: ModelInfo(
    id: 'anthropic/claude-opus-5',
    displayName: 'Opus 5',
    inputUsdPerMillion: 5.0,
    outputUsdPerMillion: 25.0,
    cacheReadUsdPerMillion: 0.5,
    minCacheableTokens: 1024,
    contextWindow: 1000000,
  ),
};

/// Resolves a tier the app asked for, rejecting anything unknown.
///
/// Deliberately strict: substituting a default for an unrecognised name is how a
/// typo turns into a bill on the most expensive tier.
ModelInfo? resolveTier(String tier) => modelCatalog[tier];
