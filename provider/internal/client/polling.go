package client

import (
	"context"
	"fmt"
	"strings"
	"time"
)

func (c *Client) WaitForDiskImage(
	ctx context.Context,
	id string,
	timeout time.Duration,
) (DiskImage, error) {
	deadline := time.Now().Add(timeout)
	interval := 2 * time.Second
	var lastState string

	for {
		image, err := c.GetDiskImage(ctx, id)
		if err == nil {
			if image.Status != nil {
				lastState = image.Status.State
			}
			switch strings.ToLower(lastState) {
			case "ready", "succeeded":
				return image, nil
			case "failed":
				message := ""
				if image.Status != nil {
					message = image.Status.Message
				}
				return DiskImage{}, fmt.Errorf("disk image %s entered Failed state: %s", id, message)
			}
		} else if !IsNotFound(err) {
			return DiskImage{}, err
		}

		if time.Now().After(deadline) {
			return DiskImage{}, fmt.Errorf(
				"disk image %s did not reach Ready within %s; last state %q",
				id,
				timeout,
				lastState,
			)
		}
		if err := sleepContext(ctx, interval); err != nil {
			return DiskImage{}, err
		}
		interval = min(interval+time.Second, 10*time.Second)
	}
}

func (c *Client) WaitForSandbox(
	ctx context.Context,
	id string,
	timeout time.Duration,
) (Sandbox, error) {
	deadline := time.Now().Add(timeout)
	interval := 2 * time.Second
	var lastState string

	for {
		sandbox, err := c.GetSandbox(ctx, id)
		if err == nil {
			lastState = sandbox.State
			switch strings.ToLower(lastState) {
			case "running":
				return sandbox, nil
			case "failed", "deleting":
				return Sandbox{}, fmt.Errorf(
					"sandbox %s entered terminal state %q",
					id,
					lastState,
				)
			}
		} else if !IsNotFound(err) {
			return Sandbox{}, err
		}

		if time.Now().After(deadline) {
			return Sandbox{}, fmt.Errorf(
				"sandbox %s did not reach Running within %s; last state %q",
				id,
				timeout,
				lastState,
			)
		}
		if err := sleepContext(ctx, interval); err != nil {
			return Sandbox{}, err
		}
		interval = min(interval+time.Second, 10*time.Second)
	}
}

func (c *Client) WaitForSandboxRunning(
	ctx context.Context,
	id string,
	timeout time.Duration,
) error {
	_, err := c.WaitForSandbox(ctx, id, timeout)
	return err
}

func (c *Client) WaitForDiskImageDeleted(
	ctx context.Context,
	id string,
	timeout time.Duration,
) error {
	return waitForDeletion(ctx, timeout, func(ctx context.Context) error {
		_, err := c.GetDiskImage(ctx, id)
		return err
	}, "disk image "+id)
}

func (c *Client) WaitForSandboxDeleted(
	ctx context.Context,
	id string,
	timeout time.Duration,
) error {
	return waitForDeletion(ctx, timeout, func(ctx context.Context) error {
		_, err := c.GetSandbox(ctx, id)
		return err
	}, "sandbox "+id)
}

func waitForDeletion(
	ctx context.Context,
	timeout time.Duration,
	get func(context.Context) error,
	name string,
) error {
	deadline := time.Now().Add(timeout)
	interval := 2 * time.Second
	for {
		err := get(ctx)
		if IsNotFound(err) {
			return nil
		}
		if err != nil {
			return err
		}
		if time.Now().After(deadline) {
			return fmt.Errorf("%s was not deleted within %s", name, timeout)
		}
		if err := sleepContext(ctx, interval); err != nil {
			return err
		}
		interval = min(interval+time.Second, 10*time.Second)
	}
}
