import subprocess
import platform
import os


def get_linux_distribution():
    """
    Detects the Linux distribution name and version.

    Returns:
        tuple: (distro_name, distro_version)
               Returns (None, None) if not Linux or detection fails.
    """
    try:
        if platform.system() != "Linux":
            return None, None

        # Use distro module if available (more reliable)
        try:
            import distro

            distro_name = distro.name(pretty=True).strip()  # Get the pretty name
            distro_version = distro.version()
            return distro_name, distro_version
        except ImportError:
            # Fallback to /etc/os-release (standard on modern systems)
            if os.path.exists("/etc/os-release"):
                with open("/etc/os-release", "r", encoding="utf-8") as f:
                    content = f.read()
                    name_line = next(
                        (
                            line
                            for line in content.splitlines()
                            if line.startswith("PRETTY_NAME=")
                        ),
                        None,
                    )
                    version_id_line = next(
                        (
                            line
                            for line in content.splitlines()
                            if line.startswith("VERSION_ID=")
                        ),
                        None,
                    )
                    if name_line:
                        distro_name = name_line.split("=", 1)[1].strip().strip('"')
                    else:
                        distro_name = None
                    if version_id_line:
                        distro_version = (
                            version_id_line.split("=", 1)[1].strip().strip('"')
                        )
                    else:
                        distro_version = None
                    if distro_name:
                        return distro_name, distro_version
            # Fallback to lsb_release (less reliable, may not be installed)
            try:
                result = subprocess.run(
                    ["lsb_release", "-a"], capture_output=True, text=True, check=True
                )
                output_lines = result.stdout.splitlines()
                distro_name_line = next(
                    (
                        line
                        for line in output_lines
                        if line.startswith("Distributor ID:")
                    ),
                    None,
                )
                distro_version_line = next(
                    (line for line in output_lines if line.startswith("Release:")), None
                )

                if distro_name_line:
                    distro_name = distro_name_line.split(":", 1)[1].strip()
                else:
                    distro_name = None
                if distro_version_line:
                    distro_version = distro_version_line.split(":", 1)[1].strip()
                else:
                    distro_version = None
                if distro_name:
                    return distro_name, distro_version
            except FileNotFoundError:
                pass  # lsb_release not found, continue to the next method

            # Fallback to platform.linux_distribution() (deprecated in Python 3.8, unreliable)
            try:
                distro_name, distro_version, _ = platform.linux_distribution()
                distro_name = distro_name.strip()
                distro_version = distro_version.strip()
                if distro_name:
                    return distro_name, distro_version
            except AttributeError:
                pass  # platform.linux_distribution doesn't exist

        return None, None  # If all methods fail

    except Exception as e:
        print(f"Error detecting distribution: {e}")
        return None, None


def get_package_manager(distro_name):
    """
    Returns the package manager for a given distribution.

    Args:
        distro_name (str): The name of the Linux distribution.

    Returns:
        str: The package manager, or None if not found.
    """
    if not distro_name:
        return None

    distro_name = distro_name.lower()

    # Common distributions and their package managers
    package_managers = {
        "ubuntu": "apt",
        "debian": "apt",
        "fedora": "dnf",
        "centos": "dnf",  # or yum, but dnf is preferred for newer versions
        "red hat enterprise linux": "dnf",  # or yum
        "arch": "pacman",
        "archcraft": "pacman",
        "manjaro": "pacman",
        "opensuse": "zypper",
        "suse linux enterprise server": "zypper",
        "gentoo": "emerge",
        "alpine": "apk",
        "linux mint": "apt",
        "elementary os": "apt",
        "pop!_os": "apt",
        "kali linux": "apt",
        "mageia": "urpmi",
        "slackware": "pkgtool",
        "void": "xbps",
        "amazon linux": "yum",  # including Amazon Linux 2
        "rocky linux": "dnf",
        "alma linux": "dnf",
    }

    # Check for exact match
    if distro_name in package_managers:
        return package_managers[distro_name]

    # Handle distributions based on others (more robust matching)
    if "debian" in distro_name:
        return "apt"
    elif "ubuntu" in distro_name:
        return "apt"
    elif "fedora" in distro_name:
        return "dnf"
    elif "centos" in distro_name or "rhel" in distro_name or "red hat" in distro_name:
        return "dnf"  #  Use dnf as the default for modern Red Hat-based
    elif "arch" in distro_name or "archcraft" in distro_name:
        return "pacman"
    elif "opensuse" in distro_name or "suse" in distro_name:
        return "zypper"
    elif "mint" in distro_name:
        return "apt"
    elif "elementary" in distro_name:
        return "apt"
    elif "pop!_os" in distro_name:
        return "apt"
    elif "kali" in distro_name:
        return "apt"
    elif "amazon" in distro_name:
        return "yum"

    return None  # Unknown distribution


def main():
    """
    Main function to detect the distribution and package manager.
    """
    distro_name, distro_version = get_linux_distribution()

    if not distro_name:
        # print("Could not detect the Linux distribution.")
        return
    # else:
    #     print(f"Detected distribution: {distro_name} (Version: {distro_version})")

    package_manager = get_package_manager(distro_name)
    if package_manager:
        print(f"{package_manager}")
    # else:
    #     print("Could not determine the package manager for this distribution.")
    #     print("This script may need to be updated to support this distribution.")


if __name__ == "__main__":
    main()
