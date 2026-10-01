// Amounts are stored in pence to avoid floating-point rounding.
export type Money = { pence: number; currency: "GBP" | "EUR" };

export function formatMoney(amount: Money): string {
  const symbol = amount.currency === "GBP" ? "£" : "€";
  return `${symbol}${(amount.pence / 100).toFixed(2)}`;
}

export function addMoney(a: Money, b: Money): Money {
  if (a.currency !== b.currency) throw new Error("currency mismatch");
  return { pence: a.pence + b.pence, currency: a.currency };
}
