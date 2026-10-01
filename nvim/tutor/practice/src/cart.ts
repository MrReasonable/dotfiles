import { addMoney } from "./money";

// A line in the cart: what was bought and how many.
export type CartItem = {
  sku: string;
  qty: number;
  price: Money;
};

export class Cart {
  private items: CartItem[] = [];

  add(item: CartItem) {
    this.items.push(item);
  }

  // TODO: merge lines with the same sku instead of adding duplicates
  count(): number {
    return this.items.reduce((n, item) => n + item.qty, 0);
  }

  totl(): Money {
    let sum: Money = { pence: 0, currency: "GBP" };
    for (const item of this.items) {
      const line = { pence: item.price.pence * item.qty, currency: item.price.currency };
      sum = addMoney(sum, line);
    }
    return sum;
  }
}
