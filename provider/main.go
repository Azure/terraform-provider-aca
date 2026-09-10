package main

import (
	"context"
	"flag"
	"log"

	"github.com/hashicorp/terraform-plugin-framework/providerserver"

	acaprovider "github.com/Azure/terraform-provider-aca/provider/internal/provider"
)

var version = "dev"

func main() {
	var debug bool
	flag.BoolVar(&debug, "debug", false, "run the provider with debugger support")
	flag.Parse()

	err := providerserver.Serve(
		context.Background(),
		acaprovider.New(version),
		providerserver.ServeOpts{
			Address: "registry.terraform.io/Azure/aca",
			Debug:   debug,
		},
	)
	if err != nil {
		log.Fatal(err)
	}
}
