package auth

import (
	"fmt"
	"os"
	"strings"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/cloud"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
)

type Config struct {
	TenantID                  string
	ClientID                  string
	ClientSecret              string
	ClientCertificatePath     string
	ClientCertificatePassword string
	OIDCTokenFilePath         string
	UseManagedIdentity        bool
	ManagedIdentityClientID   string
	UseAzureCLI               bool
	AuthorityHost             string
	DisableInstanceDiscovery  bool
}

func NewCredential(config Config) (azcore.TokenCredential, error) {
	explicit := config
	config = withEnvironmentDefaults(config)
	clientOptions := azcore.ClientOptions{}
	if config.AuthorityHost != "" {
		clientOptions.Cloud = cloud.Configuration{
			ActiveDirectoryAuthorityHost: strings.TrimSpace(config.AuthorityHost),
			Services:                     map[cloud.ServiceName]cloud.ServiceConfiguration{},
		}
	}

	var credentials []azcore.TokenCredential

	switch {
	case explicit.ClientSecret != "":
		config.ClientSecret = explicit.ClientSecret
		if err := requireTenantAndClient(config); err != nil {
			return nil, err
		}
		credential, err := azidentity.NewClientSecretCredential(
			config.TenantID,
			config.ClientID,
			config.ClientSecret,
			&azidentity.ClientSecretCredentialOptions{
				ClientOptions:            clientOptions,
				DisableInstanceDiscovery: config.DisableInstanceDiscovery,
			},
		)
		if err != nil {
			return nil, fmt.Errorf("creating client secret credential: %w", err)
		}
		credentials = append(credentials, credential)

	case explicit.ClientCertificatePath != "":
		config.ClientCertificatePath = explicit.ClientCertificatePath
		if err := requireTenantAndClient(config); err != nil {
			return nil, err
		}
		data, err := os.ReadFile(config.ClientCertificatePath)
		if err != nil {
			return nil, fmt.Errorf("reading client certificate: %w", err)
		}
		certificates, key, err := azidentity.ParseCertificates(
			data,
			[]byte(config.ClientCertificatePassword),
		)
		if err != nil {
			return nil, fmt.Errorf("parsing client certificate: %w", err)
		}
		credential, err := azidentity.NewClientCertificateCredential(
			config.TenantID,
			config.ClientID,
			certificates,
			key,
			&azidentity.ClientCertificateCredentialOptions{
				ClientOptions:            clientOptions,
				DisableInstanceDiscovery: config.DisableInstanceDiscovery,
			},
		)
		if err != nil {
			return nil, fmt.Errorf("creating client certificate credential: %w", err)
		}
		credentials = append(credentials, credential)

	case explicit.OIDCTokenFilePath != "":
		config.OIDCTokenFilePath = explicit.OIDCTokenFilePath
		if err := requireTenantAndClient(config); err != nil {
			return nil, err
		}
		credential, err := azidentity.NewWorkloadIdentityCredential(
			&azidentity.WorkloadIdentityCredentialOptions{
				ClientOptions:            clientOptions,
				TenantID:                 config.TenantID,
				ClientID:                 config.ClientID,
				TokenFilePath:            config.OIDCTokenFilePath,
				DisableInstanceDiscovery: config.DisableInstanceDiscovery,
			},
		)
		if err != nil {
			return nil, fmt.Errorf("creating workload identity credential: %w", err)
		}
		credentials = append(credentials, credential)

	case config.ClientSecret != "":
		if err := requireTenantAndClient(config); err != nil {
			return nil, err
		}
		credential, err := azidentity.NewClientSecretCredential(
			config.TenantID,
			config.ClientID,
			config.ClientSecret,
			&azidentity.ClientSecretCredentialOptions{
				ClientOptions:            clientOptions,
				DisableInstanceDiscovery: config.DisableInstanceDiscovery,
			},
		)
		if err != nil {
			return nil, fmt.Errorf("creating client secret credential: %w", err)
		}
		credentials = append(credentials, credential)

	case config.ClientCertificatePath != "":
		if err := requireTenantAndClient(config); err != nil {
			return nil, err
		}
		data, err := os.ReadFile(config.ClientCertificatePath)
		if err != nil {
			return nil, fmt.Errorf("reading client certificate: %w", err)
		}
		certificates, key, err := azidentity.ParseCertificates(
			data,
			[]byte(config.ClientCertificatePassword),
		)
		if err != nil {
			return nil, fmt.Errorf("parsing client certificate: %w", err)
		}
		credential, err := azidentity.NewClientCertificateCredential(
			config.TenantID,
			config.ClientID,
			certificates,
			key,
			&azidentity.ClientCertificateCredentialOptions{
				ClientOptions:            clientOptions,
				DisableInstanceDiscovery: config.DisableInstanceDiscovery,
			},
		)
		if err != nil {
			return nil, fmt.Errorf("creating client certificate credential: %w", err)
		}
		credentials = append(credentials, credential)

	case config.OIDCTokenFilePath != "":
		if err := requireTenantAndClient(config); err != nil {
			return nil, err
		}
		credential, err := azidentity.NewWorkloadIdentityCredential(
			&azidentity.WorkloadIdentityCredentialOptions{
				ClientOptions:            clientOptions,
				TenantID:                 config.TenantID,
				ClientID:                 config.ClientID,
				TokenFilePath:            config.OIDCTokenFilePath,
				DisableInstanceDiscovery: config.DisableInstanceDiscovery,
			},
		)
		if err != nil {
			return nil, fmt.Errorf("creating workload identity credential: %w", err)
		}
		credentials = append(credentials, credential)
	}

	if config.UseManagedIdentity {
		options := &azidentity.ManagedIdentityCredentialOptions{
			ClientOptions: clientOptions,
		}
		managedIdentityClientID := config.ManagedIdentityClientID
		if managedIdentityClientID == "" && config.ClientSecret == "" &&
			config.ClientCertificatePath == "" && config.OIDCTokenFilePath == "" {
			managedIdentityClientID = config.ClientID
		}
		if managedIdentityClientID != "" {
			options.ID = azidentity.ClientID(managedIdentityClientID)
		}
		credential, err := azidentity.NewManagedIdentityCredential(options)
		if err != nil {
			return nil, fmt.Errorf("creating managed identity credential: %w", err)
		}
		credentials = append(credentials, credential)
	}

	if config.UseAzureCLI {
		credential, err := azidentity.NewAzureCLICredential(
			&azidentity.AzureCLICredentialOptions{TenantID: config.TenantID},
		)
		if err != nil {
			return nil, fmt.Errorf("creating Azure CLI credential: %w", err)
		}
		credentials = append(credentials, credential)
	}

	if len(credentials) == 0 {
		return nil, fmt.Errorf(
			"no Azure credential configured; configure a service principal, workload identity, managed identity, or set use_azure_cli = true",
		)
	}
	if len(credentials) == 1 {
		return credentials[0], nil
	}

	credential, err := azidentity.NewChainedTokenCredential(credentials, nil)
	if err != nil {
		return nil, fmt.Errorf("creating Azure credential chain: %w", err)
	}
	return credential, nil
}

func withEnvironmentDefaults(config Config) Config {
	if config.TenantID == "" {
		config.TenantID = os.Getenv("AZURE_TENANT_ID")
	}
	if config.ClientID == "" {
		config.ClientID = os.Getenv("AZURE_CLIENT_ID")
	}
	if config.ClientSecret == "" {
		config.ClientSecret = os.Getenv("AZURE_CLIENT_SECRET")
	}
	if config.ClientCertificatePath == "" {
		config.ClientCertificatePath = os.Getenv("AZURE_CLIENT_CERTIFICATE_PATH")
	}
	if config.ClientCertificatePassword == "" {
		config.ClientCertificatePassword = os.Getenv("AZURE_CLIENT_CERTIFICATE_PASSWORD")
	}
	if config.OIDCTokenFilePath == "" {
		config.OIDCTokenFilePath = os.Getenv("AZURE_FEDERATED_TOKEN_FILE")
	}
	if config.AuthorityHost == "" {
		config.AuthorityHost = os.Getenv("AZURE_AUTHORITY_HOST")
	}
	return config
}

func requireTenantAndClient(config Config) error {
	if config.TenantID == "" || config.ClientID == "" {
		return fmt.Errorf("tenant_id and client_id are required for the selected credential")
	}
	return nil
}
