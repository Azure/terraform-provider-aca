package client

type DiskImageSpec struct {
	Base       string   `json:"base"`
	Entrypoint []string `json:"entrypoint,omitempty"`
	Command    []string `json:"cmd,omitempty"`
}

type DiskImageStatus struct {
	State   string `json:"state"`
	Message string `json:"message,omitempty"`
}

type DiskImage struct {
	ID     string            `json:"id"`
	Name   string            `json:"name,omitempty"`
	Labels map[string]string `json:"labels,omitempty"`
	Image  *DiskImageSpec    `json:"image,omitempty"`
	Status *DiskImageStatus  `json:"status,omitempty"`
}

type PublicDiskImage struct {
	ID          string            `json:"id"`
	Name        string            `json:"name"`
	Description string            `json:"description,omitempty"`
	Tags        map[string]string `json:"tags,omitempty"`
	Status      *DiskImageStatus  `json:"status,omitempty"`
}

type RegistryCredentials struct {
	Username string `json:"username"`
	Token    string `json:"token"`
}

type CreateDiskImageRequest struct {
	Image                     DiskImageSpec        `json:"image"`
	Labels                    map[string]string    `json:"labels,omitempty"`
	RegistryCredentials       *RegistryCredentials `json:"registryCredentials,omitempty"`
	ManagedIdentityResourceID string               `json:"managedIdentityResourceId,omitempty"`
	ManagedIdentityClientID   string               `json:"managedIdentityClientId,omitempty"`
}

type DiskImageList struct {
	Value    []DiskImage `json:"value"`
	NextLink string      `json:"nextLink,omitempty"`
}

type DiskImageRef struct {
	Name     string `json:"name,omitempty"`
	ID       string `json:"id,omitempty"`
	IsPublic *bool  `json:"isPublic,omitempty"`
}

type SandboxSourcesRef struct {
	DiskImage *DiskImageRef `json:"diskImage,omitempty"`
}

type SandboxResources struct {
	CPU    string `json:"cpu"`
	Memory string `json:"memory"`
	Disk   string `json:"disk,omitempty"`
}

type AutoSuspendPolicy struct {
	Enabled  bool   `json:"enabled"`
	Interval int64  `json:"interval,omitempty"`
	Mode     string `json:"mode,omitempty"`
}

type AutoDeletePolicy struct {
	Enabled               bool  `json:"enabled"`
	DeleteIntervalSeconds int64 `json:"deleteIntervalInSeconds,omitempty"`
}

type LifecyclePolicy struct {
	AutoSuspend *AutoSuspendPolicy `json:"autoSuspendPolicy,omitempty"`
	AutoDelete  *AutoDeletePolicy  `json:"autoDeletePolicy,omitempty"`
}

type PortAuthEntraID struct {
	Enabled bool     `json:"enabled"`
	Emails  []string `json:"emails,omitempty"`
}

type PortAuth struct {
	Anonymous *bool            `json:"anonymous,omitempty"`
	EntraID   *PortAuthEntraID `json:"entraId,omitempty"`
}

type PortIPRule struct {
	Name        string   `json:"name"`
	Action      string   `json:"action"`
	Priority    int64    `json:"priority"`
	SourceCIDRs []string `json:"sourceCidrs"`
}

type PortIPAccessControl struct {
	DefaultAction string       `json:"defaultAction"`
	Rules         []PortIPRule `json:"rules,omitempty"`
}

type PortRequest struct {
	Port            int64                `json:"port"`
	Protocol        string               `json:"protocol,omitempty"`
	ActivationMode  string               `json:"activationMode,omitempty"`
	Auth            *PortAuth            `json:"auth,omitempty"`
	IPAccessControl *PortIPAccessControl `json:"ipAccessControl,omitempty"`
}

type SandboxPort struct {
	Port            int64                `json:"port"`
	HostPort        int64                `json:"hostPort,omitempty"`
	Protocol        string               `json:"protocol,omitempty"`
	URL             string               `json:"url,omitempty"`
	Auth            *PortAuth            `json:"auth,omitempty"`
	IPAccessControl *PortIPAccessControl `json:"ipAccessControl,omitempty"`
}

type EgressHostRule struct {
	Pattern string `json:"pattern"`
	Action  string `json:"action"`
}

type EgressSecretRef struct {
	SecretID  string `json:"secretId"`
	SecretKey string `json:"secretKey,omitempty"`
	Format    string `json:"format,omitempty"`
}

type EgressManagedIdentityRef struct {
	IdentityType       string `json:"identityType"`
	Resource           string `json:"resource"`
	IdentityResourceID string `json:"identityResourceId,omitempty"`
	Format             string `json:"format,omitempty"`
}

type EgressHeaderValueRef struct {
	SecretRef          *EgressSecretRef          `json:"secretRef,omitempty"`
	ManagedIdentityRef *EgressManagedIdentityRef `json:"managedIdentityRef,omitempty"`
}

type EgressHeader struct {
	Operation string                `json:"operation"`
	Name      string                `json:"name"`
	Value     string                `json:"value,omitempty"`
	ValueRef  *EgressHeaderValueRef `json:"valueRef,omitempty"`
}

type EgressRuleMatch struct {
	Host    string   `json:"host"`
	Path    string   `json:"path,omitempty"`
	Methods []string `json:"methods,omitempty"`
}

type EgressRuleAction struct {
	Type    string         `json:"type"`
	Host    string         `json:"host,omitempty"`
	Path    string         `json:"path,omitempty"`
	Scheme  string         `json:"scheme,omitempty"`
	Headers []EgressHeader `json:"headers,omitempty"`
}

type EgressRule struct {
	Name   string            `json:"name,omitempty"`
	Match  *EgressRuleMatch  `json:"match,omitempty"`
	Action *EgressRuleAction `json:"action,omitempty"`
}

type EgressPolicy struct {
	DefaultAction     string           `json:"defaultAction"`
	HostRules         []EgressHostRule `json:"hostRules,omitempty"`
	Rules             []EgressRule     `json:"rules,omitempty"`
	TrafficInspection string           `json:"trafficInspection,omitempty"`
}

type CreateSandboxRequest struct {
	PresetSandboxType          string             `json:"presetSandboxType,omitempty"`
	SourcesRef                 *SandboxSourcesRef `json:"sourcesRef,omitempty"`
	Resources                  *SandboxResources  `json:"resources,omitempty"`
	Lifecycle                  *LifecyclePolicy   `json:"lifecycle,omitempty"`
	Labels                     map[string]string  `json:"labels,omitempty"`
	Environment                map[string]string  `json:"environment,omitempty"`
	Connections                []string           `json:"connections,omitempty"`
	EgressPolicy               *EgressPolicy      `json:"egressPolicy,omitempty"`
	Ports                      []PortRequest      `json:"ports,omitempty"`
	Entrypoint                 []string           `json:"entrypoint,omitempty"`
	Command                    []string           `json:"cmd,omitempty"`
	SkipEgressProxy            *bool              `json:"skipEgressProxy,omitempty"`
	CustomerVNetConnectionName string             `json:"customerVnetConnectionName,omitempty"`
	VMMType                    string             `json:"vmmType,omitempty"`
}

type SandboxStateDetails struct {
	StoppedReason string `json:"stoppedReason,omitempty"`
	StoppedAt     string `json:"stoppedAt,omitempty"`
}

type Sandbox struct {
	ID                         string               `json:"id"`
	State                      string               `json:"state,omitempty"`
	StateDetails               *SandboxStateDetails `json:"stateDetails,omitempty"`
	Labels                     map[string]string    `json:"labels,omitempty"`
	VMMType                    string               `json:"vmmType,omitempty"`
	Ports                      []SandboxPort        `json:"ports,omitempty"`
	Resources                  *SandboxResources    `json:"resources,omitempty"`
	EgressPolicy               *EgressPolicy        `json:"egressPolicy,omitempty"`
	Environment                map[string]string    `json:"environment,omitempty"`
	Connections                []string             `json:"connections,omitempty"`
	CustomerVNetConnectionName string               `json:"customerVnetConnectionName,omitempty"`
	Lifecycle                  *LifecyclePolicy     `json:"lifecycle,omitempty"`
	SourcesRef                 *SandboxSourcesRef   `json:"sourcesRef,omitempty"`
	PresetSandboxType          string               `json:"presetSandboxType,omitempty"`
	Hostname                   string               `json:"hostname,omitempty"`
	CreatedAt                  string               `json:"createdAt,omitempty"`
	Region                     string               `json:"region,omitempty"`
	Entrypoint                 []string             `json:"entrypoint,omitempty"`
	ManagementURL              string               `json:"managementUrl,omitempty"`
}

type SandboxList struct {
	Value    []Sandbox `json:"value"`
	NextLink string    `json:"nextLink,omitempty"`
}
