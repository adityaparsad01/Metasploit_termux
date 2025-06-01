# Metasploit Framework for Termux

This repository provides a robust script to install and set up the Metasploit Framework on Termux, optimized for compatibility with modern Android versions and Ruby environments (specifically Ruby 3.4+).

The installation script (`metasploit.sh`) now includes automatic patches to address common dependency conflicts, Ruby version incompatibilities, and database setup issues that often arise when installing Metasploit on Termux.

## Installation Steps

Follow these steps to install Metasploit Framework on your Termux environment:

### 1. Initial Termux Setup

Ensure your Termux environment is up-to-date and has necessary permissions:

```bash
# Update and upgrade Termux packages
pkg update -y && pkg upgrade -y

# Grant Termux storage permissions (allow when prompted)
termux-setup-storage
