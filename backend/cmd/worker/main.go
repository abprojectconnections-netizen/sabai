// Command worker runs the scheduled financial maintenance jobs. Today that is hold expiry only:
// settlement batches are deliberately NOT created here because building one needs a named human preparer (separation of duties).
// Use -once from cron / a scheduler, or leave it running (default interval 1m).
package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/travel-super-app/backend/internal/finance/booking"
	"github.com/travel-super-app/backend/internal/platform/database"
)

func main() {
	once := flag.Bool("once", false, "run each job once and exit")
	every := flag.Duration("interval", time.Minute, "interval between runs")
	flag.Parse()
	dsn := os.Getenv("MYSQL_DSN")
	if dsn == "" {
		log.Fatal("MYSQL_DSN is required")
	}
	db, err := database.Open(dsn)
	if err != nil {
		log.Fatalf("connect to MySQL: %v", err)
	}
	defer db.Close()
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	bs := booking.NewService(db)
	run := func() {
		n, err := bs.ExpireHolds(ctx)
		if err != nil {
			log.Printf("expire-holds failed after %d: %v", n, err)
			return
		}
		if n > 0 {
			log.Printf("expire-holds released %d booking(s)", n)
		}
	}
	run()
	if *once {
		return
	}
	t := time.NewTicker(*every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			run()
		}
	}
}
