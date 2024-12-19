import subprocess
import re
import os

# ANSI escape codes for colors
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"

# Function to run a command and return the output
def run_command(command, verbose=False):
    if verbose:
        print(f"Running command: {command}")
    try:
        result = subprocess.run(command, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"{RED}Error running command '{command}': {e.stderr}{RESET}"

# Function to parse the output of ifconfig to extract device names and IP addresses
def parse_ifconfig(output):
    interfaces = []
    pattern = re.compile(r'(\S+): flags.*\n.*inet (\d+\.\d+\.\d+\.\d+)', re.MULTILINE)

    for match in pattern.findall(output):
        interface_name, ip_address = match
        interfaces.append(f"Device: {interface_name}, IP: {ip_address}")
    
    return interfaces

# Function to calculate total storage from df -h output
def calculate_total_storage(output):
    total_size = 0.0
    for line in output.splitlines()[1:]:
        try:
            size = line.split()[1]
            if 'G' in size:
                total_size += float(size.strip('G'))
            elif 'T' in size:
                total_size += float(size.strip('T')) * 1024  # Convert TB to GB
            elif 'M' in size:
                total_size += float(size.strip('M')) / 1024  # Convert MB to GB
        except (IndexError, ValueError):
            continue
    return total_size

# Function to get root directory storage from df -h output
def get_root_storage(output):
    for line in output.splitlines():
        if line.endswith(" /"):
            return line
    return "Root directory not found."

# Function to check telnet connection status
def check_telnet_connection(host, port, server_type, verbose=False):
    command = f"echo '' | telnet {host} {port}"
    if verbose:
        print(f"Running Telnet check: {command}")
    try:
        result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=20)
        if "Connected" in result.stdout or "Escape character" in result.stdout:
            return f"{GREEN}Connected to {server_type} ({host}:{port}){RESET}"
        else:
            return f"{RED}Connection to {server_type} ({host}:{port}) failed{RESET}"
    except subprocess.CalledProcessError:
        return f"{RED}Connection to {server_type} ({host}:{port}) failed{RESET}"
    except subprocess.TimeoutExpired:
        return f"{RED}Connection to {server_type} ({host}:{port}) timed out{RESET}"

# Function to get total memory size from free -h output
def get_total_memory(output):
    for line in output.splitlines():
        if "Mem:" in line:
            return line.split()[1]
    return "Memory information not found."

# Function to get unique rota values from lsblk output
def get_unique_rota_values(output):
    rota_values = set()
    for line in output.splitlines()[1:]:
        parts = line.split()
        if parts:
            rota_values.add(parts[1])
    return rota_values

# Function to run wget and check success or failure with a 15-second timeout
def run_wget(link, verbose=False):
    if verbose:
        print(f"Running wget: {link}")
    try:
        # Adding --timeout=15 for a 15-second timeout
        result = subprocess.run(f"wget -q --spider --timeout=15 {link}", shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return f"{GREEN}Successfully reached: {link}{RESET}"
    except subprocess.CalledProcessError as e:
        return f"{RED}Failed to reach: {link}. Error: {e.stderr}{RESET}"

# Function to check and install 'policycoreutils' if sestatus is missing
def check_and_install_policycoreutils(verbose=False):
    result = subprocess.run("which sestatus", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    
    if result.returncode != 0:
        if verbose:
            print(f"sestatus command not found. Installing policycoreutils...")
        install_output = run_command("sudo apt install policycoreutils -y", verbose)
        if verbose:
            print(install_output)
        return run_command("sestatus", verbose)
    else:
        return run_command("sestatus", verbose)

# Function to check status output and color it based on active or inactive/failed/disabled status
def check_status(output):
    if any(state in output for state in ["inactive", "failed", "disabled"]):
        return f"{RED}{output}{RESET}"
    else:
        return f"{GREEN}{output}{RESET}"

# Function to check if ping to a host is successful
def check_ping(host, verbose=False):
    if verbose:
        print(f"Pinging {host}...")
    try:
        result = subprocess.run(f"ping -c 1 -W 15 {host}", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if "1 packets transmitted, 1 received" in result.stdout:
            return f"{GREEN}Ping to {host} successful{RESET}"
        else:
            return f"{RED}Ping to {host} failed{RESET}"
    except subprocess.TimeoutExpired:
        return f"{RED}Ping to {host} timed out{RESET}"

# Ask for Core, Adapter, and DN IPs
core_ip = input("Please enter the Core IP: ")
adapter_ip = input("Please enter the Adapter IP: ")
dn_ip = input("Please enter the DN IP: ")

# List of Telnet ports to check
telnet_ports = [1443, 8086, 7426, 8765]

# Get the current hostname (hostam)
hostname = subprocess.getoutput("hostname")

# List of commands to run (excluding ifconfig and df -h, which are handled separately)
commands = [
    "hostname",
    "nproc",
    "timedatectl",
    "hostnamectl || cat /etc/os-release",
    "umask",
    "python3 --version",
    "env | grep -i proxy || cat /etc/environment"
]

# List of links to download
links = [
    "http://www.docker.com",
    "https://www.docker.io",
    "http://download.docker.com",
    "https://raw.githubusercontent.com",
    "https://www.github.com",
    "https://registry-1.docker.io",
    "http://archive.ubuntu.com"
]

# Get the current directory path
current_directory = os.getcwd()

# Output file in the current directory
output_file = os.path.join(current_directory, "system_status.txt")
verbose = True  # Set to True to enable verbose logging

with open(output_file, "w") as file:
    # 1. Special handling for ifconfig to show only device name and IP address
    file.write(f"{YELLOW}Running command: ifconfig{RESET}\n")
    ifconfig_output = run_command("ifconfig", verbose)
    parsed_ifconfig = parse_ifconfig(ifconfig_output)

    file.write("Network Interfaces and IP Addresses:\n")
    for interface in parsed_ifconfig:
        file.write(interface + "\n")
    file.write("-" * 50 + "\n")

    # 2. First df -h command: Total storage
    file.write(f"{YELLOW}Running command: df -h (Total Storage){RESET}\n")
    df_output = run_command("df -h", verbose)
    total_storage = calculate_total_storage(df_output)
    file.write(f"Total Storage: {total_storage:.2f} GB\n")
    file.write("-" * 50 + "\n")

    # 3. Second df -h command: Root directory storage
    file.write(f"{YELLOW}Running command: df -h (Root Directory){RESET}\n")
    root_storage = get_root_storage(df_output)
    file.write("Root Directory Storage:\n" + root_storage + "\n")
    file.write("-" * 50 + "\n")

    # 4. Get total memory size
    file.write(f"{YELLOW}Running command: free -h (Total Memory){RESET}\n")
    free_output = run_command("free -h", verbose)
    total_memory = get_total_memory(free_output)
    file.write(f"Total Memory: {total_memory}\n")
    file.write("-" * 50 + "\n")

    # 5. Get unique rota values from lsblk
    file.write(f"{YELLOW}Running command: lsblk -d -o name,rota{RESET}\n")
    lsblk_output = run_command("lsblk -d -o name,rota", verbose)
    unique_rota_values = get_unique_rota_values(lsblk_output)
    file.write("Unique Rota Values (1 = HDD, 0 = SSD):\n")
    for rota in unique_rota_values:
        file.write(f"{rota}\n")
    file.write("-" * 50 + "\n")

    # 6. Running other commands
    for cmd in commands:
        file.write(f"{YELLOW}Running command: {cmd}{RESET}\n")
        result = run_command(cmd, verbose)
        file.write(result + "\n")
        file.write("-" * 50 + "\n")

    # 7. Check UFW status
    file.write(f"{YELLOW}Checking UFW status{RESET}\n")
    ufw_output = run_command("ufw status", verbose)
    colored_ufw_output = check_status(ufw_output)
    file.write(f"UFW Status:\n{colored_ufw_output}\n")
    file.write("-" * 50 + "\n")

    # 8. Check telnet connections for core, adapter, and dn IPs
    for ip in [core_ip, adapter_ip, dn_ip]:
        for port in telnet_ports:
            file.write(f"Checking Telnet Connection for {ip}:{port}\n")
            telnet_result = check_telnet_connection(ip, port, "Core" if ip == core_ip else "Adapter" if ip == adapter_ip else "DN", verbose)
            file.write(telnet_result + "\n")
            file.write("-" * 50 + "\n")

    # 9. Check wget for several links
    for link in links:
        wget_result = run_wget(link, verbose)
        file.write(wget_result + "\n")
        file.write("-" * 50 + "\n")

    # 10. Check ping to specified hosts
    file.write(f"{YELLOW}Pinging host: {core_ip}{RESET}\n")
    ping_result = check_ping(core_ip, verbose)
    file.write(ping_result + "\n")
    file.write("-" * 50 + "\n")

    # 11. Check and install policycoreutils if needed
    file.write(f"{YELLOW}Checking and installing policycoreutils (if needed){RESET}\n")
    policycoreutils_result = check_and_install_policycoreutils(verbose)
    file.write(policycoreutils_result + "\n")
    file.write("-" * 50 + "\n")

file.write(f"\n{GREEN}System Status Report Generated Successfully!{RESET}\n")
print(f"System status report has been saved to {output_file}")

