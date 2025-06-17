# Loss Prevention Proxy Pipeline System

## Project Structure

- `configs/` - Configuration files (camera/workload mapping, pipeline mapping)
- `docker/` - Dockerfiles for downloader and pipeline containers
- `docs/` - Documentation (HLD, LLD, system design)
- `downloads/` - Scripts for downloading models and videos
- `src/` - Main source code and pipeline runner scripts
- `docker-compose.yml` - Docker Compose configuration
- `Makefile` - Build automation
- `README.md` - Project overview and instructions

## Usage

- Use `docker/Dockerfile.downloader` to build the asset preparation container.
- Use `docker/Dockerfile.pipelines` to build the pipeline execution container.
- Place or update configuration files in `configs/` as needed.
- Download scripts are in `downloads/`.
- Main pipeline runner is in `src/`.

---

