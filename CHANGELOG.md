# Changelog

All notable changes to SmartKI-Pangolin Gateway will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-07-16

### Added
- Initial release of SmartKI-Pangolin Internet Gateway
- Docker-based deployment with fosrl/pangolin image
- WireGuard tunnel configuration
- Multi-site support for service exposure
- SSL termination and domain routing
- Web administration interface

### Features
- Zero-configuration tunnel setup
- Automatic SSL certificate management
- Domain-based routing (simplyki.net)
- Service health monitoring
- Bandwidth usage tracking
- Multi-user authentication
- REST API for configuration

### Infrastructure
- LXC container deployment (192.168.178.186)
- Nginx reverse proxy integration
- Port forwarding configuration
- Firewall rules management
- Docker container orchestration

### Security
- WireGuard VPN tunnels
- SSL/TLS encryption
- Access control lists
- API authentication
- Rate limiting

### Configuration
- YAML-based configuration
- Environment variable support
- Hot-reload capabilities
- Backup and restore functionality

### Documentation
- Installation and setup guide
- Configuration examples
- Troubleshooting guide
- API documentation

---

Part of the SmartKI Ecosystem - Internet Gateway Component