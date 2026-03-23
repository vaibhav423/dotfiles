#(6 cores are max but c4d doesnt have customize option to 6 rather only 4 and 8) specs root storage - 100gb , core - 4 (8vcpu) , mem -31 gb
gcloud compute instances create fire-ce \
    --project=circular-matrix-474605-r1 \
    --zone=us-central1-a \
    --machine-type=c4d-standard-8 \
    --network-interface=network-tier=PREMIUM,nic-type=GVNIC,stack-type=IPV4_ONLY,subnet=default \
    --metadata=enable-osconfig=TRUE,ssh-keys=fire:ssh-ed25519\ \
AAAAC3NzaC1lZDI1NTE5AAAAIG\+7Lo\+314Shd2gP6RXIzEk6mS7y8bk9i0uumEgZ8sse\ fire \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=393534185039-compute@developer.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
    --create-disk=auto-delete=yes,boot=yes,device-name=fire-ce,disk-resource-policy=projects/circular-matrix-474605-r1/regions/us-central1/resourcePolicies/default-schedule-1,image=projects/debian-cloud/global/images/debian-12-bookworm-v20251111,mode=rw,provisioned-iops=3600,provisioned-throughput=290,size=100,type=hyperdisk-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ops-agent-policy=v2-x86-template-1-4-0,goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any \
&& \
printf 'agentsRule:\n  packageState: installed\n  version: latest\ninstanceFilter:\n  inclusionLabels:\n  - labels:\n      goog-ops-agent-policy: v2-x86-template-1-4-0\n' > config.yaml \
&& \
gcloud compute instances ops-agents policies create goog-ops-agent-v2-x86-template-1-4-0-us-central1-a \
    --project=circular-matrix-474605-r1 \
    --zone=us-central1-a \
    --file=config.yaml

# write ip to file ~/fire-ce-ip.txt
gcloud compute instances describe fire-ce --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' > ~/fire-ce-ip.txt
