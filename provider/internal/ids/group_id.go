package ids

import (
	"fmt"
	"net/url"
	"regexp"
	"strings"
)

var (
	groupIDPattern      = regexp.MustCompile(`(?i)^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\.App/sandboxGroups/([^/]+)$`)
	locationPattern     = regexp.MustCompile(`^[a-z0-9]+$`)
	standardHostPattern = regexp.MustCompile(`^management\.([a-z0-9]+)\.azuredevcompute\.io$`)
)

type GroupID struct {
	SubscriptionID string
	ResourceGroup  string
	SandboxGroup   string
}

func ParseGroupID(value string) (GroupID, error) {
	matches := groupIDPattern.FindStringSubmatch(strings.TrimSpace(value))
	if len(matches) != 4 {
		return GroupID{}, fmt.Errorf(
			"expected /subscriptions/{subscription}/resourceGroups/{resourceGroup}/providers/Microsoft.App/sandboxGroups/{sandboxGroup}",
		)
	}

	for _, segment := range matches[1:] {
		if err := validateSegment(segment); err != nil {
			return GroupID{}, err
		}
	}

	return GroupID{
		SubscriptionID: matches[1],
		ResourceGroup:  matches[2],
		SandboxGroup:   matches[3],
	}, nil
}

func (id GroupID) String() string {
	return fmt.Sprintf(
		"/subscriptions/%s/resourceGroups/%s/providers/Microsoft.App/sandboxGroups/%s",
		id.SubscriptionID,
		id.ResourceGroup,
		id.SandboxGroup,
	)
}

func (id GroupID) DataPlanePath() string {
	return fmt.Sprintf(
		"/subscriptions/%s/resourceGroups/%s/sandboxGroups/%s",
		url.PathEscape(id.SubscriptionID),
		url.PathEscape(id.ResourceGroup),
		url.PathEscape(id.SandboxGroup),
	)
}

type Endpoint struct {
	URL      *url.URL
	Location string
	Standard bool
}

func EndpointForLocation(location string) (Endpoint, error) {
	normalized := strings.ToLower(strings.ReplaceAll(strings.TrimSpace(location), " ", ""))
	if !locationPattern.MatchString(normalized) {
		return Endpoint{}, fmt.Errorf("location must contain only letters and numbers")
	}

	parsed, err := url.Parse("https://management." + normalized + ".azuredevcompute.io")
	if err != nil {
		return Endpoint{}, fmt.Errorf("constructing regional endpoint: %w", err)
	}

	return Endpoint{URL: parsed, Location: normalized, Standard: true}, nil
}

func ParseEndpoint(value string) (Endpoint, error) {
	parsed, err := url.Parse(strings.TrimSpace(value))
	if err != nil {
		return Endpoint{}, fmt.Errorf("parsing endpoint: %w", err)
	}
	if parsed.Scheme != "https" {
		return Endpoint{}, fmt.Errorf("endpoint must use HTTPS")
	}
	if parsed.Host == "" || parsed.User != nil || parsed.RawQuery != "" || parsed.Fragment != "" {
		return Endpoint{}, fmt.Errorf("endpoint must contain only an HTTPS scheme and host")
	}
	if parsed.Path != "" && parsed.Path != "/" {
		return Endpoint{}, fmt.Errorf("endpoint must not contain a path")
	}

	parsed.Path = ""
	parsed.RawPath = ""
	host := strings.ToLower(parsed.Hostname())
	if matches := standardHostPattern.FindStringSubmatch(host); len(matches) == 2 {
		return Endpoint{URL: parsed, Location: matches[1], Standard: true}, nil
	}

	return Endpoint{URL: parsed, Standard: false}, nil
}

func IsSandboxHost(host string) bool {
	normalized := strings.ToLower(strings.TrimSuffix(host, "."))
	return normalized == "azuredevcompute.io" || strings.HasSuffix(normalized, ".azuredevcompute.io")
}

func ParseResourceURL(value, collection string) (Endpoint, GroupID, string, error) {
	parsed, err := url.Parse(strings.TrimSpace(value))
	if err != nil {
		return Endpoint{}, GroupID{}, "", fmt.Errorf("parsing import URL: %w", err)
	}
	if parsed.Scheme != "https" || parsed.Host == "" || parsed.User != nil {
		return Endpoint{}, GroupID{}, "", fmt.Errorf("import URL must be an absolute HTTPS URL")
	}
	if parsed.RawQuery != "" || parsed.Fragment != "" {
		return Endpoint{}, GroupID{}, "", fmt.Errorf("import URL must not contain a query string or fragment")
	}

	segments := strings.Split(strings.Trim(parsed.EscapedPath(), "/"), "/")
	if len(segments) != 8 ||
		!strings.EqualFold(segments[0], "subscriptions") ||
		!strings.EqualFold(segments[2], "resourceGroups") ||
		!strings.EqualFold(segments[4], "sandboxGroups") ||
		!strings.EqualFold(segments[6], collection) {
		return Endpoint{}, GroupID{}, "", fmt.Errorf(
			"expected /subscriptions/{subscription}/resourceGroups/{resourceGroup}/sandboxGroups/{group}/%s/{id}",
			collection,
		)
	}

	decoded := make([]string, len(segments))
	for i, segment := range segments {
		decoded[i], err = url.PathUnescape(segment)
		if err != nil {
			return Endpoint{}, GroupID{}, "", fmt.Errorf("decoding import URL path: %w", err)
		}
	}

	group := GroupID{
		SubscriptionID: decoded[1],
		ResourceGroup:  decoded[3],
		SandboxGroup:   decoded[5],
	}
	for _, segment := range []string{group.SubscriptionID, group.ResourceGroup, group.SandboxGroup, decoded[7]} {
		if err := validateSegment(segment); err != nil {
			return Endpoint{}, GroupID{}, "", err
		}
	}

	endpoint, err := ParseEndpoint(parsed.Scheme + "://" + parsed.Host)
	if err != nil {
		return Endpoint{}, GroupID{}, "", err
	}

	return endpoint, group, decoded[7], nil
}

func ResourceURL(endpoint Endpoint, group GroupID, collection, resourceID string) (string, error) {
	if err := validateSegment(resourceID); err != nil {
		return "", err
	}
	return strings.TrimSuffix(endpoint.URL.String(), "/") +
		group.DataPlanePath() + "/" + collection + "/" + url.PathEscape(resourceID), nil
}

func validateSegment(value string) error {
	if value == "" || strings.ContainsAny(value, `/\`+"\x00") || strings.Contains(value, "..") {
		return fmt.Errorf("resource ID segments must not be empty or contain '/', '\\', '..', or null bytes")
	}
	return nil
}
