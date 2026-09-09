package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/platform/database"
	"github.com/travel-super-app/backend/internal/platform/httpapi"
)

func main() {
	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery(), httpapi.RequestID())
	dsn := os.Getenv("MYSQL_DSN")
	if dsn == "" {
		log.Fatal("MYSQL_DSN is required")
	}
	db, err := database.Open(dsn)
	if err != nil {
		log.Fatalf("connect to MySQL: %v", err)
	}
	defer db.Close()
	httpapi.RegisterRoutes(router, db, os.Getenv("JWT_SECRET"))

	port := os.Getenv("APP_PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Travel Super App API listening on :%s", port)
	log.Fatal(router.Run(":" + port))
}
