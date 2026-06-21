# Aurid - EU-Sovereign Microsoft 365 Replacement Platform

## Overview

Aurid is a phased, EU-sovereign platform to replace Microsoft 365, starting with Identity and Access Management (IAM) and expanding to communications, mail, document editing, and file storage. Every layer runs on EU-owned infrastructure with no US jurisdiction exposure.

## Architecture

```
aurid/
├── apps/                    # Ruby on Rails applications
│   ├── admin_console/       # Enterprise admin UI (Keycloak wrapper)
│   ├── control_plane/       # Tenant management, billing, monitoring
│   └── api_gateway/         # Unified API gateway for all services
├── rust/                    # Rust components for performance-critical tasks
│   ├── migration_tool/      # AD to FreeIPA migration (aurid-migrate)
│   └── audit_logger/        # Tamper-evident audit logging
├── k8s/                     # Kubernetes deployment
│   ├── helm/                # Helm charts for deployment
│   └── opentofu/            # OpenTofu modules for data plane
├── config/                  # Shared configuration
├── scripts/                 # Utility scripts
└── docs/                    # Documentation
```

## Phase 1: IAM Platform (MVP)

### Core Components

1. **Admin Console** - Enterprise IT admin interface
2. **Control Plane** - Tenant provisioning, billing, monitoring
3. **API Gateway** - Unified access to all Aurid services
4. **Migration Tool** - Active Directory to FreeIPA migration
5. **Audit Logger** - GxP-grade tamper-evident logging

### Technology Stack

- **Primary**: Ruby on Rails 7.x
- **Performance**: Rust (migration tool, audit logging)
- **Identity**: Keycloak (embedded/integrated)
- **Directory**: FreeIPA
- **Deployment**: Kubernetes (Helm, OpenTofu)
- **Infrastructure**: Hetzner (Germany), Scaleway (France)

## Quick Start

### Prerequisites

- Ruby 3.2+
- Rust 1.70+
- Node.js 18+
- Docker + Kubernetes
- PostgreSQL
- Redis

### Development Setup

```bash
# Clone and setup
cd aurid

# Install Ruby dependencies
bundle install

# Setup databases
rails db:create db:migrate

# Start development servers
docker-compose up
```

## Project Structure

### Rails Applications

Each Rails app follows standard conventions with shared gems and configurations.

### Rust Components

Performance-critical components written in Rust for:
- High-volume data migration
- Cryptographic audit logging
- Real-time sync operations

### Kubernetes Deployment

- **Control Plane**: Managed by Aurid (Hetzner/Scaleway)
- **Data Plane**: Customer's Kubernetes cluster

## Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [API Documentation](docs/API.md)
- [Migration Guide](docs/MIGRATION.md)
- [Deployment Guide](docs/DEPLOYMENT.md)

## License

Proprietary (initial) - Open source planned for Phase 2

## Contact

Aurid ApS - Denmark
