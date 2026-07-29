export type PaddleCurrentPriceTier = {
  priceEnvName: string;
};

const PADDLE_PRICE_ID_PATTERN = /^pri_[a-z0-9]{26}$/;

export function currentPaddleCatalogPricesAreComplete(
  tiers: readonly PaddleCurrentPriceTier[],
  environment: Readonly<Record<string, string | undefined>>
): boolean {
  const currentPriceIds: string[] = [];

  for (const tier of tiers) {
    const priceId = environment[tier.priceEnvName]?.trim();
    if (!priceId || !PADDLE_PRICE_ID_PATTERN.test(priceId)) return false;
    currentPriceIds.push(priceId);
  }

  return new Set(currentPriceIds).size === tiers.length;
}
