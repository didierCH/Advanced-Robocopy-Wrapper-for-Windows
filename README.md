# Advanced Robocopy Wrapper for Windows

## Description

Copy-Script to copy publishing data for BirsForum Medien GmbH from a Windows Server to a Synology NAS for archiving purposes.

An advanced PowerShell wrapper for Robocopy, this script performs robust directory migrations on Windows. It automates file ownership and permission management, generates comprehensive logs, and provides detailed reports on file size and count, all within a guided, interactive user experience.

This PowerShell script facilitates the migration of directories, including ownership and permission management, while providing detailed logging and validation. It is designed for administrators and requires elevated privileges to execute.

---

## Key Features

- **Administrator Check**: Ensures the script is run with administrator privileges.
- **Non-Empty Destination Safeguard**: Because Robocopy runs with `/MIR` (a full mirror), anything in the destination that does not exist in the source is deleted. If the destination already exists and is not empty, the script warns the user and requires explicit confirmation before proceeding.
- **Directory Size Calculation**: Calculates and formats the size of the source and destination directories for comparison.
- **Ownership and Permission Management (Optional)**:
  - Changes ownership of the source directory to the current administrator.
  - Resets permissions to inherit from the parent directory.
- **Robocopy Integration**:
  - Uses Robocopy to copy files and directories with options for mirroring, retries, and logging.
  - Logs the Robocopy operation to a separate file.
- **Post-Copy Validation**:
  - Compares directory sizes and file counts between the source and destination.
  - Identifies missing or extra files and lists differences.
- **Detailed Logging**:
  - Generates a main log file summarizing the migration process.
  - Includes timestamps, directory sizes, file counts, and Robocopy status.

---

## Workflow

1. **Input Paths**:
   - Prompts the user for the source and destination paths.
   - Validates the existence of the paths.
   - If the destination path already exists and is not empty, prompts the user: *"The destination path is not empty. Do you really want to proceed? Everything in the directory will be deleted."* (Yes/No). Choosing No cancels the operation before any changes are made.
2. **Ownership and Permissions (Optional)**:
   - If enabled, modifies ownership and permissions of the source directory.
3. **Directory Size Calculation**:
   - Calculates the size of the source directory before copying.
4. **File Copying**:
   - Executes Robocopy to copy files and directories.
   - Logs the operation and interprets the Robocopy exit code.
5. **Post-Copy Validation**:
   - Compares directory sizes and file counts.
   - Lists differences in file presence between the source and destination.
6. **Logging**:
   - Saves a detailed log of the migration process and Robocopy output.

---

## Usage

1. Run the script as an administrator.
2. Follow the prompts to provide the source and destination paths.
3. Choose whether to modify ownership and permissions.
4. Review the logs generated in the destination's parent directory for details.

---

## Logs

- **Main Log**: Summarizes the migration process, including size and file count comparisons.
- **Robocopy Log**: Contains detailed output from the Robocopy operation.

---

This script is ideal for administrators managing directory migrations with robust validation and logging requirements.