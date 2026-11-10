/**
 * Price shown to the customer. The prototype adds NOTHING to the listed price: no service fee has been approved (design 0002 Q1).
 * In the real app the payable total always comes from the server's price snapshot; the client never computes or sends an amount.
 */
export function payableTotal(listedPrice) {
  return Math.round(listedPrice);
}
