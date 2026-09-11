package auth

import "testing"

func TestNewCredentialRequiresAuthentication(t *testing.T) {
	for _, name := range []string{
		"AZURE_TENANT_ID",
		"AZURE_CLIENT_ID",
		"AZURE_CLIENT_SECRET",
		"AZURE_CLIENT_CERTIFICATE_PATH",
		"AZURE_CLIENT_CERTIFICATE_PASSWORD",
		"AZURE_FEDERATED_TOKEN_FILE",
		"AZURE_AUTHORITY_HOST",
	} {
		t.Setenv(name, "")
	}

	_, err := NewCredential(Config{})
	if err == nil {
		t.Fatal("NewCredential() expected an error")
	}
}

func TestNewCredentialValidatesServicePrincipal(t *testing.T) {
	for _, name := range []string{
		"AZURE_TENANT_ID",
		"AZURE_CLIENT_ID",
		"AZURE_CLIENT_SECRET",
		"AZURE_CLIENT_CERTIFICATE_PATH",
		"AZURE_FEDERATED_TOKEN_FILE",
	} {
		t.Setenv(name, "")
	}

	_, err := NewCredential(Config{ClientSecret: "secret"})
	if err == nil {
		t.Fatal("NewCredential() expected an error")
	}
}
