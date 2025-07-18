#!/bin/bash

# test-capg.sh - Test CAPG configuration without real GCP credentials

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🧪 Testing CAPG Configuration..."

# Step 1: Create mock GCP credentials for testing
echo "📄 Creating mock GCP credentials..."
mkdir -p .tmp
cat > .tmp/mock-gcp-credentials.json <<EOF
{
  "type": "service_account",
  "project_id": "test-project-id",
  "private_key_id": "test-key-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...\n-----END PRIVATE KEY-----\n",
  "client_email": "test-sa@test-project-id.iam.gserviceaccount.com",
  "client_id": "123456789",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/test-sa%40test-project-id.iam.gserviceaccount.com"
}
EOF

# Step 2: Create test CAPG tfvars with mock credentials
echo "⚙️  Creating test CAPG configuration..."
cat > .tmp/test-capg.tfvars <<EOF
# Test CAPG configuration with mock credentials

capg = {
    test_cluster = {
        enabled = true

        auth = {
            project = "test-project-id"
            service_account_key_file = ".tmp/mock-gcp-credentials.json"
        }

        meta = {
            cluster_name = "test-jarvice-capg"
            kubernetes_version = "v1.28.0"
            ssh_public_key = null
        }

        location = {
            region = "us-central1"
            zones = ["us-central1-a", "us-central1-b", "us-central1-c"]
        }

        system_node_pool = {
            nodes_type = "n1-standard-4"
            nodes_num = 3
        }

        dockerbuild_node_pool = {
            nodes_type = "c2-standard-4"
            nodes_num = 1
            nodes_min = 0
            nodes_max = 5
        }

        compute_node_pools = {
            jxecompute00 = {
                nodes_type = "n1-standard-8"
                nodes_disk_size_gb = 100
                nodes_num = 0
                nodes_min = 0
                nodes_max = 20
                meta = {
                    disable_hyperthreading = "false"
                    disk_type = "pd-standard"
                }
            }
        }

        cluster = {
            project = "test-project-id"
            
            network = {
                name = "test-jarvice-capg-network"
                create_network = true
                subnet_name = "test-jarvice-capg-subnet"
                subnet_cidr = "10.0.0.0/16"
                pod_cidr = "192.168.0.0/16"
                service_cidr = "10.96.0.0/12"
            }

            control_plane = {
                machine_type = "n1-standard-4"
                disk_size_gb = 100
                image = "ubuntu-2204-jammy-v20231213"
                kubernetes_version = "v1.28.0"
            }

            node_pools = {
                system = {
                    machine_type = "n1-standard-4"
                    disk_size_gb = 100
                    replicas = 3
                    min_replicas = 1
                    max_replicas = 10
                    enable_autoscaling = true
                }
            }
        }

        helm = {
            jarvice = {
                values_yaml = <<EOY
# Test JARVICE values
jarvice:
  JARVICE_CLUSTER_TYPE: upstream
  imagePullPolicy: Always
EOY
            }
        }
    }
}
EOF

# Step 3: Test terraform initialization
echo "🔧 Testing Terraform initialization..."
terraform init -upgrade

# Step 4: Test terraform validation
echo "✅ Testing Terraform validation..."
terraform validate

# Step 5: Test terraform plan (this will show the structure without actually creating resources)
echo "📋 Testing Terraform plan structure..."
terraform plan -var-file=tfvars/global.tfvars -var-file=.tmp/test-capg.tfvars -out=.tmp/test.plan

# Step 6: Show plan summary
echo "📊 Plan Summary:"
terraform show -json .tmp/test.plan | jq -r '
    .planned_values.root_module.resources[]? | 
    select(.type != null) | 
    "\(.type).\(.name // .index)"
' | sort | uniq -c | sort -nr

echo ""
echo "✅ CAPG Configuration Test Complete!"
echo ""
echo "📁 Generated files:"
echo "   .tmp/mock-gcp-credentials.json - Mock GCP credentials"
echo "   .tmp/test-capg.tfvars - Test CAPG configuration"
echo "   .tmp/test.plan - Terraform plan file"
echo ""
echo "🚀 To test the full deployment workflow:"
echo "   1. Replace mock credentials with real GCP service account key"
echo "   2. Update project ID in test-capg.tfvars"
echo "   3. Run: terraform apply -var-file=tfvars/global.tfvars -var-file=.tmp/test-capg.tfvars"
echo ""
