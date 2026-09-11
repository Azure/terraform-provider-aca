package ids

import "testing"

func TestParseGroupID(t *testing.T) {
	t.Parallel()

	input := "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.App/sandboxGroups/group"
	group, err := ParseGroupID(input)
	if err != nil {
		t.Fatalf("ParseGroupID() error = %v", err)
	}
	if group.SubscriptionID != "sub" || group.ResourceGroup != "rg" || group.SandboxGroup != "group" {
		t.Fatalf("ParseGroupID() = %#v", group)
	}
	if group.String() != input {
		t.Fatalf("GroupID.String() = %q", group.String())
	}
}

func TestParseGroupIDRejectsTraversal(t *testing.T) {
	t.Parallel()

	_, err := ParseGroupID(
		"/subscriptions/sub/resourceGroups/../providers/Microsoft.App/sandboxGroups/group",
	)
	if err == nil {
		t.Fatal("ParseGroupID() expected an error")
	}
}

func TestParseStandardResourceURL(t *testing.T) {
	t.Parallel()

	endpoint, group, id, err := ParseResourceURL(
		"https://management.swedencentral.azuredevcompute.io/subscriptions/sub/resourceGroups/rg/sandboxGroups/group/sandboxes/sbx-id",
		"sandboxes",
	)
	if err != nil {
		t.Fatalf("ParseResourceURL() error = %v", err)
	}
	if !endpoint.Standard || endpoint.Location != "swedencentral" {
		t.Fatalf("ParseResourceURL() endpoint = %#v", endpoint)
	}
	if group.String() != "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.App/sandboxGroups/group" {
		t.Fatalf("ParseResourceURL() group = %q", group.String())
	}
	if id != "sbx-id" {
		t.Fatalf("ParseResourceURL() id = %q", id)
	}
}

func TestParseCustomResourceURL(t *testing.T) {
	t.Parallel()

	endpoint, _, _, err := ParseResourceURL(
		"https://sandbox.example.test/subscriptions/sub/resourceGroups/rg/sandboxGroups/group/diskimages/image-id",
		"diskimages",
	)
	if err != nil {
		t.Fatalf("ParseResourceURL() error = %v", err)
	}
	if endpoint.Standard || endpoint.URL.Hostname() != "sandbox.example.test" {
		t.Fatalf("ParseResourceURL() endpoint = %#v", endpoint)
	}
}

func TestParseResourceURLRejectsQuery(t *testing.T) {
	t.Parallel()

	_, _, _, err := ParseResourceURL(
		"https://management.eastus2.azuredevcompute.io/subscriptions/sub/resourceGroups/rg/sandboxGroups/group/sandboxes/id?api-version=x",
		"sandboxes",
	)
	if err == nil {
		t.Fatal("ParseResourceURL() expected an error")
	}
}
