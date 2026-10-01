import { Cart } from "./cart";
import { formatMoney } from "./money";

const cart = new Cart();
cart.add({ sku: "TEA-01", qty: 2, price: { pence: 450, currency: "GBP" } });
cart.add({ sku: "MUG-07", qty: "1", price: { pence: 899, currency: "GBP" } });

console.log(`${cart.count()} items, total ${formatMoney(cart.totl())}`);
