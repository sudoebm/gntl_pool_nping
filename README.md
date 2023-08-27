# gntl_pool_nping

[![License](https://img.shields.io/badge/license-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0.en.html)

## Description

This repository contains an alpha shell script that tests the Round-Trip Time (RTT) of various cryptocurrency mining pools. The script helps miners identify the pool with the shortest RTT, making it easier to decide which pool to use for mining. The script will continue to evolve, with ongoing expansions and optimizations planned over time. Please note that this script is provided "as is," and I want to emphasize that I accept no liability for any potential damages resulting from its use.

## Features

-  Alpha shell script for testing Round-Trip Time (RTT) of mining pools.
-  Planned expansion with new features.
-  Ongoing optimizations for improved performance.

## Usage

To run the script, execute it with superuser privileges:

```bash
sudo ./gntl_pool_nping.sh
```

The script will test the RTT of various cryptocurrency mining pools and provide you with results based on the fastest response times.

## License

This project is licensed under the **GNU General Public License Version 2**, June 1991.

## Acknowledgments

This script is inspired by the work of Acktarius and his script [`ping_ccx_pool`](https://github.com/Acktarius/ping_ccx_pool/). While not a direct fork, I thank him for the idea and approach that contributed to the development of this script.

## Dependencies

This script requires the `nping` utility, which is part of the [`nmap`](https://github.com/nmap/nmap) package, to function properly. If `nping` is not installed, the script will prompt you to install the necessary package.

**Disclaimer:** Please be aware that this script is currently in its alpha stage and is undergoing testing. It is provided on an "as is" basis, and I assume no responsibility for any potential damages resulting from its use. Use it responsibly and at your own risk.

## Change_Log

1.0.0 Initial Commit
1.1.0 Multi system functionality
  Added functionality to detect which OS is being used.
  Added functionality for package managers yum, dnf, and zypper. 
