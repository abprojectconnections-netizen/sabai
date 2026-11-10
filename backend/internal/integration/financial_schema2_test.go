//go:build integration

package integration

import (
	"sync"
	"testing"

	"github.com/google/uuid"
)

func TestInventoryCannotBeOversold(t *testing.T) {
	sup := uuid.NewString()
	mustOK(t, "supplier", "INSERT INTO suppliers (id, created_at, updated_at, supplier_type, adapter_code) VALUES (?, "+now+", "+now+", 'HOTEL', ?)", sup, "ad-"+sup[:8])
	sp, item, av := uuid.NewString(), uuid.NewString(), uuid.NewString()
	mustOK(t, "product", "INSERT INTO supplier_products (id, created_at, updated_at, supplier_id, category, external_ref) VALUES (?, "+now+", "+now+", ?, 'HOTEL', 'room-1')", sp, sup)
	mustOK(t, "item", "INSERT INTO inventory_items (id, created_at, supplier_product_id, sku) VALUES (?, "+now+", ?, 'DLX')", item, sp)
	mustOK(t, "availability 3 rooms", "INSERT INTO inventory_availability (id, created_at, updated_at, inventory_item_id, service_date, quantity_total, base_price) VALUES (?, "+now+", "+now+", ?, '2026-12-25', 3, 1500)", av, item)
	mustFail(t, "the same item and day twice", "Duplicate", "INSERT INTO inventory_availability (id, created_at, updated_at, inventory_item_id, service_date, quantity_total, base_price) VALUES (UUID(), "+now+", "+now+", ?, '2026-12-25', 9, 1)", item)
	mustFail(t, "setting sold above total directly", "", "UPDATE inventory_availability SET quantity_sold = 4 WHERE id = ?", av)

	var wg sync.WaitGroup
	var mu sync.Mutex
	won := 0
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			res, err := db.Exec("UPDATE inventory_availability SET quantity_sold = quantity_sold + 1 WHERE id = ? AND quantity_sold + 1 <= quantity_total", av)
			if err == nil {
				if n, _ := res.RowsAffected(); n == 1 {
					mu.Lock()
					won++
					mu.Unlock()
				}
			}
		}()
	}
	wg.Wait()
	if won != 3 {
		t.Fatalf("3 rooms were sold %d times", won)
	}
	// even a careless unconditional increment cannot oversell, the CHECK stops it
	mustFail(t, "an unconditional increment past capacity", "", "UPDATE inventory_availability SET quantity_sold = quantity_sold + 1 WHERE id = ?", av)
	mustFail(t, "a credential that is a raw secret rather than a reference", "", "INSERT INTO supplier_credentials (id, created_at, supplier_id, secret_ref) VALUES (UUID(), "+now+", ?, 'sk_live_abc123')", sup)
	mustOK(t, "a credential reference", "INSERT INTO supplier_credentials (id, created_at, supplier_id, secret_ref) VALUES (UUID(), "+now+", ?, 'vault://suppliers/hotel-a')", sup)
}

func TestContractLegalGateAndVersioning(t *testing.T) {
	f := newFixture(t)
	ins := "INSERT INTO partner_contracts (id, created_at, partner_id, contract_no, version, starts_on, seller_of_record, invoice_authorization, legal_review_ref) VALUES (UUID(), " + now + ", ?, 'C-1', ?, '2026-01-01', ?, ?, ?)"
	mustOK(t, "default contract: partner sells and invoices", ins, f.partner, 1, "PARTNER", 0, nil)
	mustFail(t, "authorising the platform to invoice without a legal review", "", ins, f.partner, 2, "PARTNER", 1, nil)
	mustFail(t, "platform as seller without a legal review", "", ins, f.partner, 3, "PLATFORM", 0, nil)
	mustOK(t, "platform invoicing once legal review is recorded", ins, f.partner, 4, "PARTNER", 1, "LEGAL-2026-017")
	mustFail(t, "editing a contract in place", "versioned", "UPDATE partner_contracts SET seller_of_record = 'PLATFORM'")
	mustFail(t, "an unknown settlement weekday", "", "INSERT INTO partner_contracts (id, created_at, partner_id, contract_no, version, starts_on, settlement_weekday) VALUES (UUID(), "+now+", ?, 'C-2', 1, '2026-01-01', 'SUN')", f.partner)
	var wd string
	db.QueryRow("SELECT settlement_weekday FROM partner_contracts WHERE partner_id = ? AND version = 1", f.partner).Scan(&wd)
	if wd != "TUE" {
		t.Errorf("default settlement day must be Tuesday, got %s", wd)
	}
}

func TestTaxDocumentIssuerGateAndImmutability(t *testing.T) {
	f := newFixture(t)
	ent := uuid.NewString()
	mustOK(t, "partner legal entity", "INSERT INTO legal_entities (id, created_at, entity_type, legal_name) VALUES (?, "+now+", 'PARTNER', 'ร้านทดสอบ จำกัด')", ent)
	doc := "INSERT INTO tax_documents (id, created_at, updated_at, document_type, issuer_entity_id, series, document_no, taxable_amount, vat_amount, total_amount, status, issued_at, booking_id) VALUES (?, " + now + ", " + now + ", 'TAX_INVOICE', ?, 'A', ?, 1000, 70, ?, ?, ?, ?)"
	mustFail(t, "an issued partner tax invoice with no authorization/legal review", "legal review", doc, uuid.NewString(), ent, "N-"+uuid.NewString()[:6], 1070, "ISSUED", "2026-11-01 00:00:00", f.booking)
	mustFail(t, "a total that is not taxable + VAT", "", doc, uuid.NewString(), ent, "N-"+uuid.NewString()[:6], 1000, "DRAFT", nil, f.booking)
	draft := uuid.NewString()
	mustOK(t, "a draft may exist before issuing", doc, draft, ent, nil, 1070, "DRAFT", nil, f.booking)

	// authorise through a contract with legal review, linked via the booking's partner
	mustOK(t, "link the legal entity", "UPDATE partners SET legal_entity_id = ? WHERE id = ?", ent, f.partner)
	mustOK(t, "authorised contract", "INSERT INTO partner_contracts (id, created_at, partner_id, contract_no, version, starts_on, invoice_authorization, legal_review_ref, status) VALUES (UUID(), "+now+", ?, 'C-9', 1, '2026-01-01', 1, 'LEGAL-OK', 'ACTIVE')", f.partner)
	no := "N-" + uuid.NewString()[:6]
	issued := uuid.NewString()
	mustOK(t, "issuing with authorization and a legal review", "INSERT INTO tax_documents (id, created_at, updated_at, document_type, issuer_entity_id, series, document_no, taxable_amount, vat_amount, total_amount, status, issued_at, booking_id) VALUES (?, "+now+", "+now+", 'TAX_INVOICE', ?, 'A', ?, 1000, 70, 1070, 'ISSUED', "+now+", ?)", issued, ent, no, f.booking)
	mustFail(t, "reusing a document number", "Duplicate", "INSERT INTO tax_documents (id, created_at, updated_at, document_type, issuer_entity_id, series, document_no, taxable_amount, vat_amount, total_amount, status, issued_at, booking_id) VALUES (UUID(), "+now+", "+now+", 'TAX_INVOICE', ?, 'A', ?, 1, 0, 1, 'ISSUED', "+now+", ?)", ent, no, f.booking)
	mustFail(t, "changing the amounts of an issued document", "immutable", "UPDATE tax_documents SET taxable_amount = 1, vat_amount = 0, total_amount = 1 WHERE id = ?", issued)
	mustFail(t, "deleting an issued document", "cannot be deleted", "DELETE FROM tax_documents WHERE id = ?", issued)
	mustFail(t, "a credit note without the document it corrects", "", "INSERT INTO tax_documents (id, created_at, updated_at, document_type, issuer_entity_id, taxable_amount, vat_amount, total_amount) VALUES (UUID(), "+now+", "+now+", 'CREDIT_NOTE', ?, 1, 0, 1)", ent)
	mustOK(t, "a credit note that refers to the original", "INSERT INTO tax_documents (id, created_at, updated_at, document_type, issuer_entity_id, taxable_amount, vat_amount, total_amount, parent_document_id) VALUES (UUID(), "+now+", "+now+", 'CREDIT_NOTE', ?, 1000, 70, 1070, ?)", ent, issued)
	mustOK(t, "voiding an issued document is allowed", "UPDATE tax_documents SET status = 'VOIDED' WHERE id = ?", issued)
	mustFail(t, "re-issuing a voided document", "immutable", "UPDATE tax_documents SET status = 'ISSUED' WHERE id = ?", issued)
}

func TestDocumentSequenceIsGapFree(t *testing.T) {
	ent, seq := uuid.NewString(), uuid.NewString()
	mustOK(t, "entity", "INSERT INTO legal_entities (id, created_at, entity_type, legal_name) VALUES (?, "+now+", 'PLATFORM', 'Sabai Co.')", ent)
	mustOK(t, "sequence", "INSERT INTO document_sequences (id, issuer_entity_id, series, last_number, updated_at) VALUES (?, ?, 'INV', 0, "+now+")", seq, ent)
	mustFail(t, "skipping a number", "exactly one", "UPDATE document_sequences SET last_number = 5 WHERE id = ?", seq)
	mustFail(t, "going backwards", "exactly one", "UPDATE document_sequences SET last_number = last_number - 1 WHERE id = ?", seq)
	var wg sync.WaitGroup
	var mu sync.Mutex
	got := map[int]bool{}
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			tx, err := db.Begin()
			if err != nil {
				return
			}
			defer tx.Rollback()
			var n int
			if err := tx.QueryRow("SELECT last_number FROM document_sequences WHERE id = ? FOR UPDATE", seq).Scan(&n); err != nil {
				return
			}
			if _, err := tx.Exec("UPDATE document_sequences SET last_number = ?, updated_at = "+now+" WHERE id = ?", n+1, seq); err != nil {
				return
			}
			if err := tx.Commit(); err == nil {
				mu.Lock()
				got[n+1] = true
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	for i := 1; i <= 10; i++ {
		if !got[i] {
			t.Fatalf("number %d was never allocated (gap or duplicate): %v", i, got)
		}
	}
}

func TestReconciliationRecordsAreConsistent(t *testing.T) {
	rec := uuid.NewString()
	mustOK(t, "run", "INSERT INTO payment_reconciliations (id, created_at, provider, period_from, period_to) VALUES (?, "+now+", 'mock', '2026-11-01', '2026-11-08')", rec)
	mustFail(t, "an inverted period", "", "INSERT INTO payment_reconciliations (id, created_at, provider, period_from, period_to) VALUES (UUID(), "+now+", 'mock', '2026-11-08', '2026-11-01')")
	ins := "INSERT INTO financial_reconciliation_records (id, created_at, reconciliation_id, subject_type, subject_id, provider_amount, our_amount, result) VALUES (UUID(), " + now + ", ?, 'PAYMENT', UUID(), ?, ?, ?)"
	mustOK(t, "matching amounts", ins, rec, 100, 100, "MATCHED")
	mustFail(t, "MATCHED with different amounts", "", ins, rec, 100, 99, "MATCHED")
	mustFail(t, "AMOUNT_MISMATCH with equal amounts", "", ins, rec, 100, 100, "AMOUNT_MISMATCH")
	mustOK(t, "a genuine mismatch", ins, rec, 100, 90, "AMOUNT_MISMATCH")
	mustFail(t, "editing a record", "append-only", "UPDATE financial_reconciliation_records SET result = 'MATCHED'")
}
