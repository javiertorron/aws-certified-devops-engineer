#!/usr/bin/env python3
"""
Git Workflow Automation Script for AWS CodeCommit
This script automates common Git workflows for source code management

Features:
- Automated feature branch creation
- Pull request creation
- Branch cleanup
- Repository health checks
- Integration with AWS CodeCommit
"""

import os
import sys
import argparse
import subprocess
import json
import boto3
from datetime import datetime, timedelta
from typing import List, Dict, Optional
import re

class GitWorkflowAutomator:
    def __init__(self, repository_name: str = None):
        self.repository_name = repository_name
        self.codecommit = boto3.client('codecommit')
        self.current_branch = self._get_current_branch()
        
    def _get_current_branch(self) -> str:
        """Get the current Git branch name"""
        try:
            result = subprocess.run(
                ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return 'main'
    
    def _run_git_command(self, command: List[str]) -> subprocess.CompletedProcess:
        """Execute a Git command and return the result"""
        try:
            result = subprocess.run(
                ['git'] + command,
                capture_output=True,
                text=True,
                check=True
            )
            return result
        except subprocess.CalledProcessError as e:
            print(f"Git command failed: {e.cmd}")
            print(f"Error: {e.stderr}")
            sys.exit(1)
    
    def _run_aws_command(self, service: str, command: str, **kwargs) -> Dict:
        """Execute an AWS CLI command"""
        try:
            client = boto3.client(service)
            method = getattr(client, command)
            return method(**kwargs)
        except Exception as e:
            print(f"AWS command failed: {e}")
            sys.exit(1)
    
    def create_feature_branch(self, feature_name: str, base_branch: str = 'main') -> None:
        """Create a new feature branch from base branch"""
        print(f"Creating feature branch: feature/{feature_name}")
        
        # Ensure we're on the base branch and it's up to date
        self._run_git_command(['checkout', base_branch])
        self._run_git_command(['pull', 'origin', base_branch])
        
        # Create and checkout new feature branch
        branch_name = f"feature/{feature_name}"
        self._run_git_command(['checkout', '-b', branch_name])
        
        # Push branch to remote
        self._run_git_command(['push', '-u', 'origin', branch_name])
        
        print(f"✅ Feature branch '{branch_name}' created and pushed to remote")
        print(f"🚀 You can now start working on your feature!")
    
    def create_hotfix_branch(self, hotfix_name: str, base_branch: str = 'main') -> None:
        """Create a hotfix branch for critical fixes"""
        print(f"Creating hotfix branch: hotfix/{hotfix_name}")
        
        # Ensure we're on the base branch and it's up to date
        self._run_git_command(['checkout', base_branch])
        self._run_git_command(['pull', 'origin', base_branch])
        
        # Create and checkout new hotfix branch
        branch_name = f"hotfix/{hotfix_name}"
        self._run_git_command(['checkout', '-b', branch_name])
        
        # Push branch to remote
        self._run_git_command(['push', '-u', 'origin', branch_name])
        
        print(f"🔥 Hotfix branch '{branch_name}' created and pushed to remote")
    
    def finish_feature(self, feature_name: str, target_branch: str = 'main') -> None:
        """Finish a feature branch by creating a pull request"""
        branch_name = f"feature/{feature_name}"
        
        print(f"Finishing feature branch: {branch_name}")
        
        # Ensure we're on the feature branch
        self._run_git_command(['checkout', branch_name])
        
        # Push any remaining changes
        self._run_git_command(['push', 'origin', branch_name])
        
        if self.repository_name:
            self._create_pull_request(branch_name, target_branch, feature_name)
        else:
            print("⚠️  Repository name not provided. Cannot create pull request automatically.")
            print(f"Please create a pull request manually from {branch_name} to {target_branch}")
    
    def _create_pull_request(self, source_branch: str, target_branch: str, title: str) -> None:
        """Create a pull request in CodeCommit"""
        try:
            response = self.codecommit.create_pull_request(
                title=f"Feature: {title}",
                description=f"""
## Description
{title}

## Type of Change
- [ ] Bug fix
- [x] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No sensitive data exposed
                """.strip(),
                targets=[
                    {
                        'repositoryName': self.repository_name,
                        'sourceReference': f'refs/heads/{source_branch}',
                        'destinationReference': f'refs/heads/{target_branch}'
                    }
                ]
            )
            
            pull_request_id = response['pullRequest']['pullRequestId']
            print(f"✅ Pull request created successfully!")
            print(f"🔗 Pull Request ID: {pull_request_id}")
            
        except Exception as e:
            print(f"❌ Failed to create pull request: {e}")
    
    def clean_merged_branches(self, dry_run: bool = True) -> None:
        """Clean up merged branches"""
        print("🧹 Cleaning up merged branches...")
        
        # Get list of merged branches
        result = self._run_git_command(['branch', '--merged', 'main'])
        merged_branches = [
            branch.strip() 
            for branch in result.stdout.split('\n') 
            if branch.strip() and not branch.strip().startswith('*') and 'main' not in branch
        ]
        
        if not merged_branches:
            print("✅ No merged branches to clean up")
            return
        
        print(f"Found {len(merged_branches)} merged branches:")
        for branch in merged_branches:
            print(f"  - {branch}")
        
        if dry_run:
            print("🔍 This is a dry run. Use --no-dry-run to actually delete branches.")
            return
        
        # Delete local branches
        for branch in merged_branches:
            try:
                self._run_git_command(['branch', '-d', branch])
                print(f"✅ Deleted local branch: {branch}")
            except:
                print(f"⚠️  Could not delete local branch: {branch}")
        
        # Delete remote branches
        for branch in merged_branches:
            try:
                self._run_git_command(['push', 'origin', '--delete', branch])
                print(f"✅ Deleted remote branch: {branch}")
            except:
                print(f"⚠️  Could not delete remote branch: {branch}")
    
    def repository_health_check(self) -> Dict:
        """Perform repository health check"""
        print("🏥 Performing repository health check...")
        
        health_report = {
            'status': 'healthy',
            'issues': [],
            'recommendations': [],
            'metrics': {}
        }
        
        # Check for uncommitted changes
        result = self._run_git_command(['status', '--porcelain'])
        if result.stdout.strip():
            health_report['issues'].append("Uncommitted changes detected")
            health_report['status'] = 'warning'
        
        # Check for unpushed commits
        try:
            result = self._run_git_command(['log', 'origin/main..HEAD', '--oneline'])
            unpushed_commits = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
            health_report['metrics']['unpushed_commits'] = unpushed_commits
            
            if unpushed_commits > 0:
                health_report['issues'].append(f"{unpushed_commits} unpushed commits on current branch")
                health_report['status'] = 'warning'
        except:
            pass
        
        # Check branch age
        try:
            result = self._run_git_command(['show', '-s', '--format=%ci', 'HEAD'])
            last_commit_date = datetime.fromisoformat(result.stdout.strip().replace(' +', '+'))
            days_since_commit = (datetime.now() - last_commit_date.replace(tzinfo=None)).days
            health_report['metrics']['days_since_last_commit'] = days_since_commit
            
            if days_since_commit > 30:
                health_report['recommendations'].append("Consider making more frequent commits")
        except:
            pass
        
        # Check for large files
        try:
            result = self._run_git_command(['ls-files', '-s'])
            large_files = []
            for line in result.stdout.split('\n'):
                if line:
                    parts = line.split('\t')
                    if len(parts) >= 2:
                        size = int(parts[0].split()[3])
                        filename = parts[1]
                        if size > 10 * 1024 * 1024:  # 10MB
                            large_files.append((filename, size))
            
            if large_files:
                health_report['issues'].append(f"{len(large_files)} large files detected")
                health_report['recommendations'].append("Consider using Git LFS for large files")
                health_report['metrics']['large_files'] = large_files
        except:
            pass
        
        # Report results
        print(f"📊 Repository Status: {health_report['status'].upper()}")
        
        if health_report['issues']:
            print("⚠️  Issues found:")
            for issue in health_report['issues']:
                print(f"   - {issue}")
        
        if health_report['recommendations']:
            print("💡 Recommendations:")
            for rec in health_report['recommendations']:
                print(f"   - {rec}")
        
        if health_report['metrics']:
            print("📈 Metrics:")
            for key, value in health_report['metrics'].items():
                if key == 'large_files':
                    print(f"   - {key}: {len(value)} files")
                else:
                    print(f"   - {key}: {value}")
        
        return health_report
    
    def sync_with_remote(self, branch: str = None) -> None:
        """Sync current branch with remote"""
        if not branch:
            branch = self.current_branch
        
        print(f"🔄 Syncing {branch} with remote...")
        
        # Fetch latest changes
        self._run_git_command(['fetch', 'origin'])
        
        # Check if remote branch exists
        try:
            self._run_git_command(['rev-parse', f'origin/{branch}'])
            
            # Pull changes
            self._run_git_command(['pull', 'origin', branch])
            print(f"✅ {branch} synced with remote")
            
        except:
            print(f"⚠️  Remote branch origin/{branch} doesn't exist")
            print("Creating remote branch...")
            self._run_git_command(['push', '-u', 'origin', branch])
            print(f"✅ Remote branch created and synced")
    
    def create_release_branch(self, version: str, base_branch: str = 'main') -> None:
        """Create a release branch"""
        print(f"Creating release branch: release/{version}")
        
        # Validate version format (semantic versioning)
        if not re.match(r'^\d+\.\d+\.\d+$', version):
            print("❌ Version must follow semantic versioning format (x.y.z)")
            return
        
        # Ensure we're on the base branch and it's up to date
        self._run_git_command(['checkout', base_branch])
        self._run_git_command(['pull', 'origin', base_branch])
        
        # Create and checkout new release branch
        branch_name = f"release/{version}"
        self._run_git_command(['checkout', '-b', branch_name])
        
        # Update version in files (if version file exists)
        version_files = ['version.txt', 'VERSION', 'package.json']
        for version_file in version_files:
            if os.path.exists(version_file):
                print(f"Updating version in {version_file}")
                # This is a simplified version update
                # In practice, you'd want more sophisticated version updating
                if version_file == 'package.json':
                    self._update_package_json_version(version)
                else:
                    with open(version_file, 'w') as f:
                        f.write(version + '\n')
        
        # Commit version update
        self._run_git_command(['add', '.'])
        self._run_git_command(['commit', '-m', f"Bump version to {version}"])
        
        # Push branch to remote
        self._run_git_command(['push', '-u', 'origin', branch_name])
        
        print(f"🚀 Release branch '{branch_name}' created and pushed to remote")
    
    def _update_package_json_version(self, version: str) -> None:
        """Update version in package.json"""
        try:
            with open('package.json', 'r') as f:
                data = json.load(f)
            
            data['version'] = version
            
            with open('package.json', 'w') as f:
                json.dump(data, f, indent=2)
                
        except Exception as e:
            print(f"⚠️  Could not update package.json: {e}")


def main():
    parser = argparse.ArgumentParser(description='Git Workflow Automation for AWS CodeCommit')
    parser.add_argument('--repository', '-r', help='CodeCommit repository name')
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Feature branch commands
    feature_parser = subparsers.add_parser('feature', help='Feature branch operations')
    feature_subparsers = feature_parser.add_subparsers(dest='feature_action')
    
    start_parser = feature_subparsers.add_parser('start', help='Start a new feature')
    start_parser.add_argument('name', help='Feature name')
    start_parser.add_argument('--base', default='main', help='Base branch (default: main)')
    
    finish_parser = feature_subparsers.add_parser('finish', help='Finish a feature')
    finish_parser.add_argument('name', help='Feature name')
    finish_parser.add_argument('--target', default='main', help='Target branch (default: main)')
    
    # Hotfix commands
    hotfix_parser = subparsers.add_parser('hotfix', help='Create hotfix branch')
    hotfix_parser.add_argument('name', help='Hotfix name')
    hotfix_parser.add_argument('--base', default='main', help='Base branch (default: main)')
    
    # Release commands
    release_parser = subparsers.add_parser('release', help='Create release branch')
    release_parser.add_argument('version', help='Release version (semantic versioning)')
    release_parser.add_argument('--base', default='main', help='Base branch (default: main)')
    
    # Cleanup commands
    cleanup_parser = subparsers.add_parser('cleanup', help='Clean merged branches')
    cleanup_parser.add_argument('--dry-run', action='store_true', default=True, 
                               help='Show what would be deleted (default)')
    cleanup_parser.add_argument('--no-dry-run', action='store_true', 
                               help='Actually delete branches')
    
    # Health check
    subparsers.add_parser('health', help='Repository health check')
    
    # Sync commands
    sync_parser = subparsers.add_parser('sync', help='Sync with remote')
    sync_parser.add_argument('--branch', help='Branch to sync (default: current)')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    automator = GitWorkflowAutomator(args.repository)
    
    try:
        if args.command == 'feature':
            if args.feature_action == 'start':
                automator.create_feature_branch(args.name, args.base)
            elif args.feature_action == 'finish':
                automator.finish_feature(args.name, args.target)
        
        elif args.command == 'hotfix':
            automator.create_hotfix_branch(args.name, args.base)
        
        elif args.command == 'release':
            automator.create_release_branch(args.version, args.base)
        
        elif args.command == 'cleanup':
            dry_run = not args.no_dry_run
            automator.clean_merged_branches(dry_run)
        
        elif args.command == 'health':
            automator.repository_health_check()
        
        elif args.command == 'sync':
            automator.sync_with_remote(args.branch)
            
    except KeyboardInterrupt:
        print("\n🛑 Operation cancelled by user")
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()