# c-sync: AWS S3 Backup and Sync Utility

A command-line utility for backing up and syncing files with AWS S3.

## Prerequisites

1. AWS CLI installed and configured with your credentials
2. AWS S3 bucket created
3. Proper AWS permissions set up for your user

## Installation

1. Clone the repository:
```bash
git clone https://github.com/sergei-doroshenko/c-sync
cd c-sync
```

2. Create your configuration file:
```bash
cp config.env.example config.env
```

3. Edit config.env and set your configuration:
- `BACKUP_BUCKET`: Your S3 bucket name
- `PROFILE`: Your AWS CLI profile name
- `PATHTOREMOVE`: Base path to remove from local paths when creating S3 paths

Note: The config.env file must be in the same directory as the script.

4. Create a symbolic link to make the script globally available:
```bash
sudo ln -s $(pwd)/csync.sh /usr/local/bin/c-sync
```

You should see output similar to:
```
lrwxr-xr-x 1 root wheel 59 Jul 13 2024 c-sync -> /path/to/c-sync/csync.sh
```

## Usage

### Basic Commands

```bash
c-sync <command> [path]
```

Available commands:
- `bu [path]` - Backup a file or directory to S3
- `sync [path]` - Sync cloud files with local copy
- `ls [path]` - List cloud directories
- `h` - Show help message

If no path is provided, the current directory will be used.

### Examples

1. Backup a file:
```bash
c-sync bu document.txt
```

2. Backup a directory:
```bash
c-sync bu Documents/
```

3. Sync a directory with S3:
```bash
c-sync sync Photos/
```

4. List contents of a directory in S3:
```bash
c-sync ls Videos/
```

5. Show help:
```bash
c-sync h
```

### Path Handling

The utility supports different types of paths:
- Relative paths: `Documents/Photos/`
- Absolute paths: `/Users/username/Documents/`
- Home directory paths: `~/Documents/`
- Current directory: just run command without path

## Example Output

Here's an example of backing up a directory:

```bash
➜ c-sync bu Videos/Holidays/
aws-cli/2.17.55 Python/3.12.6 Darwin/24.3.0 exe/x86_64
Starting backup of: Videos/Holidays/
Current directory: /Users/username/Documents
S3 destination: s3://my-backup-bucket/Documents/Videos/Holidays/
Videos/Holidays/ is a directory
upload: Videos/Holidays/video1.mov to s3://my-backup-bucket/Documents/Videos/Holidays/video1.mov
upload: Videos/Holidays/video2.mov to s3://my-backup-bucket/Documents/Videos/Holidays/video2.mov
```

## Notes

- The script uses your current AWS profile configuration
- S3 paths are automatically generated based on your local path structure
- Sync command uses AWS S3 sync for directories and cp for single files
- All commands support both files and directories
