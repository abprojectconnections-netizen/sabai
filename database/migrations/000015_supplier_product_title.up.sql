-- A catalogue needs something to show. Nullable: the API falls back to the item SKU until a title is entered.
ALTER TABLE supplier_products
  ADD COLUMN title VARCHAR(255) NULL AFTER category;
