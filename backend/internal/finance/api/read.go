package api

import (
	"database/sql"
	"encoding/json"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

// RegisterReads mounts read-only endpoints: the public catalogue and the caller's own bookings and wallet.
// Reads work even when financial transactions are disabled: they move no money.
func RegisterReads(public, secured *gin.RouterGroup, d Deps) {
	public.GET("/catalog/items", catalogList(d.DB))
	user := auth.RequirePermission("booking.create")
	secured.GET("/bookings", user, myBookings(d.DB))
	secured.GET("/bookings/:id", user, myBooking(d.DB))
	secured.GET("/wallet", user, myWallet(d.DB))
	secured.GET("/wallet/transactions", user, myWalletTransactions(d.DB))
}

func catalogList(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		category := c.Query("category")
		rows, err := db.QueryContext(c.Request.Context(), `SELECT i.id, COALESCE(sp.title, i.sku), sp.category, sp.partner_id, p.legal_name, MIN(a.base_price), MIN(a.service_date)
			FROM inventory_items i
			JOIN supplier_products sp ON sp.id = i.supplier_product_id
			JOIN partners p ON p.id = sp.partner_id AND p.status = 'APPROVED'
			JOIN inventory_availability a ON a.inventory_item_id = i.id AND a.service_date >= CURDATE() AND a.quantity_total > a.quantity_sold
			WHERE i.status = 'ACTIVE' AND (? = '' OR sp.category = ?)
			GROUP BY i.id, sp.title, i.sku, sp.category, sp.partner_id, p.legal_name
			ORDER BY MIN(a.service_date), i.id LIMIT ? OFFSET ?`, category, category, limit, offset)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		out := []gin.H{}
		for rows.Next() {
			var id, title, cat, partner, partnerName, price string
			var next time.Time
			if err := rows.Scan(&id, &title, &cat, &partner, &partnerName, &price, &next); err != nil {
				apiresponse.Internal(c)
				return
			}
			out = append(out, gin.H{"id": id, "title": title, "category": cat, "partner_id": partner, "partner_name": partnerName, "from_price": price, "currency": "THB", "next_available_date": next.Format("2006-01-02")})
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, out)
	}
}

func myBookings(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		p, _ := auth.CurrentPrincipal(c)
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		rows, err := db.QueryContext(c.Request.Context(), `SELECT b.id, b.booking_code, b.status, b.currency_code, COALESCE(s.base_total, b.total_amount), COALESCE(s.discount_total, 0), COALESCE(s.payable_total, b.total_amount), b.expires_at, b.created_at,
				(SELECT status FROM payments WHERE booking_id = b.id ORDER BY created_at DESC LIMIT 1),
				COALESCE((SELECT title_snapshot FROM booking_items WHERE booking_id = b.id AND deleted_at IS NULL ORDER BY created_at, id LIMIT 1), '')
			FROM bookings b LEFT JOIN booking_price_snapshots s ON s.id = b.price_snapshot_id
			WHERE b.user_id = ? AND b.deleted_at IS NULL ORDER BY b.created_at DESC, b.id LIMIT ? OFFSET ?`, p.UserID, limit, offset)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		out := []gin.H{}
		for rows.Next() {
			var id, code, status, cur, base, disc, payable string
			var expires sql.NullTime
			var created time.Time
			var pay sql.NullString
			var title string
			if err := rows.Scan(&id, &code, &status, &cur, &base, &disc, &payable, &expires, &created, &pay, &title); err != nil {
				apiresponse.Internal(c)
				return
			}
			h := bookingJSON(id, code, status, cur, base, disc, payable, expires, created, pay)
			h["title"] = title
			out = append(out, h)
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, out)
	}
}

func bookingJSON(id, code, status, cur, base, disc, payable string, expires sql.NullTime, created time.Time, pay sql.NullString) gin.H {
	h := gin.H{"id": id, "booking_code": code, "status": status, "currency": cur, "base_total": base, "discount_total": disc, "payable_total": payable, "created_at": created, "payment_status": nil, "expires_at": nil}
	if pay.Valid {
		h["payment_status"] = pay.String
	}
	if expires.Valid {
		h["expires_at"] = expires.Time
	}
	return h
}

func myBooking(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		p, _ := auth.CurrentPrincipal(c)
		ctx := c.Request.Context()
		var id, code, status, cur, base, disc, payable string
		var expires sql.NullTime
		var created time.Time
		var pay sql.NullString
		var terms sql.NullString
		err := db.QueryRowContext(ctx, `SELECT b.id, b.booking_code, b.status, b.currency_code, COALESCE(s.base_total, b.total_amount), COALESCE(s.discount_total, 0), COALESCE(s.payable_total, b.total_amount), b.expires_at, b.created_at,
				(SELECT status FROM payments WHERE booking_id = b.id ORDER BY created_at DESC LIMIT 1), s.terms_json
			FROM bookings b LEFT JOIN booking_price_snapshots s ON s.id = b.price_snapshot_id
			WHERE b.id = ? AND b.user_id = ? AND b.deleted_at IS NULL`, c.Param("id"), p.UserID).Scan(&id, &code, &status, &cur, &base, &disc, &payable, &expires, &created, &pay, &terms)
		if err == sql.ErrNoRows {
			apiresponse.NotFound(c, "booking not found") // another user's booking looks the same as a missing one
			return
		} else if err != nil {
			apiresponse.Internal(c)
			return
		}
		out := bookingJSON(id, code, status, cur, base, disc, payable, expires, created, pay)
		if terms.Valid {
			var t any
			if json.Unmarshal([]byte(terms.String), &t) == nil {
				out["terms"] = t
			}
		}
		items := []gin.H{}
		irows, err := db.QueryContext(ctx, "SELECT reference_id, COALESCE(title_snapshot, ''), service_date, quantity, unit_amount FROM booking_items WHERE booking_id = ? AND deleted_at IS NULL ORDER BY created_at, id", id)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer irows.Close()
		for irows.Next() {
			var ref, title, unit string
			var date sql.NullTime
			var qty int
			if err := irows.Scan(&ref, &title, &date, &qty, &unit); err != nil {
				apiresponse.Internal(c)
				return
			}
			it := gin.H{"inventory_item_id": ref, "title": title, "quantity": qty, "unit_amount": unit, "service_date": nil}
			if date.Valid {
				it["service_date"] = date.Time.Format("2006-01-02")
			}
			items = append(items, it)
		}
		out["items"] = items
		refunds := []gin.H{}
		rrows, err := db.QueryContext(ctx, "SELECT id, status, method, requested_amount, approved_amount FROM refund_requests WHERE booking_id = ? ORDER BY created_at, id", id)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rrows.Close()
		for rrows.Next() {
			var rid, st, method, req string
			var appr sql.NullString
			if err := rrows.Scan(&rid, &st, &method, &req, &appr); err != nil {
				apiresponse.Internal(c)
				return
			}
			r := gin.H{"id": rid, "status": st, "method": method, "requested_amount": req, "approved_amount": nil}
			if appr.Valid {
				r["approved_amount"] = appr.String
			}
			refunds = append(refunds, r)
		}
		out["refunds"] = refunds
		apiresponse.OK(c, out)
	}
}

func myWallet(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		p, _ := auth.CurrentPrincipal(c)
		var bal, pend, cur, typ string
		err := db.QueryRowContext(c.Request.Context(), "SELECT available_balance, pending_balance, currency_code, balance_type FROM wallets WHERE user_id = ? AND deleted_at IS NULL", p.UserID).Scan(&bal, &pend, &cur, &typ)
		if err == sql.ErrNoRows { // no wallet yet means an empty one; it is created by the first refund credit
			apiresponse.OK(c, gin.H{"available_balance": "0.00", "pending_balance": "0.00", "currency": "THB", "balance_type": "REFUND_CREDIT"})
			return
		} else if err != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"available_balance": bal, "pending_balance": pend, "currency": cur, "balance_type": typ})
	}
}

func myWalletTransactions(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		p, _ := auth.CurrentPrincipal(c)
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		rows, err := db.QueryContext(c.Request.Context(), `SELECT id, created_at, transaction_type, reference_type, credit_amount, debit_amount, balance_after FROM wallet_ledger_entries
			WHERE user_id = ? ORDER BY seq DESC LIMIT ? OFFSET ?`, p.UserID, limit, offset)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		out := []gin.H{}
		for rows.Next() {
			var id, typ, ref, credit, debit, after string
			var at time.Time
			if err := rows.Scan(&id, &at, &typ, &ref, &credit, &debit, &after); err != nil {
				apiresponse.Internal(c)
				return
			}
			out = append(out, gin.H{"id": id, "created_at": at, "type": typ, "reference_type": ref, "credit_amount": credit, "debit_amount": debit, "balance_after": after})
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, out)
	}
}
