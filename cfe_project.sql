/*
Campaign Finance Expenditure Data Exploration
*/
USE campaign_finance_expenditure;

/*View that displays expenditure from organizations, used to identify who spends the most and on what.*/
CREATE VIEW entity_spending AS
SELECT pb.paid_by_id AS organization_id, 
	pb.paid_by_organization AS organization_name,
	p.payee_id AS paid_to,
	et.expenditure_type AS expenditure_type,
	e.expense_category AS expense_category,
	t.payment_amount AS amount_spent
FROM transactions t
	JOIN paid_by pb ON pb.paid_by_id = t.paid_by_id
	JOIN payee p ON p.payee_id = t.payee_id
	JOIN expenses e ON e.expense_category_id = t.expense_category_id
	JOIN expenditure_type et ON et.expenditure_id = t.expenditure_id
	WHERE pb.paid_by_organization IS NOT NULL
GROUP BY pb.paid_by_id
ORDER BY amount_spent DESC;
	/*Displays complete view:
    SELECT * FROM entity_spending;*/
    
	/*Displays organization name and amount_spent, with payments formatted:
SELECT
  organization_name,
  CONCAT('$', FORMAT(total_spent, 2)) AS total_spent
FROM entity_spending;*/

/*Use CTE to track monthly spending, including rolling spending over a 3 month period*/

SELECT
  t.paid_by_id,
  DATE_FORMAT(t.payment_date, '%Y-%m') AS month,
  SUM(t.payment_amount) AS monthly_spend
FROM transactions t
JOIN paid_by pb ON pb.paid_by_id = t.paid_by_id
WHERE t.payment_amount IS NOT NULL
GROUP BY t.paid_by_id, DATE_FORMAT(t.payment_date, '%Y-%m')
ORDER BY t.paid_by_id, month;

WITH monthly AS (
  SELECT
    t.paid_by_id,
    DATE_FORMAT(t.payment_date, '%Y-%m') AS month,
    LAST_DAY(t.payment_date) AS month_end,
    SUM(t.payment_amount) AS monthly_spend
  FROM transactions t
  JOIN paid_by pb ON pb.paid_by_id = t.paid_by_id
  WHERE t.payment_amount IS NOT NULL
  GROUP BY t.paid_by_id, DATE_FORMAT(t.payment_date, '%Y-%m'), LAST_DAY(t.payment_date)
)

SELECT
  paid_by_id,
  month,
  monthly_spend,
  SUM(monthly_spend) OVER (
    PARTITION BY paid_by_id
    ORDER BY month_end
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ) AS rolling_3_month_spend
FROM monthly
ORDER BY paid_by_id, month_end;

/*Flag transactions that are unusually high, or missing details - useful for larger datasets, monitoring input errors, and audits*/
CREATE TEMPORARY TABLE high_risk_transactions AS
SELECT 
  t.*,
  CASE 
    WHEN t.payment_amount > 10000 THEN 'High Amount'
    WHEN t.expense_category_id IS NULL THEN 'Missing Category'
    ELSE NULL
  END AS risk_reason
FROM transactions t
WHERE t.payment_amount > 10000 OR t.expense_category_id IS NULL;

/* View high_risk_transactions:
SELECT * FROM high_risk_transactions;*/