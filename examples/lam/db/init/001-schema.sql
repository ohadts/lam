-- Seed for the "orders" database. Applied by `lam seed` / first `lam up`.
CREATE TABLE IF NOT EXISTS orders (
  id          BIGSERIAL PRIMARY KEY,
  customer_id BIGINT      NOT NULL,
  status      TEXT        NOT NULL DEFAULT 'NEW',
  total_cents BIGINT      NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO orders (customer_id, status, total_cents) VALUES
  (1001, 'NEW',       4990),
  (1002, 'PAID',     12900),
  (1003, 'CANCELLED', 2500);
