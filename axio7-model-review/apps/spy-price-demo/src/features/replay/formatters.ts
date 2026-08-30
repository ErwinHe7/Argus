const easternTimeFormatter = new Intl.DateTimeFormat("en-US", {
  hour: "numeric",
  minute: "2-digit",
  timeZone: "America/New_York",
});

const probabilityFormatter = new Intl.NumberFormat("en-US", {
  style: "percent",
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
});

const signedBasisPointFormatter = new Intl.NumberFormat("en-US", {
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
  signDisplay: "always",
});

export function formatEasternTime(timestamp: string): string {
  return easternTimeFormatter.format(new Date(timestamp));
}

export function formatEasternTimestamp(timestamp: string): string {
  return `${formatEasternTime(timestamp)} ET`;
}

export function formatUsd(value: number, fractionDigits = 3): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: fractionDigits,
    maximumFractionDigits: fractionDigits,
  }).format(value);
}

export function formatProbability(value: number): string {
  return probabilityFormatter.format(value);
}

export function formatSignedBasisPoints(value: number): string {
  return `${signedBasisPointFormatter.format(value)} BPS`;
}

export function formatVolume(value: number): string {
  return value.toLocaleString("en-US");
}
