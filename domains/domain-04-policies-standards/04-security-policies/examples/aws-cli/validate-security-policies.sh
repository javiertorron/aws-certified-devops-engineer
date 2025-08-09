#!/bin/bash

# AWS CLI Script for Security Policies Validation
# This script validates security policies and compliance across AWS resources
# Prerequisites: AWS CLI configured with appropriate permissions

set -euo pipefail

# Configuration variables
PROJECT_NAME="${PROJECT_NAME:-devops-security}"
ENVIRONMENT="${ENVIRONMENT:-production}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters for summary
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_CHECKS++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNING_CHECKS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_CHECKS++))
}

increment_total() {
    ((TOTAL_CHECKS++))
}

# Function to check password policy
check_password_policy() {
    log_info "Checking account password policy..."
    increment_total
    
    local policy_output
    if policy_output=$(aws iam get-account-password-policy 2>/dev/null); then
        local min_length=$(echo "$policy_output" | jq -r '.PasswordPolicy.MinimumPasswordLength')
        local require_symbols=$(echo "$policy_output" | jq -r '.PasswordPolicy.RequireSymbols')
        local require_numbers=$(echo "$policy_output" | jq -r '.PasswordPolicy.RequireNumbers')
        local require_uppercase=$(echo "$policy_output" | jq -r '.PasswordPolicy.RequireUppercaseCharacters')
        local require_lowercase=$(echo "$policy_output" | jq -r '.PasswordPolicy.RequireLowercaseCharacters')
        local max_age=$(echo "$policy_output" | jq -r '.PasswordPolicy.MaxPasswordAge // 999')
        
        if [[ "$min_length" -ge 14 ]] && \
           [[ "$require_symbols" == "true" ]] && \
           [[ "$require_numbers" == "true" ]] && \
           [[ "$require_uppercase" == "true" ]] && \
           [[ "$require_lowercase" == "true" ]] && \
           [[ "$max_age" -le 90 ]]; then
            log_success "Password policy meets security requirements"
        else
            log_error "Password policy does not meet security requirements"
            echo "  Current settings: MinLength=$min_length, MaxAge=$max_age"
        fi
    else
        log_error "No password policy configured"
    fi
}

# Function to check for root access keys
check_root_access_keys() {
    log_info "Checking for root access keys..."
    increment_total
    
    local summary_output
    if summary_output=$(aws iam get-account-summary 2>/dev/null); then
        local root_access_keys=$(echo "$summary_output" | jq -r '.SummaryMap.AccountAccessKeysPresent')
        
        if [[ "$root_access_keys" -eq 0 ]]; then
            log_success "No root access keys present"
        else
            log_error "Root access keys are present - security risk!"
        fi
    else
        log_warning "Unable to check root access key status"
    fi
}

# Function to check MFA for root user
check_root_mfa() {
    log_info "Checking root user MFA status..."
    increment_total
    
    local summary_output
    if summary_output=$(aws iam get-account-summary 2>/dev/null); then
        local root_mfa=$(echo "$summary_output" | jq -r '.SummaryMap.AccountMFAEnabled')
        
        if [[ "$root_mfa" -eq 1 ]]; then
            log_success "Root user MFA is enabled"
        else
            log_error "Root user MFA is not enabled"
        fi
    else
        log_warning "Unable to check root MFA status"
    fi
}

# Function to check GuardDuty status
check_guardduty_status() {
    log_info "Checking GuardDuty status..."
    increment_total
    
    local detectors
    if detectors=$(aws guardduty list-detectors 2>/dev/null); then
        local detector_count=$(echo "$detectors" | jq -r '.DetectorIds | length')
        
        if [[ "$detector_count" -gt 0 ]]; then
            local detector_id=$(echo "$detectors" | jq -r '.DetectorIds[0]')
            local detector_details=$(aws guardduty get-detector --detector-id "$detector_id" 2>/dev/null)
            local status=$(echo "$detector_details" | jq -r '.Status')
            
            if [[ "$status" == "ENABLED" ]]; then
                log_success "GuardDuty is enabled and active"
                
                # Check for high severity findings
                local findings_count
                if findings_count=$(aws guardduty get-findings-statistics --detector-id "$detector_id" --finding-criteria '{"Criterion":{"severity":{"Gte":7.0}}}' 2>/dev/null); then
                    local high_findings=$(echo "$findings_count" | jq -r '.FindingStatistics.CountBySeverity.High // 0')
                    if [[ "$high_findings" -gt 0 ]]; then
                        log_warning "GuardDuty has $high_findings high severity findings"
                    fi
                fi
            else
                log_error "GuardDuty detector exists but is not enabled"
            fi
        else
            log_error "GuardDuty is not enabled"
        fi
    else
        log_error "Unable to check GuardDuty status"
    fi
}

# Function to check Security Hub status
check_security_hub_status() {
    log_info "Checking Security Hub status..."
    increment_total
    
    if aws securityhub describe-hub >/dev/null 2>&1; then
        log_success "Security Hub is enabled"
        
        # Check for high severity findings
        local findings
        if findings=$(aws securityhub get-findings --filters '{"SeverityLabel":[{"Value":"HIGH","Comparison":"EQUALS"}]}' --max-items 50 2>/dev/null); then
            local high_findings_count=$(echo "$findings" | jq -r '.Findings | length')
            if [[ "$high_findings_count" -gt 0 ]]; then
                log_warning "Security Hub has $high_findings_count high severity findings"
            fi
        fi
    else
        log_error "Security Hub is not enabled"
    fi
}

# Function to check Config status
check_config_status() {
    log_info "Checking AWS Config status..."
    increment_total
    
    local recorders
    if recorders=$(aws configservice describe-configuration-recorders 2>/dev/null); then
        local recorder_count=$(echo "$recorders" | jq -r '.ConfigurationRecorders | length')
        
        if [[ "$recorder_count" -gt 0 ]]; then
            local recorder_name=$(echo "$recorders" | jq -r '.ConfigurationRecorders[0].name')
            local recorder_status=$(aws configservice describe-configuration-recorder-status --configuration-recorder-names "$recorder_name" 2>/dev/null)
            local recording=$(echo "$recorder_status" | jq -r '.ConfigurationRecordersStatus[0].recording')
            
            if [[ "$recording" == "true" ]]; then
                log_success "AWS Config is active and recording"
            else
                log_error "AWS Config recorder exists but is not recording"
            fi
        else
            log_error "AWS Config is not configured"
        fi
    else
        log_error "Unable to check AWS Config status"
    fi
}

# Function to check Config rules compliance
check_config_rules_compliance() {
    log_info "Checking Config rules compliance..."
    
    local rules=("encrypted-volumes" "s3-bucket-public-read-prohibited" "root-access-key-check" "iam-password-policy")
    
    for rule in "${rules[@]}"; do
        increment_total
        local compliance
        if compliance=$(aws configservice get-compliance-details-by-config-rule --config-rule-name "$rule" 2>/dev/null); then
            local compliant_count=$(echo "$compliance" | jq -r '[.EvaluationResults[] | select(.ComplianceType == "COMPLIANT")] | length')
            local non_compliant_count=$(echo "$compliance" | jq -r '[.EvaluationResults[] | select(.ComplianceType == "NON_COMPLIANT")] | length')
            
            if [[ "$non_compliant_count" -eq 0 ]]; then
                log_success "Config rule '$rule': All resources compliant ($compliant_count resources)"
            else
                log_error "Config rule '$rule': $non_compliant_count non-compliant resources found"
            fi
        else
            log_warning "Config rule '$rule': Unable to check compliance or rule not found"
        fi
    done
}

# Function to check S3 bucket security
check_s3_bucket_security() {
    log_info "Checking S3 bucket security settings..."
    
    local buckets
    if buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null); then
        for bucket in $buckets; do
            increment_total
            
            # Check public access block
            local public_access_block
            if public_access_block=$(aws s3api get-public-access-block --bucket "$bucket" 2>/dev/null); then
                local block_public_acls=$(echo "$public_access_block" | jq -r '.PublicAccessBlockConfiguration.BlockPublicAcls')
                local block_public_policy=$(echo "$public_access_block" | jq -r '.PublicAccessBlockConfiguration.BlockPublicPolicy')
                local ignore_public_acls=$(echo "$public_access_block" | jq -r '.PublicAccessBlockConfiguration.IgnorePublicAcls')
                local restrict_public_buckets=$(echo "$public_access_block" | jq -r '.PublicAccessBlockConfiguration.RestrictPublicBuckets')
                
                if [[ "$block_public_acls" == "true" ]] && \
                   [[ "$block_public_policy" == "true" ]] && \
                   [[ "$ignore_public_acls" == "true" ]] && \
                   [[ "$restrict_public_buckets" == "true" ]]; then
                    log_success "S3 bucket '$bucket': Public access properly blocked"
                else
                    log_error "S3 bucket '$bucket': Public access not fully blocked"
                fi
            else
                log_warning "S3 bucket '$bucket': Unable to check public access block settings"
            fi
            
            # Check encryption
            increment_total
            if aws s3api get-bucket-encryption --bucket "$bucket" >/dev/null 2>&1; then
                log_success "S3 bucket '$bucket': Encryption enabled"
            else
                log_error "S3 bucket '$bucket': No encryption configured"
            fi
        done
    else
        log_warning "Unable to list S3 buckets"
    fi
}

# Function to check EC2 security groups
check_ec2_security_groups() {
    log_info "Checking EC2 security groups..."
    
    local security_groups
    if security_groups=$(aws ec2 describe-security-groups --query 'SecurityGroups[?GroupName!=`default`]' 2>/dev/null); then
        local sg_count=$(echo "$security_groups" | jq -r '. | length')
        local risky_sgs=0
        
        for ((i=0; i<sg_count; i++)); do
            increment_total
            local sg_id=$(echo "$security_groups" | jq -r ".[$i].GroupId")
            local sg_name=$(echo "$security_groups" | jq -r ".[$i].GroupName")
            local ingress_rules=$(echo "$security_groups" | jq -r ".[$i].IpPermissions")
            
            # Check for overly permissive rules (0.0.0.0/0)
            local open_rules=$(echo "$ingress_rules" | jq -r '[.[] | select(.IpRanges[]?.CidrIp == "0.0.0.0/0")] | length')
            
            if [[ "$open_rules" -gt 0 ]]; then
                log_error "Security group '$sg_name' ($sg_id): Has $open_rules rules open to the internet (0.0.0.0/0)"
                ((risky_sgs++))
            else
                log_success "Security group '$sg_name' ($sg_id): No overly permissive rules"
            fi
        done
        
        if [[ "$risky_sgs" -eq 0 ]]; then
            log_info "All security groups follow security best practices"
        else
            log_warning "Found $risky_sgs security groups with potential security risks"
        fi
    else
        log_warning "Unable to check security groups"
    fi
}

# Function to check IAM users without MFA
check_iam_users_mfa() {
    log_info "Checking IAM users MFA status..."
    
    local users
    if users=$(aws iam list-users --query 'Users[].UserName' --output text 2>/dev/null); then
        local users_without_mfa=0
        
        for user in $users; do
            increment_total
            local mfa_devices
            if mfa_devices=$(aws iam list-mfa-devices --user-name "$user" 2>/dev/null); then
                local device_count=$(echo "$mfa_devices" | jq -r '.MFADevices | length')
                
                if [[ "$device_count" -eq 0 ]]; then
                    log_error "IAM user '$user': No MFA device configured"
                    ((users_without_mfa++))
                else
                    log_success "IAM user '$user': MFA device configured"
                fi
            else
                log_warning "IAM user '$user': Unable to check MFA status"
            fi
        done
        
        if [[ "$users_without_mfa" -gt 0 ]]; then
            log_warning "Found $users_without_mfa IAM users without MFA"
        fi
    else
        log_warning "Unable to list IAM users"
    fi
}

# Function to check CloudTrail status
check_cloudtrail_status() {
    log_info "Checking CloudTrail status..."
    increment_total
    
    local trails
    if trails=$(aws cloudtrail describe-trails 2>/dev/null); then
        local trail_count=$(echo "$trails" | jq -r '.trailList | length')
        
        if [[ "$trail_count" -gt 0 ]]; then
            local active_trails=0
            local multi_region_trails=0
            
            for ((i=0; i<trail_count; i++)); do
                local trail_name=$(echo "$trails" | jq -r ".trailList[$i].Name")
                local is_multi_region=$(echo "$trails" | jq -r ".trailList[$i].IsMultiRegionTrail")
                
                # Check if trail is logging
                local status=$(aws cloudtrail get-trail-status --name "$trail_name" 2>/dev/null)
                local is_logging=$(echo "$status" | jq -r '.IsLogging')
                
                if [[ "$is_logging" == "true" ]]; then
                    ((active_trails++))
                fi
                
                if [[ "$is_multi_region" == "true" ]]; then
                    ((multi_region_trails++))
                fi
            done
            
            if [[ "$active_trails" -gt 0 ]]; then
                log_success "CloudTrail: $active_trails active trails found"
            else
                log_error "CloudTrail: No active trails found"
            fi
            
            if [[ "$multi_region_trails" -gt 0 ]]; then
                log_success "CloudTrail: Multi-region logging enabled"
            else
                log_warning "CloudTrail: No multi-region trails configured"
            fi
        else
            log_error "CloudTrail: No trails configured"
        fi
    else
        log_error "Unable to check CloudTrail status"
    fi
}

# Function to check unused access keys
check_unused_access_keys() {
    log_info "Checking for unused access keys..."
    
    local users
    if users=$(aws iam list-users --query 'Users[].UserName' --output text 2>/dev/null); then
        local old_keys_count=0
        
        for user in $users; do
            local access_keys
            if access_keys=$(aws iam list-access-keys --user-name "$user" 2>/dev/null); then
                local key_count=$(echo "$access_keys" | jq -r '.AccessKeyMetadata | length')
                
                for ((i=0; i<key_count; i++)); do
                    increment_total
                    local access_key_id=$(echo "$access_keys" | jq -r ".AccessKeyMetadata[$i].AccessKeyId")
                    local create_date=$(echo "$access_keys" | jq -r ".AccessKeyMetadata[$i].CreateDate")
                    
                    # Check last used
                    local last_used
                    if last_used=$(aws iam get-access-key-last-used --access-key-id "$access_key_id" 2>/dev/null); then
                        local last_used_date=$(echo "$last_used" | jq -r '.AccessKeyLastUsed.LastUsedDate // "never"')
                        
                        if [[ "$last_used_date" == "never" ]]; then
                            log_warning "Access key '$access_key_id' for user '$user': Never used"
                            ((old_keys_count++))
                        else
                            # Check if key is older than 90 days
                            local last_used_epoch=$(date -d "$last_used_date" +%s 2>/dev/null || echo 0)
                            local ninety_days_ago=$(($(date +%s) - 7776000))
                            
                            if [[ "$last_used_epoch" -lt "$ninety_days_ago" ]]; then
                                log_warning "Access key '$access_key_id' for user '$user': Not used in 90+ days (last used: $last_used_date)"
                                ((old_keys_count++))
                            else
                                log_success "Access key '$access_key_id' for user '$user': Recently used"
                            fi
                        fi
                    fi
                done
            fi
        done
        
        if [[ "$old_keys_count" -eq 0 ]]; then
            log_info "All access keys are actively used"
        else
            log_warning "Found $old_keys_count potentially unused access keys"
        fi
    else
        log_warning "Unable to check access keys"
    fi
}

# Function to display validation summary
display_summary() {
    echo ""
    echo "============================================="
    echo "Security Policies Validation Summary"
    echo "============================================="
    echo "Total Checks Performed: $TOTAL_CHECKS"
    echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
    echo -e "${YELLOW}Warnings: $WARNING_CHECKS${NC}"
    echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
    echo ""
    
    local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    echo "Success Rate: $success_rate%"
    echo ""
    
    if [[ "$FAILED_CHECKS" -eq 0 ]]; then
        if [[ "$WARNING_CHECKS" -eq 0 ]]; then
            log_success "Excellent! All security checks passed."
        else
            log_warning "Good! All critical checks passed, but some warnings need attention."
        fi
    else
        log_error "Security issues found. Please address the failed checks immediately."
    fi
    
    echo ""
    echo "Recommendations:"
    echo "1. Address all failed security checks immediately"
    echo "2. Review warnings and implement improvements"
    echo "3. Set up automated monitoring for continuous compliance"
    echo "4. Regularly run security validation checks"
    echo "5. Consider implementing automated remediation"
}

# Main execution function
main() {
    log_info "Starting Security Policies Validation for Account: $ACCOUNT_ID"
    log_info "Region: $AWS_REGION"
    echo ""
    
    # Perform security checks
    check_password_policy
    check_root_access_keys
    check_root_mfa
    check_guardduty_status
    check_security_hub_status
    check_config_status
    check_config_rules_compliance
    check_s3_bucket_security
    check_ec2_security_groups
    check_iam_users_mfa
    check_cloudtrail_status
    check_unused_access_keys
    
    # Display summary
    display_summary
}

# Script options
case "${1:-}" in
    --help|-h)
        echo "AWS Security Policies Validation Script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Environment Variables:"
        echo "  PROJECT_NAME    Project name (default: devops-security)"
        echo "  ENVIRONMENT     Environment (default: production)"
        echo "  AWS_REGION      AWS region (default: us-east-1)"
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        echo "  --summary-only  Show only the final summary"
        echo ""
        echo "This script validates:"
        echo "- Account password policy"
        echo "- Root account security"
        echo "- AWS security services status"
        echo "- Config rules compliance"
        echo "- S3 bucket security"
        echo "- EC2 security groups"
        echo "- IAM user MFA status"
        echo "- CloudTrail configuration"
        echo "- Access key usage"
        exit 0
        ;;
    --summary-only)
        main | grep -E "(\[PASS\]|\[FAIL\]|\[WARN\]|Summary|Recommendations|Total Checks|Success Rate)"
        ;;
    *)
        main
        ;;
esac