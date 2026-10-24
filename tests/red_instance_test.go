package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func getAWSRegion() string {
	if r := os.Getenv("AWS_REGION"); r != "" {
		return r
	}
	if r := os.Getenv("AWS_DEFAULT_REGION"); r != "" {
		return r
	}
	return "us-east-1"
}

// Path 1: the module provisions its own network (create_vpc = true).
func TestRedInstanceCreatesNetwork(t *testing.T) {
	t.Parallel()

	ctx := t.Context()

	awsRegion := getAWSRegion()
	projectName := fmt.Sprintf("red-inst-own-%s", strings.ToLower(random.UniqueId()))
	instanceName := fmt.Sprintf("red-%s", strings.ToLower(random.UniqueId()))

	opts := &terraform.Options{
		TerraformDir: "../examples/complete",
		Vars: map[string]interface{}{
			"region":        awsRegion,
			"project_name":  projectName,
			"instance_name": instanceName,
		},
	}

	defer test_structure.RunTestStage(t, "teardown", func() {
		terraform.DestroyContext(t, ctx, opts)
	})

	test_structure.RunTestStage(t, "setup", func() {
		terraform.InitAndApplyContext(t, ctx, opts)
	})

	test_structure.RunTestStage(t, "validate", func() {
		instanceID := terraform.OutputContext(t, ctx, opts, "instance_id")
		if instanceID == "" || !strings.HasPrefix(instanceID, "i-") {
			t.Fatalf("Expected an instance ID starting with 'i-', got: %q", instanceID)
		}

		publicIP := terraform.OutputContext(t, ctx, opts, "public_ip")
		if publicIP == "Public IP not allocated" || publicIP == "" {
			t.Fatalf("Expected a public IP, got: %q", publicIP)
		}
		privateIP := terraform.OutputContext(t, ctx, opts, "private_ip")
		if !strings.HasPrefix(privateIP, "10.0.1.") {
			t.Fatalf("Expected an AWS-assigned private IP in 10.0.1.0/24, got: %q", privateIP)
		}
	})
}

// Path 2: the module consumes an externally-provided network
// (create_vpc = false, vpc_id/subnet_id supplied by the caller).
func TestRedInstanceUsesExistingNetwork(t *testing.T) {
	t.Parallel()

	ctx := t.Context()

	awsRegion := getAWSRegion()
	projectName := fmt.Sprintf("red-inst-ext-%s", strings.ToLower(random.UniqueId()))
	instanceName := fmt.Sprintf("red-%s", strings.ToLower(random.UniqueId()))

	opts := &terraform.Options{
		TerraformDir: "../examples/existing-network",
		Vars: map[string]interface{}{
			"region":        awsRegion,
			"project_name":  projectName,
			"instance_name": instanceName,
		},
	}

	defer test_structure.RunTestStage(t, "teardown", func() {
		terraform.DestroyContext(t, ctx, opts)
	})

	test_structure.RunTestStage(t, "setup", func() {
		terraform.InitAndApplyContext(t, ctx, opts)
	})

	test_structure.RunTestStage(t, "validate", func() {
		instanceID := terraform.OutputContext(t, ctx, opts, "instance_id")
		if instanceID == "" || !strings.HasPrefix(instanceID, "i-") {
			t.Fatalf("Expected an instance ID starting with 'i-', got: %q", instanceID)
		}

		suppliedVPC := terraform.OutputContext(t, ctx, opts, "supplied_vpc_id")
		if !strings.HasPrefix(suppliedVPC, "vpc-") {
			t.Fatalf("Expected supplied VPC ID starting with 'vpc-', got: %q", suppliedVPC)
		}

		// With the output change, the module echoes the supplied VPC ID.
		// Assert it matches exactly — proves the instance landed in the
		// network it was handed, not one the module created.
		moduleVPC := terraform.OutputContext(t, ctx, opts, "vpc_id")
		if moduleVPC != suppliedVPC {
			t.Fatalf("Module vpc_id (%q) should equal supplied VPC (%q)", moduleVPC, suppliedVPC)
		}

		const pinnedIP = "10.20.1.10"
		privateIP := terraform.OutputContext(t, ctx, opts, "private_ip")
		if privateIP != pinnedIP {
			t.Fatalf("Expected pinned private IP %q, got: %q", pinnedIP, privateIP)
		}

		// The 8080 rule must reference the source security group, not a CIDR.
		instanceSG := terraform.OutputContext(t, ctx, opts, "security_group_id")
		sourceSG := terraform.OutputContext(t, ctx, opts, "source_security_group_id")

		cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(awsRegion))
		if err != nil {
			t.Fatalf("Failed to load AWS config: %v", err)
		}
		client := ec2.NewFromConfig(cfg)

		out, err := client.DescribeSecurityGroupRules(ctx, &ec2.DescribeSecurityGroupRulesInput{
			Filters: []types.Filter{
				{Name: aws.String("group-id"), Values: []string{instanceSG}},
			},
		})
		if err != nil {
			t.Fatalf("Failed to describe rules for %s: %v", instanceSG, err)
		}

		found := false
		for _, r := range out.SecurityGroupRules {
			if aws.ToBool(r.IsEgress) || r.ReferencedGroupInfo == nil {
				continue
			}
			if aws.ToString(r.ReferencedGroupInfo.GroupId) == sourceSG && aws.ToInt32(r.FromPort) == 8080 {
				found = true
				break
			}
		}
		if !found {
			t.Fatalf("Expected an ingress rule on %s for port 8080 from source SG %s", instanceSG, sourceSG)
		}
	})
}
